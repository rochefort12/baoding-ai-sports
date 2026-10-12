#requires -Version 7.0
# 初始化当前 M1.1 登录边界。只补齐初始化登录，不删除后来注册的账号。重复执行不重复建号。
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
Set-Location -LiteralPath $WorkspaceRoot
$dockerCli = Get-DockerCommand
$sqlPath = Join-Path $WorkspaceRoot 'database/seed/m11-participant.sql'
if (!(Test-Path -LiteralPath $sqlPath)) { throw 'M1.1 seed file is missing.' }
$sql = Get-Content -LiteralPath $sqlPath -Raw
if ($sql -match '(?im)^\s*(BEGIN|COMMIT|ROLLBACK)\s*;') { throw 'Seed file must not contain transaction controls.' }
$script = @"
BEGIN;
SELECT pg_advisory_xact_lock(621045013);
$sql
COMMIT;
"@
$script | & $dockerCli exec -i aisports-dev-postgres psql -U $env:POSTGRES_USER -d $env:POSTGRES_DB -v ON_ERROR_STOP=1
Assert-NativeExit 'M1.1 data initialization'
$check = @"
SELECT 'tenant' AS item, company_name AS detail FROM sys_tenant WHERE tenant_id = '100001'
UNION ALL
SELECT 'role', role_key FROM sys_role WHERE role_id = 2106100000000000001
UNION ALL
SELECT 'menu', menu_name FROM sys_menu WHERE menu_id = 2106100000000000003
UNION ALL
SELECT 'role_menu', count(*)::text FROM sys_role_menu WHERE role_id = 2106100000000000001
UNION ALL
SELECT 'role_dept', count(*)::text FROM sys_role_dept WHERE role_id = 2106100000000000001
UNION ALL
SELECT 'user', user_name FROM sys_user WHERE tenant_id = '100001' AND user_name = '13800001001' AND del_flag = '0'
UNION ALL
SELECT 'user_role', count(*)::text
FROM sys_user_role r
JOIN sys_user u ON u.user_id = r.user_id
WHERE u.tenant_id = '100001' AND u.user_name = '13800001001' AND r.role_id = 2106100000000000001
UNION ALL
SELECT 'account', a.status
FROM asp_account a
JOIN sys_user u ON u.user_id = a.backend_user_id
WHERE u.tenant_id = '100001' AND u.user_name = '13800001001'
UNION ALL
SELECT 'phone_channel', i.channel
FROM asp_login_identity i
JOIN asp_account a ON a.id = i.account_id
JOIN sys_user u ON u.user_id = a.backend_user_id
WHERE u.user_name = '13800001001' AND i.valid_until IS NULL
UNION ALL
SELECT 'extra_user', count(*)::text
FROM sys_user
WHERE tenant_id = '100001' AND user_name <> '13800001001';
"@
$check | & $dockerCli exec -i aisports-dev-postgres psql -U $env:POSTGRES_USER -d $env:POSTGRES_DB -v ON_ERROR_STOP=1
Assert-NativeExit 'M1.1 data check'
Write-Host 'M1.1 data initialized.'
