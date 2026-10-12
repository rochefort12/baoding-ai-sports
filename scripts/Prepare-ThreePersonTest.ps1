#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$ContextPath = '.local/business-regression-20261011/d32bff962337431daf467558d3bd2a50/context.private.json',
    [string]$RunId,
    [string]$PostgreSQLBin = 'C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin'
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$taskExpectedDb = 'aisports_verify_phase1_242ded43673246699be6bb0f596aa59b'
$taskExpectedJar = 'cdf0321b954b7551f9f52a50b256f195678f5f540e028bcde3ed1a010ce8474e'
$taskContextPath = [IO.Path]::GetFullPath((Join-Path $WorkspaceRoot $ContextPath))
if ([IO.Path]::IsPathRooted($ContextPath)) { $taskContextPath = [IO.Path]::GetFullPath($ContextPath) }
$taskContextRoot = [IO.Path]::GetFullPath((Join-Path $WorkspaceRoot '.local/business-regression-20261011'))
if (!$taskContextPath.StartsWith($taskContextRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Select an existing protected backup context.' }
$taskContext = Get-Content -LiteralPath $taskContextPath -Raw | ConvertFrom-Json
$taskPreflightPath = Join-Path (Split-Path $taskContextPath -Parent) 'preflight-receipt.json'
$taskPreflight = Get-Content -LiteralPath $taskPreflightPath -Raw | ConvertFrom-Json
$taskRuntime = Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.local/phase1-implementation/verification-runtime.json') -Raw | ConvertFrom-Json
if ($taskContext.database -ne $taskExpectedDb -or $taskPreflight.database -ne $taskExpectedDb -or !$taskPreflight.passed -or $taskRuntime.database -ne $taskExpectedDb -or $taskRuntime.port -ne 8082 -or $taskRuntime.jarSHA256 -ne $taskExpectedJar) { throw 'Exact isolated runtime and verified backup are required.' }
if ($taskContext.backend -ne 'http://127.0.0.1:8082' -or $taskContext.frontend -ne 'http://127.0.0.1:5192') { throw 'Unexpected service context.' }
$taskBackupPath = Join-Path (Split-Path $taskContextPath -Parent) 'before-business-tests.dump'
if ((Get-FileHash -LiteralPath $taskBackupPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskPreflight.backupSha256) { throw 'Verified backup bytes changed.' }
$taskListeners = @(Get-NetTCPConnection -State Listen -LocalPort 8082)
$taskProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$($taskRuntime.pid)"
if ($taskListeners.Count -ne 1 -or $taskListeners[0].LocalAddress -ne '127.0.0.1' -or $taskListeners[0].OwningProcess -ne $taskRuntime.pid -or !$taskProcess -or !$taskProcess.CommandLine.Contains('--server.port=8082') -or !$taskProcess.CommandLine.Contains('--redisson.keyPrefix='+$taskRuntime.redisPrefix) -or !$taskProcess.CommandLine.Contains($taskRuntime.jarPath)) { throw 'Active isolated process ownership cannot be verified.' }
$taskDatabaseSockets = @(Get-NetTCPConnection -State Established -OwningProcess $taskRuntime.pid | Where-Object { $_.RemotePort -eq [int]$env:POSTGRES_PORT -and $_.RemoteAddress -eq '127.0.0.1' })
if (!$taskDatabaseSockets.Count) { throw 'The verified Java process has no local PostgreSQL connection.' }
if ((Get-FileHash -LiteralPath $taskRuntime.jarPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskExpectedJar) { throw 'Active runtime package bytes changed.' }
if (!$RunId) { $RunId = [guid]::NewGuid().ToString('N') }
if ($RunId -notmatch '^[a-f0-9]{32}$') { throw 'RunId must be a lowercase UUID without separators.' }
$taskRunRoot = [IO.Path]::GetFullPath((Join-Path $WorkspaceRoot '.local/three-person-test-20261012'))
$taskOut = [IO.Path]::GetFullPath((Join-Path $taskRunRoot $RunId))
if (!$taskOut.StartsWith($taskRunRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe batch path.' }
$taskNewDirectory = !(Test-Path -LiteralPath $taskOut)
if ($taskNewDirectory) { New-Item -ItemType Directory -Path $taskOut | Out-Null }
if ((Get-Item -LiteralPath $taskOut).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Batch directories cannot be reparse points.' }
# Protect the new batch before the first credential/checkpoint byte is written.
$taskOwnerSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$taskAcl = Get-Acl -LiteralPath $taskOut
if ($taskNewDirectory) {
    $taskAcl.SetAccessRuleProtection($true, $false)
    foreach ($taskExistingRule in @($taskAcl.Access)) { [void]$taskAcl.RemoveAccessRuleSpecific($taskExistingRule) }
    foreach ($taskAllowedSid in @($taskOwnerSid, 'S-1-5-18')) {
        $taskRule = [Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($taskAllowedSid), 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        [void]$taskAcl.AddAccessRule($taskRule)
    }
    Set-Acl -LiteralPath $taskOut -AclObject $taskAcl
}
if (!(Get-Acl -LiteralPath $taskOut).AreAccessRulesProtected) { throw 'Existing batch ACL must remain protected from inheritance.' }
function Assert-PrivateBatchAcl {
    foreach ($taskItem in @((Get-Item -LiteralPath $taskOut)) + @(Get-ChildItem -LiteralPath $taskOut -Recurse -Force)) {
        if ($taskItem.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Unexpected reparse point in private batch.' }
        $taskItemAcl = Get-Acl -LiteralPath $taskItem.FullName
        foreach ($taskAccess in $taskItemAcl.Access) {
            $taskAccessSid = $taskAccess.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
            if ($taskAccess.AccessControlType -eq 'Allow' -and $taskAccessSid -notin @($taskOwnerSid, 'S-1-5-18')) { throw 'Private batch ACL contains an additional reader.' }
        }
    }
}
Assert-PrivateBatchAcl
$taskGuard = [ordered]@{at=[DateTimeOffset]::Now.ToString('o');database=$taskExpectedDb;port=8082;pid=$taskRuntime.pid;databaseClientPorts=@($taskDatabaseSockets.LocalPort);jarSha256=$taskExpectedJar;backupSha256=$taskPreflight.backupSha256;ownerSid=$taskOwnerSid;allowedSids=@($taskOwnerSid,'S-1-5-18');aclPassed=$true}
$taskGuardPath = Join-Path $taskOut 'runtime-guard.json'
$taskGuard | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $taskGuardPath -Encoding utf8
$taskOldContext = $env:AISPORTS_REGRESSION_CONTEXT
$taskOldRun = $env:AISPORTS_THREE_PERSON_RUN
$taskOldPsql = $env:AISPORTS_THREE_PERSON_PSQL
try {
    $env:AISPORTS_REGRESSION_CONTEXT = $taskContextPath
    $env:AISPORTS_THREE_PERSON_RUN = $taskOut
    $env:AISPORTS_THREE_PERSON_PSQL = Join-Path $PostgreSQLBin 'psql.exe'
    Push-Location $WorkspaceRoot
    try { & 'D:/dev/nodejs/node.exe' (Join-Path $PSScriptRoot 'Prepare-ThreePersonTest.mjs'); Assert-NativeExit 'Prepare new three-person test identities' }
    finally { Pop-Location }
    Assert-PrivateBatchAcl
    $taskAclReceipt = [ordered]@{at=[DateTimeOffset]::Now.ToString('o');runId=$RunId;passed=$true;privateFiles=@(Get-ChildItem -LiteralPath $taskOut -Recurse -File | ForEach-Object { $_.FullName.Substring($taskOut.Length+1) });allowedReaders='Current Windows owner and SYSTEM only'}
    $taskAclReceipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $taskOut 'acl-receipt.json') -Encoding utf8
    Assert-PrivateBatchAcl
    Write-Output ('Three-person test batch: ' + $taskOut)
} finally {
    $env:AISPORTS_REGRESSION_CONTEXT = $taskOldContext
    $env:AISPORTS_THREE_PERSON_RUN = $taskOldRun
    $env:AISPORTS_THREE_PERSON_PSQL = $taskOldPsql
}
