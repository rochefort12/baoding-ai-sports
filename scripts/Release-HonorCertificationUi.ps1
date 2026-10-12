#requires -Version 7.0
<# Exact six UI-only honor-certification activations. No business SQL writes or Agent release. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$EvidencePath,
    [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedJarSha256,
    [switch]$Main,
    [switch]$PreflightOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'The protected local AISports Windows host is required.' }
$WorkspaceRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$JarPath = Join-Path $WorkspaceRoot 'backend/ruoyi-admin/target/ruoyi-admin.jar'
$EvidenceAbsolute = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($EvidencePath)) { $EvidencePath } else { Join-Path $WorkspaceRoot $EvidencePath }))
if (-not $EvidenceAbsolute.StartsWith($WorkspaceRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'The evidence must remain inside this workspace.' }

function Assert-PlainPath([string]$Path) {
    $cursor = [IO.Path]::GetFullPath($Path)
    if ($cursor -ne $WorkspaceRoot -and -not $cursor.StartsWith($WorkspaceRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'A release path escaped this workspace.' }
    while ($cursor -and $cursor -ne $WorkspaceRoot) {
        if (Test-Path -LiteralPath $cursor) {
            if (((Get-Item -LiteralPath $cursor).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'A release path contains a reparse point.' }
        }
        $cursor = Split-Path $cursor -Parent
    }
}
function Protect-Directory([string]$Path) {
    Assert-PlainPath $Path
    [IO.Directory]::CreateDirectory($Path) | Out-Null
    $directory = [IO.DirectoryInfo]::new($Path)
    $acl = [IO.FileSystemAclExtensions]::GetAccessControl($directory,[Security.AccessControl.AccessControlSections]::Access)
    $acl.SetAccessRuleProtection($true,$false)
    foreach ($rule in @($acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]))) { $acl.RemoveAccessRuleSpecific($rule) }
    $userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $systemSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    foreach ($sid in @($userSid,$systemSid)) { $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow')) }
    [IO.FileSystemAclExtensions]::SetAccessControl($directory,$acl)
    $actual = [IO.FileSystemAclExtensions]::GetAccessControl($directory,[Security.AccessControl.AccessControlSections]::Access)
    $rules = @($actual.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]))
    if (-not $actual.AreAccessRulesProtected -or $rules.Count -ne 2 -or @($rules | Where-Object { $_.IdentityReference.Value -notin @($userSid.Value,$systemSid.Value) -or $_.AccessControlType -ne 'Allow' -or $_.FileSystemRights -ne [Security.AccessControl.FileSystemRights]::FullControl }).Count) { throw 'Protected release ACL verification failed.' }
}
Assert-PlainPath $EvidenceAbsolute
Assert-PlainPath $JarPath
if ((Get-FileHash -LiteralPath $JarPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $ExpectedJarSha256.ToLowerInvariant()) { throw 'The current JAR differs from the expected verification JAR.' }
$port = if ($Main) { 8080 } else { 8082 }
if ($Main) {
    $pidPath = Join-Path $WorkspaceRoot '.local/backend.pid'
    Assert-PlainPath $pidPath
    $backendPid = [int]([IO.File]::ReadAllText($pidPath).Trim())
} else {
    $runtimePath = Join-Path $WorkspaceRoot '.local/phase1-implementation/verification-runtime.json'
    Assert-PlainPath $runtimePath
    $runtime = [IO.File]::ReadAllText($runtimePath) | ConvertFrom-Json
    if ($runtime.port -ne 8082 -or $runtime.database -notmatch '^aisports_verify_phase1_[a-f0-9]{32}$' -or $runtime.jarSHA256 -ne $ExpectedJarSha256.ToLowerInvariant()) { throw 'Existing rehearsal identity or JAR binding differs.' }
    $backendPid = [int]$runtime.pid
}
$process = Get-CimInstance Win32_Process -Filter "ProcessId=$backendPid"
$connections = @(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction Stop)
if (-not $process -or $process.Name -notmatch '^java(w)?\.exe$' -or -not $connections.Count -or @($connections | Where-Object { $_.OwningProcess -ne $backendPid -or $_.LocalAddress -notin @('127.0.0.1','::1') }).Count) { throw 'Only the recorded loopback sports process may be released.' }
$command = ([string]$process.CommandLine).Replace('/','\')
if (-not $command.Contains($JarPath.Replace('/','\'),[StringComparison]::OrdinalIgnoreCase) -or $command -notmatch '--spring\.profiles\.active=local(?:\s|$)' -or $command -match '--spring\.config\.(location|additional-location)|--spring\.profiles\.include|--spring\.datasource') { throw 'The runtime JAR/profile ownership guard failed.' }
if (($Main -and $command -match '--server\.port=(?!8080(?:\s|$))') -or (-not $Main -and $command -notmatch '--server\.port=8082(?:\s|$)')) { throw 'The backend port command differs from the selected local runtime.' }
if ($process.CreationDate.ToUniversalTime() -lt (Get-Item -LiteralPath $JarPath).LastWriteTimeUtc) { throw 'The backend was started before the current JAR was written.' }

# Read only PostgreSQL connection values. Do not load model keys for an administrative release.
$envPath = Join-Path $WorkspaceRoot '.env'
Assert-PlainPath $envPath
$environmentBefore = @{}
foreach ($name in @('POSTGRES_USER','POSTGRES_PASSWORD','POSTGRES_PORT','POSTGRES_DB','AISPORTS_MAIN_ADMIN_TOKEN','AISPORTS_HONOR_RUNTIME_GUARD','AISPORTS_HONOR_RELEASE_ROOT')) { $environmentBefore[$name] = [Environment]::GetEnvironmentVariable($name,'Process') }
$packet = $null
try {
    $localPg = @{}
    foreach ($line in [IO.File]::ReadAllLines($envPath)) { if ($line -match '^(POSTGRES_USER|POSTGRES_PASSWORD|POSTGRES_PORT|POSTGRES_DB)=(.*)$') { $localPg[$Matches[1]] = $Matches[2] } }
    if (-not $localPg.POSTGRES_USER -or -not $localPg.POSTGRES_PASSWORD -or $localPg.POSTGRES_DB -ne 'aisports' -or $localPg.POSTGRES_PORT -ne '25432') { throw 'The fixed local PostgreSQL connection is unavailable.' }
    foreach ($name in @('POSTGRES_USER','POSTGRES_PASSWORD','POSTGRES_PORT','POSTGRES_DB')) { [Environment]::SetEnvironmentVariable($name,$localPg[$name],'Process') }
    if ($Main) {
        $credentialPath = Join-Path $WorkspaceRoot '.local/main-access/administrator.dpapi'
        Assert-PlainPath $credentialPath
        $secure = ConvertTo-SecureString ([IO.File]::ReadAllText($credentialPath).Trim())
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try { $packet = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) | ConvertFrom-Json }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer); $secure.Dispose() }
        if ($packet.username -ne 'admin' -or $packet.baseUri -ne 'http://127.0.0.1:8080' -or -not $packet.token) { throw 'The protected main administrator identity differs.' }
        $env:AISPORTS_MAIN_ADMIN_TOKEN = $packet.token
    }
    $releaseRoot = Join-Path $WorkspaceRoot '.local/honor-certification-release-20261011'
    Protect-Directory $releaseRoot
    $env:AISPORTS_HONOR_RELEASE_ROOT = $releaseRoot
    $env:AISPORTS_HONOR_RUNTIME_GUARD = @{ port=$port; pid=$backendPid; jarSha256=$ExpectedJarSha256.ToLowerInvariant(); processStartedAt=$process.CreationDate.ToUniversalTime().ToString('o') } | ConvertTo-Json -Compress
    $arguments = @("$PSScriptRoot/Release-HonorCertificationUi.mjs",'--evidence',$EvidenceAbsolute,'--jar-sha256',$ExpectedJarSha256.ToLowerInvariant())
    if ($Main) { $arguments += '--main' }
    if ($PreflightOnly) { $arguments += '--preflight-only' }
    Push-Location $WorkspaceRoot
    try { & 'D:/dev/nodejs/node.exe' @arguments; if ($LASTEXITCODE -ne 0) { throw 'Selective honor UI release did not pass. Inspect its protected immutable receipt.' } }
    finally { Pop-Location }
} finally {
    foreach ($name in $environmentBefore.Keys) { [Environment]::SetEnvironmentVariable($name,$environmentBefore[$name],'Process') }
    $packet = $null; $localPg = $null
}
