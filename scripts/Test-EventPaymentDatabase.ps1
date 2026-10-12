#requires -Version 7.0
param([Parameter(Mandatory)][long]$EventId)
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$dockerCli = Get-DockerCommand
# 仅验证本轮模拟赛事的结构约束，每次插入都在回滚事务中；不改报名、资金或通过状态。
$sql = @"
BEGIN;
DO `$`$
DECLARE payload jsonb; target_tenant varchar(20);
BEGIN
  SELECT tenant_id INTO STRICT target_tenant FROM asp_event WHERE id=$EventId AND name LIKE '赛事统一收款测试-%（模拟）';
  FOR payload IN SELECT item FROM (VALUES ('{}'::jsonb), ('{"channels":[]}'::jsonb), ('{"schemaVersion":1}'::jsonb), ('{"schemaVersion":2,"channels":[]}'::jsonb), ('{"schemaVersion":1,"channels":null}'::jsonb), ('[]'::jsonb)) samples(item)
  LOOP
    BEGIN
      INSERT INTO asp_event_payment_config(id,tenant_id,event_id,settings) VALUES (9900280000000001,target_tenant,$EventId,payload);
      RAISE EXCEPTION 'Invalid payment settings unexpectedly passed CHECK';
    EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS invalid event payment contract rejected';
    END;
  END LOOP;
END `$`$;
ROLLBACK;
SELECT count(*) AS applied_payment_migrations FROM aisports_schema_history WHERE version IN ('V028','V029');
"@
$sql | & $dockerCli exec -i aisports-dev-postgres psql -U $env:POSTGRES_USER -d $env:POSTGRES_DB -v ON_ERROR_STOP=1
Assert-NativeExit 'Event payment database constraints'
