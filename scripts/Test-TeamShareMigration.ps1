#requires -Version 7.0
[CmdletBinding()]param([Parameter(Mandatory)][string]$RootDirectory)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$taskRuntime=Get-Content -LiteralPath "$WorkspaceRoot/.local/phase1-implementation/verification-runtime.json" -Raw|ConvertFrom-Json
if($taskRuntime.database -ne 'aisports_verify_phase1_242ded43673246699be6bb0f596aa59b'){throw 'Only the exact prepared isolated database is allowed'}
$taskRoot=[IO.Path]::GetFullPath($RootDirectory)
$taskAllowed=[IO.Path]::GetFullPath("$WorkspaceRoot/.local/team-invite-experience-20261012")+[IO.Path]::DirectorySeparatorChar
if(!$taskRoot.StartsWith($taskAllowed,[StringComparison]::OrdinalIgnoreCase)){throw 'Run outside protected team invitation root'}
New-Item -ItemType Directory -Path $taskRoot -Force|Out-Null
$taskOutput=Join-Path $taskRoot ('migration-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Path $taskOutput|Out-Null
$taskPg='C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin'
$taskClone='aisports_verify_teamshare_'+[guid]::NewGuid().ToString('N')
$taskReceipt=@{at=[DateTimeOffset]::Now.ToString('o');scope='V041 forward migration in a backed-up independent restore, then exact isolated trial only; no production changes.';database=$taskRuntime.database;clone=$taskClone;checks=@();passed=$false}
function Read-TaskFingerprint([string]$TaskDatabase,[switch]$OriginalColumns){
 $taskExpression=if($OriginalColumns){"to_jsonb(c)-ARRAY['invitation_kind','inviter_person_id','invite_token','expires_at','share_invitation_id']::text[]"}else{'to_jsonb(c)'}
 $taskValue=& "$taskPg/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $TaskDatabase -At -v ON_ERROR_STOP=1 -c "SELECT count(*)||':'||md5(COALESCE(string_agg(($taskExpression)::text,'|' ORDER BY id),'')) FROM asp_team_invitation c;"
 Assert-NativeExit 'Read invitation fingerprint';return $taskValue.Trim()
}
$env:PGPASSWORD=$env:POSTGRES_PASSWORD
try{
 $taskVersion=& "$taskPg/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $taskRuntime.database -At -v ON_ERROR_STOP=1 -c "SELECT count(*) FROM aisports_schema_history WHERE version='V041';";Assert-NativeExit 'Read V041 gate'
 if($taskVersion.Trim() -ne '0'){throw 'V041 already applied; do not replay migration trial, use original receipt and read-only checks'}
 $taskReceipt.before=Read-TaskFingerprint $taskRuntime.database
 $taskDump=Join-Path $taskOutput 'before.dump'
 & "$taskPg/pg_dump.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -Fc -f $taskDump $taskRuntime.database *> (Join-Path $taskOutput 'backup.log');Assert-NativeExit 'Fresh isolated backup'
 $taskReceipt.backupSha256=(Get-FileHash -LiteralPath $taskDump).Hash.ToLowerInvariant()
 & "$taskPg/createdb.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER --template=template0 $taskClone *> (Join-Path $taskOutput 'create-clone.log');Assert-NativeExit 'Create explicit isolated clone'
 & "$taskPg/pg_restore.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $taskClone $taskDump *> (Join-Path $taskOutput 'restore.log');Assert-NativeExit 'Restore full backup'
 if((Read-TaskFingerprint $taskClone) -ne $taskReceipt.before){throw 'Restored original invitation fingerprint differs'}
 $taskReceipt.checks+='Fresh backup and independent restore preserve every original invitation column'
 & "$PSScriptRoot/Apply-NativeMigrations.ps1" -PostgreSQLBin $taskPg -Database $taskClone
 $env:PGPASSWORD=$env:POSTGRES_PASSWORD
 if((Read-TaskFingerprint $taskClone -OriginalColumns) -ne $taskReceipt.before){throw 'V041 modified original invitation facts'}
 $taskDefaults=& "$taskPg/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $taskClone -At -v ON_ERROR_STOP=1 -c "SELECT count(*) FROM asp_team_invitation WHERE invitation_kind<>'direct' OR inviter_person_id IS NOT NULL OR invite_token IS NOT NULL OR expires_at IS NOT NULL OR share_invitation_id IS NOT NULL;";Assert-NativeExit 'Check historical direct defaults'
 if($taskDefaults.Trim() -ne '0'){throw 'Migration invented share data for old invitations'}
 $taskReceipt.checks+='Forward migration leaves every original fact intact and defaults old invitations to direct without inferred share data'
 & "$PSScriptRoot/Apply-NativeMigrations.ps1" -PostgreSQLBin $taskPg -Database $taskClone
 $env:PGPASSWORD=$env:POSTGRES_PASSWORD
 if((Read-TaskFingerprint $taskClone -OriginalColumns) -ne $taskReceipt.before){throw 'Repeated migration modified original invitations'}
 $taskReceipt.checks+='Migration replay is ledger-idempotent'
 $taskSql=@'
BEGIN;
DO $$
DECLARE t asp_team%ROWTYPE; a bigint; failures integer:=0;
BEGIN
 SELECT * INTO STRICT t FROM asp_team ORDER BY id LIMIT 1;
 SELECT id INTO STRICT a FROM asp_account WHERE person_id=t.captain_person_id ORDER BY id LIMIT 1;
 INSERT INTO asp_team_invitation(id,team_id,inviter_account_id,inviter_person_id,invitation_kind,invite_token,expires_at,status)
 VALUES(8980000000000000001,t.id,a,t.captain_person_id,'share',repeat('a',64),CURRENT_TIMESTAMP+INTERVAL '7 days','pending');
 INSERT INTO asp_team_invitation(id,team_id,inviter_account_id,target_person_id,invitation_kind,share_invitation_id,status)
 VALUES(8980000000000000002,t.id,a,t.captain_person_id,'direct',8980000000000000001,'accepted');
 BEGIN
  INSERT INTO asp_team_invitation(id,team_id,inviter_account_id,invitation_kind,status)
  VALUES(8980000000000000003,t.id,a,'direct','pending');
 EXCEPTION WHEN check_violation THEN failures:=failures+1;END;
 BEGIN
  INSERT INTO asp_team_invitation(id,team_id,inviter_account_id,inviter_person_id,invitation_kind,invite_token,expires_at,status)
  VALUES(8980000000000000004,t.id,a,t.captain_person_id,'share','invalid',CURRENT_TIMESTAMP+INTERVAL '7 days','revoked');
 EXCEPTION WHEN check_violation THEN failures:=failures+1;END;
 BEGIN
  INSERT INTO asp_team_invitation(id,team_id,inviter_account_id,target_person_id,invitation_kind,share_invitation_id,status)
  VALUES(8980000000000000005,t.id,a,t.captain_person_id,'direct',8980000000000000001,'accepted');
 EXCEPTION WHEN unique_violation THEN failures:=failures+1;END;
 BEGIN
  INSERT INTO asp_team_invitation(id,team_id,inviter_account_id,inviter_person_id,invitation_kind,invite_token,expires_at,status)
  VALUES(8980000000000000006,t.id,a,t.captain_person_id,'share',repeat('b',64),CURRENT_TIMESTAMP+INTERVAL '7 days','pending');
 EXCEPTION WHEN unique_violation THEN failures:=failures+1;END;
 BEGIN
  INSERT INTO asp_team_invitation(id,team_id,inviter_account_id,target_person_id,invitation_kind,share_invitation_id,status)
  VALUES(8980000000000000007,t.id,a,t.captain_person_id,'direct',8980000000000000099,'accepted');
 EXCEPTION WHEN foreign_key_violation THEN failures:=failures+1;END;
 BEGIN
  INSERT INTO asp_team_invitation(id,team_id,inviter_account_id,inviter_person_id,invitation_kind,invite_token,expires_at,status)
  VALUES(8980000000000000008,t.id,a,8980000000000000099,'share',repeat('c',64),CURRENT_TIMESTAMP+INTERVAL '7 days','revoked');
 EXCEPTION WHEN foreign_key_violation THEN failures:=failures+1;END;
 IF failures<>6 THEN RAISE EXCEPTION 'Expected all six independent invitation constraint rejections';END IF;
END
$$;
ROLLBACK;
'@
 $taskSql|& "$taskPg/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $taskClone -v ON_ERROR_STOP=1 *> (Join-Path $taskOutput 'constraints.log');Assert-NativeExit 'Share shape, token, unique acceptance/grant, source and captain foreign keys'
 if((Read-TaskFingerprint $taskClone -OriginalColumns) -ne $taskReceipt.before){throw 'Constraint trial failed to roll back'}
 $taskReceipt.checks+='Share without target and directed acceptance valid; missing direct target, malformed token, duplicate acceptance/grant and invalid source/captain rejected; all fixtures rolled back'
 if((Read-TaskFingerprint $taskRuntime.database) -ne $taskReceipt.before){throw 'Live invitations changed since backup; retain clone evidence and retry after review'}
 & "$PSScriptRoot/Apply-NativeMigrations.ps1" -PostgreSQLBin $taskPg -Database $taskRuntime.database
 $env:PGPASSWORD=$env:POSTGRES_PASSWORD
 if((Read-TaskFingerprint $taskRuntime.database -OriginalColumns) -ne $taskReceipt.before){throw 'Activated migration altered historical invitations'}
 $taskReceipt.checks+='Same migration activated only in exact isolated trial with original invitation fingerprint unchanged'
 $taskReceipt.migrationSha256=(Get-FileHash -LiteralPath "$WorkspaceRoot/database/migrations/V041__team_share_invitation.sql").Hash.ToLowerInvariant();$taskReceipt.passed=$true
}catch{$taskReceipt.failure=$_.Exception.Message;throw}finally{
 Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
 $taskReceipt|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $taskOutput 'receipt.json') -Encoding utf8
 Write-Host ('Evidence: '+$taskOutput)
}
