#requires -Version 7.0
# 清空本机 aisports-dev 库中的业务测试数据，并清掉本项目 Redis。
# 不删除表结构、迁移记录、框架初始化，也不操作其他项目的容器。
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
Set-Location -LiteralPath $WorkspaceRoot
$dockerCli = Get-DockerCommand

function Assert-ProjectContainer([string]$Name) {
    $actual = (& $dockerCli inspect -f '{{.Name}}' $Name).Trim()
    Assert-NativeExit "Inspect $Name"
    if ($actual -ne "/$Name") { throw "Refusing to touch a container other than $Name." }
}

Assert-ProjectContainer 'aisports-dev-postgres'
Assert-ProjectContainer 'aisports-dev-redis'

$sqlPath = Join-Path $WorkspaceRoot 'database/seed/reset-test-data.sql'
if (!(Test-Path -LiteralPath $sqlPath)) { throw 'Reset SQL is missing.' }
$sql = Get-Content -LiteralPath $sqlPath -Raw
if ($sql -match '(?im)^\s*(BEGIN|COMMIT|ROLLBACK)\s*;') { throw 'Reset SQL must not contain transaction controls.' }

$script = @"
BEGIN;
SELECT pg_advisory_xact_lock(621045014);
$sql
COMMIT;
"@
$script | & $dockerCli exec -i aisports-dev-postgres psql -U $env:POSTGRES_USER -d $env:POSTGRES_DB -v ON_ERROR_STOP=1
Assert-NativeExit 'Reset test data'

& $dockerCli exec -e "REDISCLI_AUTH=$($env:REDIS_PASSWORD)" aisports-dev-redis redis-cli --no-auth-warning FLUSHDB
Assert-NativeExit 'Flush project Redis'

$check = @'
SELECT 'account' AS item, count(*)::text AS total FROM asp_account
UNION ALL SELECT 'person', count(*)::text FROM asp_person
UNION ALL SELECT 'event', count(*)::text FROM asp_event
UNION ALL SELECT 'organization', count(*)::text FROM asp_organization
UNION ALL SELECT 'registration', count(*)::text FROM asp_registration
UNION ALL SELECT 'tenant', count(*)::text FROM sys_tenant
UNION ALL SELECT 'user', count(*)::text FROM sys_user
UNION ALL SELECT 'sport', count(*)::text FROM asp_sport
UNION ALL SELECT 'migration', count(*)::text FROM aisports_schema_history
ORDER BY item;
'@
$check | & $dockerCli exec -i aisports-dev-postgres psql -U $env:POSTGRES_USER -d $env:POSTGRES_DB -v ON_ERROR_STOP=1
Assert-NativeExit 'Reset verification'
Write-Host 'Local test data reset.'
