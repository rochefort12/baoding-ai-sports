#requires -Version 7.0
# Install the verified package for the next startup while preserving the user's stopped main application.
[CmdletBinding()]param([Parameter(Mandatory)][string]$BuildReceipt,[Parameter(Mandatory)][string]$LiveReceipt,[Parameter(Mandatory)][string]$RecoveryReceipt)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
if($env:POSTGRES_DB -ne 'aisports'){throw 'Main database identity changed'}
if(Get-NetTCPConnection -State Listen -LocalPort 8080 -ErrorAction SilentlyContinue){throw 'Main application must remain stopped for this staging operation'}
function Read-Gate([string]$Path){$taskPath=(Resolve-Path -LiteralPath $Path).Path;if(!$taskPath.StartsWith($WorkspaceRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Gate escaped workspace'};$taskGate=Get-Content -LiteralPath $taskPath -Raw|ConvertFrom-Json;if(!$taskGate.passed){throw 'An acceptance gate did not pass'};return $taskGate}
$taskBuild=Read-Gate $BuildReceipt;$taskLive=Read-Gate $LiveReceipt;$taskRecovery=Read-Gate $RecoveryReceipt
if(!$taskBuild.jarPath -or @($taskLive.checks).Count -lt 17 -or @($taskRecovery.checks).Count -lt 5){throw 'Required full build, real child result and restart gates are missing'}
if($taskLive.runtimeJarSha256 -ne $taskBuild.jarSha256 -or $taskRecovery.runtimeJarSha256 -ne $taskBuild.jarSha256){throw 'Real model evidence is not bound to this package'}
$taskSource=(Resolve-Path -LiteralPath $taskBuild.jarPath).Path
if(!$taskSource.StartsWith($WorkspaceRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or (Get-FileHash -LiteralPath $taskSource).Hash.ToLowerInvariant() -ne $taskBuild.jarSha256){throw 'Tested package changed'}
$taskId=[guid]::NewGuid().ToString('N');$taskOut=Join-Path $WorkspaceRoot ('.local/agent-runtime-20261012/main-stage-'+$taskId)
New-Item -ItemType Directory -Path $taskOut|Out-Null
$taskAcl=Get-Acl -LiteralPath $taskOut;$taskAcl.SetAccessRuleProtection($true,$false)
foreach($taskSid in @([Security.Principal.WindowsIdentity]::GetCurrent().User.Value,'S-1-5-18')){$taskAcl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($taskSid),'FullControl','ContainerInherit,ObjectInherit','None','Allow'))};Set-Acl -LiteralPath $taskOut -AclObject $taskAcl
$taskBin='C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin'
$taskRestore='aisports_agent_restore_'+$taskId;$taskDump=Join-Path $taskOut 'main-before.dump'
$taskReceipt=@{at=[DateTimeOffset]::Now.ToString('o');passed=$false;state='STAGING';scope='Stopped main package installation and forward migration; no main model run, business write or capability activation';jarSha256=$taskBuild.jarSha256;restoreDatabase=$taskRestore;checks=@()}
$env:PGPASSWORD=$env:POSTGRES_PASSWORD
function Fingerprint([string]$Database,[bool]$BusinessOnly=$false){
 $taskExclusion=if($BusinessOnly){" AND table_name NOT IN('aisports_schema_history','asp_agent_version','asp_agent_run')"}else{''}
 $taskQuery="SELECT format('SELECT %L,count(*),md5(COALESCE(string_agg(md5(t::text),%L ORDER BY t::text),%L)) FROM public.%I t;',table_name,'','',table_name) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'$taskExclusion ORDER BY table_name;"
 $taskLines=& "$taskBin/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $Database -At -v ON_ERROR_STOP=1 -c $taskQuery;Assert-NativeExit 'Read fingerprint statements'
 $taskRows=("BEGIN READ ONLY;`n"+($taskLines -join "`n")+"`nROLLBACK;")|& "$taskBin/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $Database -At -v ON_ERROR_STOP=1;Assert-NativeExit 'Read table fingerprints'
 return @($taskRows|Where-Object {$_ -notin @('BEGIN','ROLLBACK')})
}
try {
 $taskBefore=Fingerprint 'aisports';$taskBusinessBefore=Fingerprint 'aisports' $true
 & "$taskBin/pg_dump.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d aisports -Fc -f $taskDump;Assert-NativeExit 'Backup stopped main database'
 & "$taskBin/createdb.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -T template0 $taskRestore;Assert-NativeExit 'Create independent main restore verification database'
 & "$taskBin/pg_restore.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $taskRestore --exit-on-error $taskDump *> (Join-Path $taskOut 'restore.log');Assert-NativeExit 'Restore main backup'
 if(Compare-Object $taskBefore (Fingerprint $taskRestore)){throw 'Main backup restore differs'}
 $taskBefore|Set-Content -LiteralPath (Join-Path $taskOut 'before-fingerprints.txt') -Encoding utf8
 $taskReceipt.checks+='main backup and full restore match';$taskReceipt.backupSha256=(Get-FileHash -LiteralPath $taskDump).Hash.ToLowerInvariant();$taskReceipt.restoredTables=$taskBefore.Count
 & "$PSScriptRoot/Apply-NativeMigrations.ps1" -PostgreSQLBin $taskBin -Database $taskRestore
 $env:PGPASSWORD=$env:POSTGRES_PASSWORD
 & "$PSScriptRoot/Apply-NativeMigrations.ps1" -PostgreSQLBin $taskBin -Database 'aisports'
 $env:PGPASSWORD=$env:POSTGRES_PASSWORD
 if(Compare-Object $taskBusinessBefore (Fingerprint 'aisports' $true)){throw 'Main business or channel facts changed'}
 $taskReceipt.checks+='V039 applied with business and channel data unchanged';$taskReceipt.unchangedTables=$taskBusinessBefore.Count
 $taskDefault=Join-Path $WorkspaceRoot 'backend/ruoyi-admin/target/ruoyi-admin.jar'
 if(Test-Path -LiteralPath $taskDefault){$taskReceipt.priorDefaultJarSha256=(Get-FileHash -LiteralPath $taskDefault).Hash.ToLowerInvariant();Copy-Item -LiteralPath $taskDefault -Destination (Join-Path $taskOut 'prior-default.jar')}
 Copy-Item -LiteralPath $taskSource -Destination $taskDefault
 if((Get-FileHash -LiteralPath $taskDefault).Hash.ToLowerInvariant() -ne $taskBuild.jarSha256){throw 'Installed package bytes differ'}
 $taskReceipt.checks+='default startup package matches accepted candidate';$taskReceipt.mainListening=$false;$taskReceipt.state='INSTALLED_MAIN_STOPPED';$taskReceipt.passed=$true
}catch{$taskReceipt.failure=$_.Exception.Message;throw}
finally{Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue;$taskReceipt|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $taskOut 'receipt.json') -Encoding utf8;Write-Output ('Main staging evidence: '+$taskOut)}
