#requires -Version 7.0
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
Set-Location -LiteralPath $WorkspaceRoot
$dockerCli = Get-DockerCommand
& "$PSScriptRoot/Invoke-Flyway.ps1" -Command validate
$expectedCount = @(Get-ChildItem -LiteralPath 'database/migrations' -File | Where-Object Name -Match '^V[0-9]+__[a-z0-9_]+\.sql$').Count
$appliedCount = & $dockerCli exec aisports-dev-postgres psql -U $env:POSTGRES_USER -d $env:POSTGRES_DB -Atc "SELECT count(*) FROM flyway_schema_history WHERE success"
Assert-NativeExit 'Migration history verification'
if ([int]$appliedCount.Trim() -ne $expectedCount) { throw "Expected $expectedCount successful Flyway migrations, found $($appliedCount.Trim())." }
Get-Content -LiteralPath 'database/verification/preparation.sql' -Raw | & $dockerCli exec -i aisports-dev-postgres psql -U $env:POSTGRES_USER -d $env:POSTGRES_DB -v ON_ERROR_STOP=1
Assert-NativeExit 'Database structural checks'
$previousPassword = $env:PGPASSWORD
try {
    $env:PGPASSWORD = $env:APP_DB_PASSWORD
    & $dockerCli exec -e PGPASSWORD aisports-dev-postgres psql -h 127.0.0.1 -U $env:APP_DB_USER -d $env:POSTGRES_DB -Atc "SELECT 'APP_ROLE_OK', NOT rolsuper, NOT rolcreatedb, NOT rolcreaterole FROM pg_roles WHERE rolname=current_user; SELECT count(*) FROM sys_user; SELECT has_schema_privilege(current_user,'public','CREATE');"
    Assert-NativeExit 'Application database credentials'
} finally { $env:PGPASSWORD = $previousPassword }
$redisResult = & $dockerCli exec aisports-dev-redis redis-cli ping
Assert-NativeExit 'Redis connectivity'
if ($redisResult.Trim() -ne 'PONG') { throw 'Redis did not respond with PONG' }
Write-Host 'PASS: Flyway validate, application role authentication and Redis.'
