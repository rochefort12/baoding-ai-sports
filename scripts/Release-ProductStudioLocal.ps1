#requires -Version 7.0
<#
Selective, local-only product-studio activation. This entry point does not reuse or
modify Release-Phase1Local.ps1. All activation writes go through the administrator
release API; SQL is used only for identity/catalog/audit verification and backup.
The report is frozen before release. Release/rollback receipts are separate new
objects. A backup is retained as recovery evidence, never restored automatically.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$EvidencePath,
    [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedJarSha256,
    [switch]$PreflightOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'This release entry point requires the AISports Windows host.' }
$WorkspaceRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$ExpectedJarSha256 = $ExpectedJarSha256.ToLowerInvariant()
$BaseUri = 'http://127.0.0.1:8080'
$ClientId = 'e5cd7e4891bf95d1d19206ce24a7b32e'
$Targets = @('event.material.save', 'event.material.generate', 'event.cover.save')
$RequiredChecks = @('frontendTypecheck', 'frontendBuild', 'realModel', 'avatarHttp', 'roomUi', 'ordinaryOrganizerUi')
$RequiredSources = @(
    'backend/aisports-domains/d04/aisports-table-event/src/main/java/org/dromara/sports/event/service/EventMaterialActionProvider.java',
    'backend/aisports-domains/d04/aisports-table-event/src/main/java/org/dromara/sports/event/service/EventMaterialService.java',
    'backend/aisports-domains/d02/aisports-table-profile-display/src/main/java/org/dromara/sports/tables/d02/profile_display/ProfileAvatarService.java',
    'plus-ui/src/components/business/EventMaterialStudio.vue',
    'plus-ui/src/components/business/EventCoverEditor.vue',
    'plus-ui/src/components/consumer/SportsAvatarEditor.vue',
    'plus-ui/src/components/consumer/SportsAvatar.vue',
    'plus-ui/src/api/sports/organizerMaterials.ts'
)
$PgBin = 'C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin'
$JarPath = Join-Path $WorkspaceRoot 'backend/ruoyi-admin/target/ruoyi-admin.jar'
$Out = Join-Path $WorkspaceRoot '.local/product-release-20261011'
$RunId = [guid]::NewGuid().ToString('N')
$StartedAt = [DateTimeOffset]::UtcNow.ToString('o')
$Token = $null
$AdminPassword = $null
$LockStream = $null
$OutputReady = $false
$PreviousPgPassword = [Environment]::GetEnvironmentVariable('PGPASSWORD', 'Process')
$Attempted = [Collections.Generic.List[string]]::new()
$Released = [Collections.Generic.List[string]]::new()
$PriorTargets = @{}
$DefinitionHashes = @{}
$Receipt = [ordered]@{
    scope = 'local-product-studio-trial'; runId = $RunId; startedAt = $StartedAt
    endpoint = $BaseUri; database = 'aisports'; channels = @('ui'); targets = $Targets
    passed = $false; state = 'preflight'; checks = @(); attempted = @(); released = @()
    restoration = 'not_required'; limitation = 'Local UI activation only. It does not certify real payments, SMS, image-provider success, LAN access, or a complete live tournament.'
}

function Assert-Condition([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        $failure = [InvalidOperationException]::new($Message)
        $failure.Data['studio_safe'] = $true
        throw $failure
    }
}

function Get-SafeFailure($ErrorRecord) {
    if ($ErrorRecord.Exception.Data.Contains('studio_safe')) { return $ErrorRecord.Exception.Message }
    return 'A local prerequisite or operation failed. Raw exception details were omitted to protect credentials; inspect the host privately.'
}

function Resolve-WorkspaceFile([string]$Value, [long]$MaxBytes = 67108864) {
    Assert-Condition (-not [string]::IsNullOrWhiteSpace($Value)) 'An evidence/source path is missing.'
    $full = if ([IO.Path]::IsPathRooted($Value)) { [IO.Path]::GetFullPath($Value) } else { [IO.Path]::GetFullPath((Join-Path $WorkspaceRoot $Value)) }
    Assert-Condition ($full.StartsWith($WorkspaceRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) 'Evidence/source path escapes this workspace.'
    $item = Get-Item -LiteralPath $full
    Assert-Condition (-not $item.PSIsContainer -and $item.Length -gt 0 -and $item.Length -le $MaxBytes) 'Evidence/source must be a bounded, non-empty ordinary file.'
    $cursor = $full
    while ($cursor -and $cursor -ne $WorkspaceRoot) {
        $part = Get-Item -LiteralPath $cursor
        Assert-Condition (($part.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Evidence/source path contains a reparse point.'
        $cursor = Split-Path $cursor -Parent
    }
    return $full
}

function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Get-Relative([string]$Path) { return [IO.Path]::GetRelativePath($WorkspaceRoot, $Path).Replace('\', '/') }

function Set-ProtectedDirectory([string]$Path) {
    # Only this host's user and SYSTEM may read the backup and release receipts.
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    $item = Get-Item -LiteralPath $Path
    Assert-Condition (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Protected receipt destination contains a reparse point.'
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $system = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    # Write only the access-control section. Set-Acl with a new security
    # descriptor also attempts privileged security/audit-section operations on
    # this host. An ordinary owner can secure its DACL without SeSecurityPrivilege.
    $directory = [IO.DirectoryInfo]::new($Path)
    $acl = [IO.FileSystemAclExtensions]::GetAccessControl($directory, [Security.AccessControl.AccessControlSections]::Access)
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($rule in @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))) { $acl.RemoveAccessRuleSpecific($rule) }
    foreach ($identity in @($sid, $system)) {
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($identity, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
    }
    [IO.FileSystemAclExtensions]::SetAccessControl($directory, $acl)
    $verified = [IO.FileSystemAclExtensions]::GetAccessControl($directory, [Security.AccessControl.AccessControlSections]::Access)
    $actualRules = @($verified.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
    Assert-Condition ($verified.AreAccessRulesProtected -and $actualRules.Count -eq 2 -and @($actualRules | Where-Object { $_.IdentityReference.Value -notin @($sid.Value, $system.Value) -or $_.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or $_.FileSystemRights -ne [Security.AccessControl.FileSystemRights]::FullControl }).Count -eq 0) 'Protected receipt directory ACL did not retain exactly ADMIN and SYSTEM access.'
}

function Write-FrozenJson([string]$Name, $Value) {
    $path = Join-Path $Out ("studio-$RunId-$Name.json")
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($Value | ConvertTo-Json -Depth 70) + "`n")
    $stream = [IO.FileStream]::new($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    try { $stream.Write($bytes); $stream.Flush($true) } finally { $stream.Dispose() }
    return [ordered]@{ path = Get-Relative $path; sha256 = Get-Sha256 $path }
}

function Add-Check([string]$Name) {
    $Receipt.checks += [ordered]@{ name = $Name; passed = $true; at = [DateTimeOffset]::UtcNow.ToString('o') }
}

function Invoke-LocalApi([string]$Route, [string]$Method = 'GET', $Body = $null) {
    Assert-Condition ($Route.StartsWith('/') -and -not $Route.Contains('://')) 'Only fixed local API routes are accepted.'
    $headers = @{ clientid = $ClientId }
    if ($Token) { $headers.Authorization = 'Bearer ' + $Token }
    $arguments = @{ Uri = $BaseUri + $Route; Method = $Method; Headers = $headers; TimeoutSec = 25; MaximumRedirection = 0 }
    if ($null -ne $Body) { $arguments.ContentType = 'application/json'; $arguments.Body = $Body | ConvertTo-Json -Depth 40 -Compress }
    try { $result = Invoke-RestMethod @arguments } catch { Assert-Condition $false "Local API request failed: $Method $Route. No response body or credentials were recorded." }
    Assert-Condition ($null -ne $result -and $result.code -eq 200) "Local API rejected: $Method $Route. Inspect the protected application log."
    return $result.data
}

function Invoke-ReadOnlySql([string]$Sql) {
    Assert-Condition ($Sql -match '^SELECT\s' -and $Sql -notmatch '\b(INSERT|UPDATE|DELETE|ALTER|CREATE|DROP|TRUNCATE)\b') 'Release verification SQL must be read-only.'
    $result = & (Join-Path $PgBin 'psql.exe') -X -h 127.0.0.1 -p 25432 -U $LocalEnv.POSTGRES_USER -d aisports -At -v ON_ERROR_STOP=1 -c $Sql 2>&1
    Assert-Condition ($LASTEXITCODE -eq 0) 'Read-only local database verification failed. No raw database output was recorded.'
    return ($result -join "`n").Trim()
}

function Get-ActivationRows {
    $json = Invoke-ReadOnlySql @'
SELECT COALESCE(json_agg(t ORDER BY t.code,t.channel),'[]'::json)::text FROM (
 SELECT a.id::text,a.code,a.channel,a.enabled,a.capability_version_id::text,a.version,
        v.source_hash,v.revision,v.status
 FROM asp_capability_activation a LEFT JOIN asp_capability_version v
   ON v.id=a.capability_version_id AND v.code=a.code
) t
'@
    return @($json | ConvertFrom-Json -AsHashtable)
}

function Get-UnrelatedCanonical($Rows) {
    return (@($Rows | Where-Object { -not ($_.channel -eq 'ui' -and $Targets -contains $_.code) } | Sort-Object code, channel) | ConvertTo-Json -Depth 12 -Compress)
}

function Get-LatestTargetAudit([string]$Code) {
    Assert-Condition ($Targets -contains $Code) 'Only a fixed target release audit may be read.'
    $json = Invoke-ReadOnlySql "SELECT COALESCE((SELECT result_reference::text FROM asp_action_execution WHERE action_code='capability.release' AND result_reference->>'code'='$Code' AND result_reference->>'channel'='ui' ORDER BY occurred_at DESC,id DESC LIMIT 1),'{}')"
    return ($json | ConvertFrom-Json -AsHashtable)
}

function Assert-LocalRuntime {
    $jar = Resolve-WorkspaceFile $JarPath 1073741824
    Assert-Condition ((Get-Sha256 $jar) -eq $ExpectedJarSha256) 'The current JAR differs from the verified release.'
    $pidFile = Resolve-WorkspaceFile '.local/backend.pid' 128
    $pidText = [IO.File]::ReadAllText($pidFile).Trim()
    Assert-Condition ($pidText -match '^[1-9][0-9]*$') 'The main backend PID receipt is invalid.'
    $backendPid = [int]$pidText
    $connections = @(Get-NetTCPConnection -State Listen -LocalPort 8080 -ErrorAction Stop)
    Assert-Condition ($connections.Count -gt 0 -and @($connections | Where-Object { $_.OwningProcess -ne $backendPid -or $_.LocalAddress -notin @('127.0.0.1', '::1') }).Count -eq 0) '8080 is not exclusively owned by the loopback sports backend.'
    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$backendPid"
    Assert-Condition ($null -ne $process -and $process.Name -match '^java(w)?\.exe$') 'Main backend process is not the recorded Java process.'
    $command = ([string]$process.CommandLine).Replace('/', '\')
    Assert-Condition ($command.Contains($jar.Replace('/', '\'), [StringComparison]::OrdinalIgnoreCase) -and $command -match '--spring\.profiles\.active=local(?:\s|$)' -and $command -notmatch '--server\.port=(?!8080(?:\s|$))' -and $command -notmatch '--spring\.datasource|--spring\.config\.(location|additional-location)|--spring\.profiles\.include') 'Backend command does not identify this local JAR/profile.'
    Assert-Condition ($process.CreationDate.ToUniversalTime() -ge (Get-Item -LiteralPath $jar).LastWriteTimeUtc) 'The backend process started before this JAR was written; restart the verified JAR before release.'
    return [ordered]@{ pid = $backendPid; processStartedAt = $process.CreationDate.ToUniversalTime().ToString('o'); jarSha256 = $ExpectedJarSha256; listener = '127.0.0.1:8080' }
}

function Assert-EvidenceBindings {
    Assert-Condition ((Get-Sha256 $EvidenceAbsolute) -eq $EvidenceHash) 'The frozen verification report changed during release.'
    foreach ($binding in $Bindings) {
        Assert-Condition ((Get-Sha256 (Resolve-WorkspaceFile $binding.path)) -eq $binding.sha256) 'A verified source or test artifact changed during release.'
    }
    $null = Assert-LocalRuntime
}

function Assert-Catalog($Catalog) {
    Assert-Condition ($null -ne $Catalog -and $null -ne $Catalog.definitions -and $null -ne $Catalog.activations) 'Capability catalog is unavailable.'
    Assert-Condition (@($Catalog.activations | Where-Object { $_.channel -eq 'agent' -and $_.enabled }).Count -eq 0) 'Agent channels must remain closed.'
    Assert-Condition (@($Catalog.activations | Where-Object { $_.channel -eq 'ui' -and $_.enabled -and $Targets -notcontains $_.code }).Count -eq 47) 'The previously released 47 UI capabilities differ from the expected baseline.'
}

function Set-TargetActivation([string]$Code, [bool]$Enabled) {
    Assert-Condition (-not $PreflightOnly) 'Preflight-only mode cannot call the release API.'
    Assert-Condition ($Targets -contains $Code) 'A release request attempted to change an unrelated capability.'
    $null = Invoke-LocalApi '/sports/platform/management/release' 'POST' @{
        code = $Code; channel = 'ui'; enabled = $Enabled
        definitionHash = $DefinitionHashes[$Code]; evidenceHash = $EvidenceHash
    }
}

try {
    # Resolve the fixed output ancestry before creating any protected child.
    $local = Get-Item -LiteralPath (Join-Path $WorkspaceRoot '.local')
    Assert-Condition (($local.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Local state root contains a reparse point.'
    Set-ProtectedDirectory $Out
    $OutputReady = $true
    $LockStream = [IO.FileStream]::new((Join-Path $Out 'studio-release.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    foreach ($name in @('psql.exe', 'pg_dump.exe', 'pg_restore.exe')) {
        Assert-Condition (Test-Path -LiteralPath (Join-Path $PgBin $name) -PathType Leaf) 'The fixed local PostgreSQL toolchain is unavailable.'
    }
    $EvidenceAbsolute = Resolve-WorkspaceFile $EvidencePath
    $EvidenceHash = Get-Sha256 $EvidenceAbsolute
    $evidence = [IO.File]::ReadAllText($EvidenceAbsolute) | ConvertFrom-Json -AsHashtable
    Assert-Condition ($evidence.scope -eq 'local-product-studio-trial' -and $evidence.passed -is [bool] -and $evidence.passed -and $evidence.jarSha256 -eq $ExpectedJarSha256) 'A passed, matching product-studio report is required.'
    $Bindings = [Collections.Generic.List[object]]::new()
    $boundSources = @{}
    foreach ($entry in @($evidence.sourceFiles)) {
        Assert-Condition ($entry.sha256 -match '^[a-f0-9]{64}$') 'A source binding has no valid SHA-256.'
        $source = Resolve-WorkspaceFile ([string]$entry.path)
        $relative = Get-Relative $source
        Assert-Condition (-not $boundSources.ContainsKey($relative)) 'Duplicate source bindings are not allowed.'
        Assert-Condition ((Get-Sha256 $source) -eq $entry.sha256) 'The current source differs from the verified source.'
        $boundSources[$relative] = $entry.sha256
        $Bindings.Add(@{ path = $relative; sha256 = $entry.sha256 })
    }
    foreach ($required in $RequiredSources) { Assert-Condition ($boundSources.ContainsKey($required)) "The verification report must bind source: $required" }
    foreach ($name in $RequiredChecks) {
        $gate = $evidence.checks[$name]
        Assert-Condition ($null -ne $gate -and $gate.passed -is [bool] -and $gate.passed -and $gate.sha256 -match '^[a-f0-9]{64}$') "Required verification gate is missing or failed: $name"
        $artifact = Resolve-WorkspaceFile ([string]$gate.evidencePath)
        Assert-Condition ((Get-Sha256 $artifact) -eq $gate.sha256) "Verification artifact changed: $name"
        $Bindings.Add(@{ path = Get-Relative $artifact; sha256 = $gate.sha256 })
    }
    $Receipt.evidence = @{ path = Get-Relative $EvidenceAbsolute; sha256 = $EvidenceHash }
    $Receipt.jarSha256 = $ExpectedJarSha256
    $Receipt.bindings = $Bindings.ToArray()
    Add-Check 'Frozen report, current JAR, source and six actual verification artifacts match'

    # Read only the infrastructure values required by this release; do not load AI keys.
    $LocalEnv = @{}
    foreach ($line in [IO.File]::ReadAllLines((Resolve-WorkspaceFile '.env'))) {
        if ($line -match '^(POSTGRES_(?:DB|PORT|USER|PASSWORD))=(.*)$') { $LocalEnv[$Matches[1]] = $Matches[2] }
    }
    Assert-Condition ($LocalEnv.POSTGRES_DB -eq 'aisports' -and $LocalEnv.POSTGRES_PORT -eq '25432' -and $LocalEnv.POSTGRES_USER -and $LocalEnv.POSTGRES_PASSWORD) 'Only the exact native main database aisports at loopback 25432 is allowed.'
    [Environment]::SetEnvironmentVariable('PGPASSWORD', $LocalEnv.POSTGRES_PASSWORD, 'Process')
    Assert-Condition ((Invoke-ReadOnlySql 'SELECT current_database()') -eq 'aisports') 'Live PostgreSQL database identity differs from aisports.'
    $Receipt.runtime = Assert-LocalRuntime
    Add-Check 'Owned loopback main Java process and exact database verified'

    $Receipt.phase = 'captcha_check'
    $captcha = Invoke-LocalApi '/auth/code'
    Assert-Condition (-not $captcha.captchaEnabled) 'Captcha is enabled; unattended administrator release cannot proceed without a verified login.'
    $Receipt.phase = 'local_credential_read'
    Assert-Condition (Test-Path -LiteralPath (Join-Path $WorkspaceRoot '.local/walk-flow.ps1') -PathType Leaf) 'Local administrator credential source .local/walk-flow.ps1 is unavailable; no credential is inferred.'
    $helper = [IO.File]::ReadAllText((Resolve-WorkspaceFile '.local/walk-flow.ps1'))
    $adminMatch = [regex]::Match($helper, '(?s)function Login-Admin.*?password\s*=\s*''([^'']+)''')
    Assert-Condition $adminMatch.Success 'Local administrator credential is unavailable; no credential is inferred.'
    $AdminPassword = $adminMatch.Groups[1].Value
    $helper = $null; $adminMatch = $null
    $Receipt.phase = 'admin_login'
    $login = Invoke-LocalApi '/auth/login' 'POST' @{ username = 'admin'; password = $AdminPassword; clientId = $ClientId; grantType = 'password'; tenantId = '000000' }
    Assert-Condition ($login.access_token) 'Administrator login did not return an authenticated session.'
    $Token = [string]$login.access_token
    $AdminPassword = $null; $login = $null
    $Receipt.phase = 'catalog_read'
    $catalog = Invoke-LocalApi '/sports/platform/management'
    Assert-Catalog $catalog
    foreach ($code in $Targets) {
        $definition = @($catalog.definitions | Where-Object { $_.definition.code -eq $code })
        Assert-Condition ($definition.Count -eq 1 -and -not $definition[0].definition.agent -and $definition[0].definition.actorTypes -contains 'organizer' -and $definition[0].definitionHash -match '^[a-f0-9]{64}$') "The current UI-only organizer capability is invalid: $code"
        $DefinitionHashes[$code] = [string]$definition[0].definitionHash
        $prior = @($catalog.activations | Where-Object { $_.code -eq $code -and $_.channel -eq 'ui' })
        Assert-Condition ($prior.Count -le 1) 'Duplicate target activation in catalog.'
        # This API intentionally only publishes the current definition. A stale
        # prior pointer cannot be restored through it, so reject before any write.
        Assert-Condition ($prior.Count -eq 0 -or $prior[0].source_hash -eq $DefinitionHashes[$code]) "Prior target definition cannot be restored through the current release API: $code"
        $PriorTargets[$code] = @{ existed = $prior.Count -eq 1; enabled = ($prior.Count -eq 1 -and [bool]$prior[0].enabled); definitionHash = $DefinitionHashes[$code] }
    }
    $Receipt.phase = 'catalog_freeze'
    $beforeRows = @(Get-ActivationRows)
    Assert-Condition (@($beforeRows | Where-Object { $_.channel -eq 'agent' -and $_.enabled }).Count -eq 0) 'Database agent activation disagrees with the catalog.'
    $UnrelatedBefore = Get-UnrelatedCanonical $beforeRows
    $Receipt.beforeCatalog = Write-FrozenJson 'catalog-before' $catalog
    $Receipt.beforeActivationRows = Write-FrozenJson 'activations-before' $beforeRows
    $audit = Invoke-ReadOnlySql "SELECT COALESCE(json_agg(t ORDER BY t.id),'[]'::json)::text FROM (SELECT id::text,actor_type,actor_id::text,channel,request_key,payload_hash,status,result_reference,occurred_at FROM asp_action_execution WHERE action_code='capability.release') t"
    $Receipt.beforeReleaseAudit = Write-FrozenJson 'audit-before' ($audit | ConvertFrom-Json -AsHashtable)
    Add-Check 'Real administrator catalog: original 47 UI entries, target definitions, Agent zero and rollback bounds frozen'

    $Receipt.phase = 'backup'
    $backupPath = Join-Path $Out ("studio-$RunId-pre-release.dump")
    Assert-Condition (-not (Test-Path -LiteralPath $backupPath)) 'Backup destination already exists.'
    $dumpOutput = & (Join-Path $PgBin 'pg_dump.exe') -h 127.0.0.1 -p 25432 -U $LocalEnv.POSTGRES_USER -d aisports -Fc -f $backupPath 2>&1
    Assert-Condition ($LASTEXITCODE -eq 0 -and (Get-Item -LiteralPath $backupPath).Length -gt 0) 'Pre-release database backup failed; release was not attempted.'
    $archiveList = & (Join-Path $PgBin 'pg_restore.exe') --list $backupPath 2>&1
    Assert-Condition ($LASTEXITCODE -eq 0 -and ($archiveList -join "`n") -match 'asp_capability_activation') 'Pre-release archive cannot be listed or lacks the capability table.'
    $backupStream = [IO.FileStream]::new($backupPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)
    try { $backupStream.Flush($true) } finally { $backupStream.Dispose() }
    $Receipt.backup = @{ path = Get-Relative $backupPath; sha256 = Get-Sha256 $backupPath; bytes = (Get-Item -LiteralPath $backupPath).Length; validation = 'pg_restore --list; no restore into a database was performed' }
    Add-Check 'Protected main database archive preserved and archive catalog readable'
    Assert-EvidenceBindings
    Assert-Condition ((Get-UnrelatedCanonical (Get-ActivationRows)) -eq $UnrelatedBefore) 'Unrelated capability state changed before release.'
    $beforeReleaseCatalog = Invoke-LocalApi '/sports/platform/management'
    Assert-Catalog $beforeReleaseCatalog
    foreach ($code in $Targets) {
        $liveTarget = @($beforeReleaseCatalog.activations | Where-Object { $_.code -eq $code -and $_.channel -eq 'ui' })
        $prior = $PriorTargets[$code]
        Assert-Condition (($liveTarget.Count -eq 1) -eq [bool]$prior.existed) 'A target activation changed while the backup was being created.'
        if ($prior.existed) {
            Assert-Condition ([bool]$liveTarget[0].enabled -eq [bool]$prior.enabled -and $liveTarget[0].source_hash -eq $prior.definitionHash) 'A target state or definition changed before release.'
        }
    }
    $Receipt.intent = Write-FrozenJson 'intent' @{
        runId = $RunId; startedAt = $StartedAt; scope = 'local-product-studio-trial'; evidence = $Receipt.evidence
        runtime = $Receipt.runtime; priorTargets = $PriorTargets; definitionHashes = $DefinitionHashes
        backup = $Receipt.backup; beforeCatalog = $Receipt.beforeCatalog; beforeActivationRows = $Receipt.beforeActivationRows; beforeReleaseAudit = $Receipt.beforeReleaseAudit
    }
    if ($PreflightOnly) {
        $Receipt.passed = $true; $Receipt.state = 'preflight_passed'; $Receipt.releaseApplied = $false
        return
    }

    $Receipt.state = 'releasing'
    foreach ($code in $Targets) {
        if ($PriorTargets[$code].enabled) { continue }
        Assert-EvidenceBindings
        # Persist attempted target before HTTP: a connection loss can occur after
        # commit. Rollback reads the real state rather than assuming it failed.
        $Attempted.Add($code)
        $null = Write-FrozenJson ("attempt-$($Attempted.Count)") @{ code = $code; channel = 'ui'; definitionHash = $DefinitionHashes[$code]; evidenceHash = $EvidenceHash; at = [DateTimeOffset]::UtcNow.ToString('o') }
        Set-TargetActivation $code $true
        $Released.Add($code)
    }
    $after = Invoke-LocalApi '/sports/platform/management'
    Assert-Catalog $after
    foreach ($code in $Targets) {
        $active = @($after.activations | Where-Object { $_.code -eq $code -and $_.channel -eq 'ui' })
        Assert-Condition ($active.Count -eq 1 -and $active[0].enabled -and $active[0].source_hash -eq $DefinitionHashes[$code]) "Target UI activation did not match the current source: $code"
        if ($Released.Contains($code)) {
            $actualAudit = Get-LatestTargetAudit $code
            Assert-Condition ($actualAudit.evidenceHash -eq $EvidenceHash -and $actualAudit.definitionHash -eq $DefinitionHashes[$code] -and $actualAudit.enabled -eq $true) 'The real main database release audit does not match this API activation.'
        }
    }
    $afterRows = @(Get-ActivationRows)
    Assert-Condition ((Get-UnrelatedCanonical $afterRows) -eq $UnrelatedBefore) 'An unrelated activation changed; the script will not write to it.'
    Assert-EvidenceBindings
    $Receipt.afterCatalog = Write-FrozenJson 'catalog-after' $after
    $Receipt.afterActivationRows = Write-FrozenJson 'activations-after' $afterRows
    Add-Check 'Exactly three current UI definitions available; original entries preserved and Agent zero'
    $Receipt.passed = $true; $Receipt.state = 'released'
} catch {
    # Capture only controlled error messages. Never write API bodies, tokens,
    # credentials, helper source, or arbitrary native stderr into receipts.
    $Receipt.state = 'failed'
    $Receipt.error = Get-SafeFailure $_
    $Receipt.errorType = $_.Exception.GetType().FullName
    $Receipt.failureLine = $_.InvocationInfo.ScriptLineNumber
    if ($Attempted.Count -gt 0 -and $Token) {
        $Receipt.restoration = 'in_progress'
        $rollbackChecks = @()
        foreach ($code in @($Attempted | Select-Object -Unique)) {
            try {
                $current = Invoke-LocalApi '/sports/platform/management'
                $row = @($current.activations | Where-Object { $_.code -eq $code -and $_.channel -eq 'ui' })
                Assert-Condition ($row.Count -le 1) 'Rollback found duplicate target activation.'
                if ($row.Count -eq 1 -and $row[0].enabled) {
                    # Published versions can be reused. Their original evidence
                    # hash is not proof of who last activated the channel; the
                    # real administrator release audit supplies that ownership.
                    $lastAudit = Get-LatestTargetAudit $code
                    Assert-Condition ($row[0].source_hash -eq $DefinitionHashes[$code] -and $lastAudit.evidenceHash -eq $EvidenceHash -and $lastAudit.definitionHash -eq $DefinitionHashes[$code] -and $lastAudit.enabled -eq $true) 'Rollback target no longer belongs to this release; manual coordination is required.'
                    Set-TargetActivation $code ([bool]$PriorTargets[$code].enabled)
                }
                $verified = Invoke-LocalApi '/sports/platform/management'
                $restored = @($verified.activations | Where-Object { $_.code -eq $code -and $_.channel -eq 'ui' })
                $enabled = $restored.Count -eq 1 -and [bool]$restored[0].enabled
                Assert-Condition ($enabled -eq [bool]$PriorTargets[$code].enabled) 'Rollback did not restore the prior effective target state.'
                $rollbackChecks += @{ code = $code; passed = $true; originallyAbsent = -not $PriorTargets[$code].existed; effectiveEnabled = $enabled }
            } catch {
                $rollbackChecks += @{ code = $code; passed = $false; error = Get-SafeFailure $_ }
            }
        }
        $Receipt.rollbackChecks = $rollbackChecks
        $Receipt.restoration = if (@($rollbackChecks | Where-Object { -not $_.passed }).Count -eq 0) { 'effective_target_state_restored' } else { 'manual_recovery_required' }
        $Receipt.rollbackLimitation = 'A previously absent target may remain as a disabled activation with a durable version and audit record. The API preserves history; physical row absence is not restored.'
        try {
            $restoredCatalog = Invoke-LocalApi '/sports/platform/management'
            Assert-Catalog $restoredCatalog
            Assert-Condition ((Get-UnrelatedCanonical (Get-ActivationRows)) -eq $UnrelatedBefore) 'Unrelated activation state changed; it was not overwritten.'
            $Receipt.rollbackCatalog = Write-FrozenJson 'catalog-rollback' $restoredCatalog
        } catch { $Receipt.restoration = 'manual_recovery_required'; $Receipt.rollbackVerificationError = Get-SafeFailure $_ }
    }
} finally {
    $Receipt.attempted = $Attempted.ToArray(); $Receipt.released = $Released.ToArray()
    $Receipt.finishedAt = [DateTimeOffset]::UtcNow.ToString('o')
    $Token = $null; $AdminPassword = $null; $helper = $null; $adminMatch = $null; $login = $null
    if (Get-Variable LocalEnv -ErrorAction SilentlyContinue) { $LocalEnv.Clear() }
    [Environment]::SetEnvironmentVariable('PGPASSWORD', $PreviousPgPassword, 'Process')
    try {
        if ($OutputReady) {
            $final = Write-FrozenJson 'receipt' $Receipt
            Write-Host "Product-studio release state: $($Receipt.state). Protected receipt: $($final.path)"
        } elseif ($Receipt.state -eq 'failed') {
            Write-Host "Product-studio preflight failed before a protected receipt could be written: $($Receipt.error)"
        }
    } finally { if ($LockStream) { $LockStream.Dispose() } }
}
if (-not $Receipt.passed) { throw 'Selective local release did not pass. See the protected immutable receipt; no unrelated capability or business facts were changed by this script.' }
