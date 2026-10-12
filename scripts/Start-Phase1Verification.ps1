#requires -Version 7.0
[CmdletBinding()] param([string]$PostgreSQLBin='C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin')
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
if(Get-NetTCPConnection -State Listen -LocalPort 8082 -ErrorAction SilentlyContinue){throw 'Verification port 8082 is already in use'}
$verificationDb='aisports_verify_phase1_'+[Guid]::NewGuid().ToString('N')
$prefix='aisports:verify:phase1:'+ [Guid]::NewGuid().ToString('N')+':'
$out=Join-Path $WorkspaceRoot '.local/phase1-implementation'
$backup=Join-Path $out ('http-test-source-'+[Guid]::NewGuid().ToString('N')+'.dump')
$env:PGPASSWORD=$env:POSTGRES_PASSWORD
try {
 & "$PostgreSQLBin/pg_dump.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -Fc -d $env:POSTGRES_DB -f $backup
 Assert-NativeExit 'Isolated HTTP test snapshot'
 & "$PostgreSQLBin/createdb.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -T template0 $verificationDb
 Assert-NativeExit 'Create isolated HTTP test database'
 & "$PostgreSQLBin/pg_restore.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $verificationDb --exit-on-error $backup *> (Join-Path $out 'http-test-restore.log')
 Assert-NativeExit 'Restore isolated HTTP test database'
} finally {Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue}
$env:POSTGRES_DB=$verificationDb
$env:MCP_ENABLED='true'
$jar=Join-Path $WorkspaceRoot 'backend/ruoyi-admin/target/ruoyi-admin.jar'
$process=Start-Process -FilePath 'D:/dev/jdk17/bin/java.exe' -ArgumentList @('-Xmx768m','-jar',"`"$jar`"",'--spring.profiles.active=local','--server.port=8082','--server.address=127.0.0.1','--captcha.enable=false',('--redisson.keyPrefix='+$prefix),'--aisports.ai.daily-tasks=100') -WorkingDirectory "$WorkspaceRoot/backend" -WindowStyle Hidden -RedirectStandardOutput (Join-Path $out 'http-test-runtime.log') -RedirectStandardError (Join-Path $out 'http-test-error.log') -PassThru
@{database=$verificationDb;redisPrefix=$prefix;pid=$process.Id;port=8082;jarSHA256=(Get-FileHash -LiteralPath $jar).Hash.ToLowerInvariant();createdAt=(Get-Date).ToString('o');scope='Isolated local service tests with simulated people and money; not a real event acceptance'}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out 'verification-runtime.json') -Encoding utf8
Write-Host 'Isolated local verification backend dispatched on port 8082.'
