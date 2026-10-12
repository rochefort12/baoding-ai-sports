#requires -Version 7.0
<# Restore only this project's newly prepared snapshot, then verify V034 and replay. #>
[CmdletBinding()]param()
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$taskBin='C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin'
$taskOut=Join-Path $WorkspaceRoot '.local/product-release-20261011'
$taskReceiptFile=Get-ChildItem -LiteralPath $taskOut -Filter 'backups-*.json'|Sort-Object LastWriteTime -Descending|Select-Object -First 1
if(!$taskReceiptFile){throw 'Pre-migration backup receipt is required.'}
$taskBackup=Get-Content -LiteralPath $taskReceiptFile.FullName -Raw|ConvertFrom-Json|Where-Object database -eq $env:POSTGRES_DB|Select-Object -First 1
if(!$taskBackup -or $taskBackup.file -notmatch '^pre-product-aisports-[a-f0-9]{32}\.dump$'){throw 'Expected controller-local project snapshot.'}
$taskDump=Join-Path $taskOut $taskBackup.file
if((Get-FileHash -LiteralPath $taskDump).Hash.ToLowerInvariant()-ne $taskBackup.sha256){throw 'Backup bytes no longer match receipt.'}
$taskDb='aisports_product_restore_'+[guid]::NewGuid().ToString('N')
$taskCreated=$false
$taskLog=Join-Path $taskOut ('restore-'+[guid]::NewGuid().ToString('N')+'.log')
$taskBefore=$null;$taskAfter=$null
$env:PGPASSWORD=$env:POSTGRES_PASSWORD
try{
    & "$taskBin/createdb.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -T template0 $taskDb
    Assert-NativeExit 'Create owned product restore database';$taskCreated=$true
    & "$taskBin/pg_restore.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $taskDb --exit-on-error $taskDump *> $taskLog
    Assert-NativeExit 'Restore pre-migration snapshot'
    $taskSql="SELECT (SELECT count(*) FROM asp_event),(SELECT count(*) FROM asp_registration),(SELECT count(*) FROM asp_action_execution),(SELECT count(*) FROM asp_fee_obligation);"
    $taskBefore=& "$taskBin/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $taskDb -At -v ON_ERROR_STOP=1 -c $taskSql
    Assert-NativeExit 'Read restored preserved-business counts'
    & "$PSScriptRoot/Apply-NativeMigrations.ps1" -PostgreSQLBin $taskBin -Database $taskDb
    & "$PSScriptRoot/Apply-NativeMigrations.ps1" -PostgreSQLBin $taskBin -Database $taskDb
    $env:PGPASSWORD=$env:POSTGRES_PASSWORD
    $taskAfter=& "$taskBin/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $taskDb -At -v ON_ERROR_STOP=1 -c $taskSql
    Assert-NativeExit 'Read post-migration preserved-business counts'
    if($taskBefore.Trim()-ne $taskAfter.Trim()){throw 'A migration changed preserved business records.'}
    $taskNew=& "$taskBin/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $taskDb -At -v ON_ERROR_STOP=1 -c "SELECT count(*) FROM aisports_schema_history WHERE version='V034'; SELECT count(*) FROM asp_event WHERE operations_materials <> '{}'::jsonb;"
    Assert-NativeExit 'Verify material column default and durable migration ledger'
    if(($taskNew-join '|')-ne '1|0'){throw 'Unexpected material migration result.'}
    $taskReceipt=@{timestamp=[DateTimeOffset]::Now.ToString('o');backup=$taskBackup.file;backupSha256=$taskBackup.sha256;migration='V034';restoreAccepted=$true;repeatAccepted=$true;preservedCounts=$taskAfter.Trim();scope='Actual isolated PostgreSQL restore and forward/replay verification, no business event completion'}
    $taskReceipt|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $taskOut ('migration-'+[guid]::NewGuid().ToString('N')+'.json'))
    Write-Host 'PASS V034: real snapshot restored, migration and replay accepted; preserved business counts unchanged.'
}finally{
    $env:PGPASSWORD=$env:POSTGRES_PASSWORD
    if($taskCreated -and $taskDb-match '^aisports_product_restore_[a-f0-9]{32}$'){
        & "$taskBin/dropdb.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER $taskDb
        if($LASTEXITCODE-ne 0){Write-Warning 'Owned verification copy remains for diagnosis.'}
    }
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}
