#requires -Version 7.0
[CmdletBinding()]
param([switch]$Start)
. "$PSScriptRoot/Common.ps1"
Set-Location -LiteralPath $WorkspaceRoot
if (!(Test-Path -LiteralPath '.env')) {
    $content = Get-Content -LiteralPath '.env.example' -Raw
    foreach ($key in @('POSTGRES_PASSWORD', 'APP_DB_PASSWORD', 'REDIS_PASSWORD', 'JWT_SECRET', 'MONITOR_PASSWORD')) {
        $secret = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant()
        $content = $content.Replace("$key=GENERATE_LOCALLY", "$key=$secret")
    }
    [IO.File]::WriteAllText((Join-Path $WorkspaceRoot '.env'), $content)
}
Import-LocalEnvironment
# Only safe identifiers/hex credentials are accepted in generated SQL/config.
foreach ($key in @('POSTGRES_DB','POSTGRES_USER','APP_DB_USER')) {
    if ([Environment]::GetEnvironmentVariable($key) -notmatch '^[a-z][a-z0-9_]{0,62}$') { throw "Invalid identifier: $key" }
}
foreach ($key in @('POSTGRES_PASSWORD','APP_DB_PASSWORD','REDIS_PASSWORD','JWT_SECRET','MONITOR_PASSWORD')) {
    if ([Environment]::GetEnvironmentVariable($key) -notmatch '^[a-f0-9]{64}$') { throw "Use generated hex credentials for $key" }
}
New-Item -ItemType Directory -Path '.local/postgres', '.local/redis' -Force | Out-Null
$roleSql = @"
CREATE ROLE $env:APP_DB_USER LOGIN PASSWORD '$env:APP_DB_PASSWORD' NOSUPERUSER NOCREATEDB NOCREATEROLE;
GRANT CONNECT ON DATABASE $env:POSTGRES_DB TO $env:APP_DB_USER;
GRANT USAGE ON SCHEMA public TO $env:APP_DB_USER;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO $env:APP_DB_USER;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO $env:APP_DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $env:APP_DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO $env:APP_DB_USER;
"@
[IO.File]::WriteAllText((Join-Path $WorkspaceRoot '.local/postgres/90-role-and-history.sql'), $roleSql)
$redisConfig = "bind 0.0.0.0`nprotected-mode yes`nport 6379`nappendonly yes`nrequirepass $env:REDIS_PASSWORD`n"
[IO.File]::WriteAllText((Join-Path $WorkspaceRoot '.local/redis/redis.conf'), $redisConfig)
# Local frontend overrides contain no credentials.
[IO.File]::WriteAllText((Join-Path $WorkspaceRoot 'plus-ui/.env.development.local'), "VITE_APP_TITLE=AISports 体育服务平台`nVITE_APP_PORT=5173`nVITE_APP_ENCRYPT=false`n")
$dockerCli = Get-DockerCommand
& $dockerCli compose config --quiet
Assert-NativeExit 'Compose configuration validation'
if ($Start) {
    & $dockerCli compose pull
    Assert-NativeExit 'Image pull'
    & $dockerCli compose up -d --wait --wait-timeout 120
    Assert-NativeExit 'Environment startup'
    & "$PSScriptRoot/Apply-Migrations.ps1"
    & "$PSScriptRoot/Test-Infrastructure.ps1"
}
Write-Host 'Private configuration ready. Secrets were not printed. Existing data volumes are retained.'
