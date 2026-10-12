#requires -Version 7.0
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
Set-Location -LiteralPath $WorkspaceRoot
$dockerCli = Get-DockerCommand
foreach ($migrationFile in Get-ChildItem -LiteralPath 'database/migrations' -File | Where-Object Name -Match '^V[0-9]+__.*\.sql$') {
    $version = [regex]::Match($migrationFile.Name,'^(V[0-9]+)').Groups[1].Value
    $expectedHash = (Get-FileHash -LiteralPath $migrationFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $actualHash = & $dockerCli exec aisports-dev-postgres psql -U $env:POSTGRES_USER -d $env:POSTGRES_DB -Atc "SELECT checksum FROM aisports_schema_history WHERE version='$version'"
    Assert-NativeExit 'Migration history verification'
    if (!$actualHash -or $actualHash.Trim() -ne $expectedHash) { throw "$version absent or checksum differs; apply a reviewed migration instead of rewriting deployed DDL." }
}
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
Write-Host 'PASS: migration checksum, application role authentication and Redis.'
