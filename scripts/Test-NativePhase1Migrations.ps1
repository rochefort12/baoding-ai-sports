#requires -Version 7.0
[CmdletBinding()]
param([string]$PostgreSQLBin='C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin')
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$client=[IO.Path]::GetFullPath($PostgreSQLBin)
$verificationDb='aisports_verify_phase1_'+[Guid]::NewGuid().ToString('N')
if($verificationDb -notmatch '^aisports_verify_phase1_[0-9a-f]{32}$'){throw 'Invalid isolated verification database'}
$output=Join-Path $WorkspaceRoot '.local/phase1-implementation'
$backup=Join-Path $output ('before-phase1-'+[Guid]::NewGuid().ToString('N')+'.dump')
$env:PGPASSWORD=$env:POSTGRES_PASSWORD
$created=$false
try {
 & "$client/pg_dump.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -Fc -d $env:POSTGRES_DB -f $backup
 Assert-NativeExit 'Create pre-migration backup'
 & "$client/createdb.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -T template0 $verificationDb
 Assert-NativeExit 'Create isolated verification database';$created=$true
 & "$client/pg_restore.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $verificationDb --exit-on-error $backup *> (Join-Path $output 'migration-phase1-restore.log')
 Assert-NativeExit 'Restore verification copy'
 & "$PSScriptRoot/Apply-NativeMigrations.ps1" -PostgreSQLBin $client -Database $verificationDb
 $env:PGPASSWORD=$env:POSTGRES_PASSWORD
 $first=& "$client/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $verificationDb -At -v ON_ERROR_STOP=1 -c "SELECT (SELECT count(*) FROM asp_agent WHERE status='active'),(SELECT count(*) FROM asp_agent_version WHERE status='active'),(SELECT count(*) FROM asp_growth_policy WHERE status='active'),(SELECT count(*) FROM asp_capability_activation WHERE enabled);"
 Assert-NativeExit 'Verify seeded policy and closed capability gates'
 if($first.Trim() -ne '8|8|1|0'){throw "Unexpected migration verification counts: $first"}
 & "$PSScriptRoot/Apply-NativeMigrations.ps1" -PostgreSQLBin $client -Database $verificationDb
 $receipt=@{time=(Get-Date).ToString('o');migration='V030-V033';backup=[IO.Path]::GetFileName($backup);backupSHA256=(Get-FileHash -LiteralPath $backup).Hash.ToLowerInvariant();seedCounts=$first.Trim();repeatApplied=$true;scope='Isolated restore and migration replay only; no real-model or business acceptance'}
 $receipt|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $output 'migration-phase1-receipt.json') -Encoding utf8
 Write-Host 'PASS: isolated restore, V030-V033 seed validation, and identical migration replay. Capability gates remain closed.'
} finally {
 $env:PGPASSWORD=$env:POSTGRES_PASSWORD
 if($created -and $verificationDb -match '^aisports_verify_phase1_[0-9a-f]{32}$'){ & "$client/dropdb.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER $verificationDb }
 Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}
