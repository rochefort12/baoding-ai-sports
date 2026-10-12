#requires -Version 7.0
[CmdletBinding()] param([string]$PostgreSQLBin='C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin')
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$taskRuntime=Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.local/phase1-implementation/verification-runtime.json') -Raw | ConvertFrom-Json
if($taskRuntime.database -notmatch '^aisports_verify_phase1_[a-f0-9]{32}$' -or $taskRuntime.port -ne 8082){throw 'An existing isolated runtime is required.'}
$taskListener=@(Get-NetTCPConnection -State Listen -LocalPort 8082)
$taskProcess=Get-CimInstance Win32_Process -Filter "ProcessId=$($taskRuntime.pid)"
if($taskListener.Count -ne 1 -or $taskListener[0].LocalAddress -ne '127.0.0.1' -or $taskListener[0].OwningProcess -ne $taskRuntime.pid -or !$taskProcess.CommandLine.Contains('--server.port=8082')){throw 'Isolated service ownership cannot be verified.'}
$taskId=[guid]::NewGuid().ToString('N')
$taskOut=Join-Path $WorkspaceRoot ('.local/business-regression-20261011/'+$taskId)
New-Item -ItemType Directory -Path $taskOut | Out-Null
# The working context contains login material; protect the whole run before writing it.
$taskAcl=Get-Acl -LiteralPath $taskOut
$taskAcl.SetAccessRuleProtection($true,$false)
foreach($taskSid in @([Security.Principal.WindowsIdentity]::GetCurrent().User.Value,'S-1-5-18')){
    $taskRule=[Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($taskSid),'FullControl','ContainerInherit,ObjectInherit','None','Allow')
    $taskAcl.AddAccessRule($taskRule)
}
Set-Acl -LiteralPath $taskOut -AclObject $taskAcl
$taskRestoreDb='aisports_restorecheck_'+$taskId
$taskBackup=Join-Path $taskOut 'before-business-tests.dump'
$taskReceipt=[ordered]@{at=[DateTimeOffset]::Now.ToString('o');runId=$taskId;database=$taskRuntime.database;port=8082;frontend=5192;restoreDatabase=$taskRestoreDb;passed=$false;scope='Synthetic business regression in the existing isolated database; main database and old business runs are preserved.'}
function Read-Fingerprint([string]$Database){
    $taskQuery="SELECT format('SELECT %L, count(*), md5(COALESCE(string_agg(md5(t::text), %L ORDER BY t::text), %L)) FROM public.%I t;',table_name,'','',table_name) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' ORDER BY table_name;"
    $taskStatements=& "$PostgreSQLBin/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $Database -At -v ON_ERROR_STOP=1 -c $taskQuery
    Assert-NativeExit 'Read table fingerprint statements'
    $taskRows=("SET default_transaction_read_only=on;`n"+($taskStatements -join "`n")) | & "$PostgreSQLBin/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $Database -At -v ON_ERROR_STOP=1
    Assert-NativeExit 'Read database table fingerprints'
    return @($taskRows | Where-Object {$_ -ne 'SET'})
}
$env:PGPASSWORD=$env:POSTGRES_PASSWORD
try{
    & "$PostgreSQLBin/pg_dump.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -Fc -d $taskRuntime.database -f $taskBackup
    Assert-NativeExit 'Backup existing isolated business data'
    & "$PostgreSQLBin/createdb.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -T template0 $taskRestoreDb
    Assert-NativeExit 'Create isolated backup verification database'
    & "$PostgreSQLBin/pg_restore.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $taskRestoreDb --exit-on-error $taskBackup *> (Join-Path $taskOut 'restore.log')
    Assert-NativeExit 'Restore backup to independent verification database'
    $taskBefore=Read-Fingerprint $taskRuntime.database
    $taskRestored=Read-Fingerprint $taskRestoreDb
    $taskBefore | Set-Content -LiteralPath (Join-Path $taskOut 'before-table-fingerprints.txt') -Encoding utf8
    $taskRestored | Set-Content -LiteralPath (Join-Path $taskOut 'restored-table-fingerprints.txt') -Encoding utf8
    if(Compare-Object $taskBefore $taskRestored){throw 'Restored table content differs from the source snapshot.'}
    # Refresh authentication only; never initialize roles or replay previous business stages.
    & 'D:/dev/nodejs/node.exe' (Join-Path $PSScriptRoot 'Test-Phase1Flow.mjs') recover *> (Join-Path $taskOut 'auth-recovery.log')
    Assert-NativeExit 'Recover existing ordinary-role sessions'
    $taskState=Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.local/phase1-implementation/verification-session.json') -Raw | ConvertFrom-Json
    if($taskState.database -ne $taskRuntime.database){throw 'Authentication state belongs to another database.'}
    $taskContext=[ordered]@{runId=$taskId;prefix=('回归-'+$taskId.Substring(0,8));database=$taskRuntime.database;backend='http://127.0.0.1:8082';frontend='http://127.0.0.1:5192';out=$taskOut;clientId='e5cd7e4891bf95d1d19206ce24a7b32e';password=$taskState.password;admin=$taskState.admin;government=$taskState.government;organizer=$taskState.organizer;organizationId=$taskState.organizationId;people=$taskState.people;definitions=$taskState.definitions;guard='Only new run-prefixed objects may be changed; shared roles must not be reinitialized, old business objects must not be replayed.'}
    $taskContext | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $taskOut 'context.private.json') -Encoding utf8
    $taskReceipt.backupSha256=(Get-FileHash -LiteralPath $taskBackup -Algorithm SHA256).Hash.ToLowerInvariant()
    $taskReceipt.tableCount=$taskBefore.Count
    $taskReceipt.fingerprintSha256=(Get-FileHash -LiteralPath (Join-Path $taskOut 'before-table-fingerprints.txt')).Hash.ToLowerInvariant()
    $taskReceipt.authOnlyRecovered=$true
    $taskReceipt.passed=$true
}catch{
    $taskReceipt.failure=$_.Exception.Message
    throw
}finally{
    $taskReceipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $taskOut 'preflight-receipt.json') -Encoding utf8
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    Write-Output ('Business regression evidence: '+$taskOut)
}
