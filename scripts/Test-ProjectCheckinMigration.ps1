#requires -Version 7.0
[CmdletBinding()]param([Parameter(Mandatory)][string]$FixtureDirectory)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$taskRuntime=Get-Content -LiteralPath "$WorkspaceRoot/.local/phase1-implementation/verification-runtime.json" -Raw|ConvertFrom-Json
if($taskRuntime.database -ne 'aisports_verify_phase1_242ded43673246699be6bb0f596aa59b'){throw 'Only the currently prepared isolated database is allowed'}
$taskFixture=[IO.Path]::GetFullPath($FixtureDirectory)
$taskAllowed=[IO.Path]::GetFullPath("$WorkspaceRoot/.local/project-checkin-20261012")+[IO.Path]::DirectorySeparatorChar
if(!$taskFixture.StartsWith($taskAllowed,[StringComparison]::OrdinalIgnoreCase)){throw 'Fixture outside protected run root'}
$taskState=Get-Content -LiteralPath (Join-Path $taskFixture 'state.private.json') -Raw|ConvertFrom-Json
foreach($taskId in @($taskState.event.id,$taskState.A.id,$taskState.B.id)){if($taskId -notmatch '^\d+$'){throw 'Invalid fixture ID'}}
$taskPg='C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin'
$taskOutput=Join-Path $taskFixture ('migration-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Path $taskOutput|Out-Null
$taskClone='aisports_verify_checkin_'+[guid]::NewGuid().ToString('N')
$taskReceipt=@{at=[DateTimeOffset]::Now.ToString('o');scope='Forward migration and constraints in a restored isolated clone, then exact isolated trial activation. No production changes.';database=$taskRuntime.database;clone=$taskClone;checks=@();passed=$false}
function Read-TaskFingerprint([string]$TaskDatabase,[switch]$WithoutUnit){
 $taskExpression=if($WithoutUnit){"to_jsonb(c)-'unit_id'"}else{'to_jsonb(c)'}
 $taskFingerprint=& "$taskPg/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $TaskDatabase -At -v ON_ERROR_STOP=1 -c "SELECT count(*)||':'||md5(COALESCE(string_agg(($taskExpression)::text,'|' ORDER BY id),'')) FROM asp_checkin c;"
 Assert-NativeExit 'Read complete attendance fingerprint';return $taskFingerprint.Trim()
}
$env:PGPASSWORD=$env:POSTGRES_PASSWORD
try{
 $taskVersion=& "$taskPg/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $taskRuntime.database -At -c "SELECT count(*) FROM aisports_schema_history WHERE version='V040';";Assert-NativeExit 'Read V040 gate'
 if($taskVersion.Trim() -ne '0'){throw 'V040 already applied; retain original evidence and use read-only verification instead'}
 $taskReceipt.before=Read-TaskFingerprint $taskRuntime.database
 $taskDump=Join-Path $taskOutput 'before.dump'
 & "$taskPg/pg_dump.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -Fc -f $taskDump $taskRuntime.database *> (Join-Path $taskOutput 'backup.log');Assert-NativeExit 'Fresh isolated backup'
 $taskReceipt.backupSha256=(Get-FileHash -LiteralPath $taskDump).Hash.ToLowerInvariant()
 & "$taskPg/createdb.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER --template=template0 $taskClone *> (Join-Path $taskOutput 'create-clone.log');Assert-NativeExit 'Create explicit isolated clone'
 & "$taskPg/pg_restore.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $taskClone $taskDump *> (Join-Path $taskOutput 'restore.log');Assert-NativeExit 'Restore full backup'
 if((Read-TaskFingerprint $taskClone) -ne $taskReceipt.before){throw 'Restored attendance fingerprint differs'};$taskReceipt.checks+='Fresh backup and independent restore preserve every attendance row'
 & "$PSScriptRoot/Apply-NativeMigrations.ps1" -PostgreSQLBin $taskPg -Database $taskClone
 $env:PGPASSWORD=$env:POSTGRES_PASSWORD
 if((Read-TaskFingerprint $taskClone -WithoutUnit) -ne $taskReceipt.before){throw 'Migration modified original attendance'};$taskReceipt.checks+='Forward migration preserves original rows without inferred project backfill'
 & "$PSScriptRoot/Apply-NativeMigrations.ps1" -PostgreSQLBin $taskPg -Database $taskClone
 $env:PGPASSWORD=$env:POSTGRES_PASSWORD
 if((Read-TaskFingerprint $taskClone -WithoutUnit) -ne $taskReceipt.before){throw 'Repeated migration changed attendance'};$taskReceipt.checks+='Repeated migration is ledger-idempotent'
 $taskSql=@"
BEGIN;
DO \$\$
DECLARE old asp_checkin%ROWTYPE; failures integer:=0;
BEGIN
 SELECT * INTO STRICT old FROM asp_checkin WHERE id=$($taskState.oldCheckin.checkInId);
 INSERT INTO asp_checkin(id,tenant_id,event_id,unit_id,person_id,check_type,status,verification,occurred_at,request_key)
 VALUES(8990000000000000001,old.tenant_id,old.event_id,$($taskState.A.id),old.person_id,'unit','confirmed','{}',CURRENT_TIMESTAMP,'scope-constraint-a'),
       (8990000000000000002,old.tenant_id,old.event_id,$($taskState.B.id),old.person_id,'unit','confirmed','{}',CURRENT_TIMESTAMP,'scope-constraint-b');
 BEGIN
  INSERT INTO asp_checkin(id,tenant_id,event_id,unit_id,person_id,check_type,status,verification,occurred_at,request_key)
  VALUES(8990000000000000003,old.tenant_id,old.event_id,$($taskState.A.id),old.person_id,'unit','confirmed','{}',CURRENT_TIMESTAMP,'scope-duplicate');
 EXCEPTION WHEN unique_violation THEN failures:=failures+1;END;
 BEGIN
  INSERT INTO asp_checkin(id,tenant_id,event_id,person_id,check_type,status,verification,occurred_at,request_key)
  VALUES(8990000000000000004,old.tenant_id,old.event_id,old.person_id,'unit','confirmed','{}',CURRENT_TIMESTAMP,'scope-null-unit');
 EXCEPTION WHEN check_violation THEN failures:=failures+1;END;
 BEGIN
  INSERT INTO asp_checkin(id,tenant_id,event_id,unit_id,person_id,check_type,status,verification,occurred_at,request_key)
  VALUES(8990000000000000005,old.tenant_id,old.event_id,8990000000000000009,old.person_id,'unit','confirmed','{}',CURRENT_TIMESTAMP,'scope-invalid-unit');
 EXCEPTION WHEN foreign_key_violation THEN failures:=failures+1;END;
 IF failures<>3 THEN RAISE EXCEPTION 'Expected all three independent constraint rejections';END IF;
END
\$\$;
ROLLBACK;
"@
 # Dollar quoting is literal PostgreSQL syntax; replace the PowerShell protection marker before stdin.
 $taskSql=$taskSql.Replace('\$\$','$$')
 $taskSql|& "$taskPg/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $taskClone -v ON_ERROR_STOP=1 *> (Join-Path $taskOutput 'constraints.log');Assert-NativeExit 'Project uniqueness, required scope and project foreign key'
 if((Read-TaskFingerprint $taskClone -WithoutUnit) -ne $taskReceipt.before){throw 'Constraint trial failed to roll back'};$taskReceipt.checks+='Separate projects coexist; duplicate project, missing project and invalid project rejected; all constraint fixtures rolled back'
 if((Read-TaskFingerprint $taskRuntime.database) -ne $taskReceipt.before){throw 'Live attendance changed since backup'}
 & "$PSScriptRoot/Apply-NativeMigrations.ps1" -PostgreSQLBin $taskPg -Database $taskRuntime.database
 $env:PGPASSWORD=$env:POSTGRES_PASSWORD
 if((Read-TaskFingerprint $taskRuntime.database -WithoutUnit) -ne $taskReceipt.before){throw 'Activated migration altered original attendance'};$taskReceipt.checks+='Same migration activated in the isolated trial with original attendance unchanged'
 $taskReceipt.migrationSha256=(Get-FileHash -LiteralPath "$WorkspaceRoot/database/migrations/V040__project_checkin_scope.sql").Hash.ToLowerInvariant();$taskReceipt.passed=$true
}catch{$taskReceipt.failure=$_.Exception.Message;throw}finally{Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue;$taskReceipt|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $taskOutput 'receipt.json') -Encoding utf8;Write-Host ('Evidence: '+$taskOutput)}
