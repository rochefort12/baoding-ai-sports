#requires -Version 7.0
# Flyway 11.7.2 runs outside the application. It does not start PostgreSQL.
[CmdletBinding()]
param(
    [ValidateSet('migrate', 'validate', 'info')]
    [string]$Command = 'migrate',
    [string]$Database,
    [int]$Port = 0
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
if (!$Database) { $Database = $env:POSTGRES_DB }
if ($Port -eq 0) { $Port = [int]$env:POSTGRES_PORT }
if ($Database -notmatch '^[a-z_][a-z0-9_]*$') { throw 'Invalid database identifier' }
if ($Port -lt 1 -or $Port -gt 65535) { throw 'Invalid PostgreSQL port' }
if ($env:POSTGRES_USER -notmatch '^[a-z][a-z0-9_]{0,62}$') { throw 'Invalid database owner' }
if ($env:POSTGRES_USER -eq $env:APP_DB_USER) { throw 'Flyway must use the database owner, not the application role.' }
$listening = @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue | Where-Object LocalAddress -in @('127.0.0.1', '::1'))
if ($listening.Count -eq 0) { throw "PostgreSQL is not listening on 127.0.0.1:$Port. This command does not start the database." }
$dockerCli = Get-DockerCommand
$image = if ($env:POSTGRES_IMAGE) { $env:POSTGRES_IMAGE } else { 'postgres:17.11-bookworm' }
$probe = "SELECT CASE WHEN to_regclass('public.asp_account') IS NOT NULL AND to_regclass('public.flyway_schema_history') IS NULL THEN 'old-ledger' ELSE 'ok' END;"
$env:PGPASSWORD = $env:POSTGRES_PASSWORD
try {
    $state = & $dockerCli run --rm --add-host=host.docker.internal:host-gateway -e PGPASSWORD -e "PGUSER=$($env:POSTGRES_USER)" $image psql -h host.docker.internal -p $Port -d $Database -v ON_ERROR_STOP=1 -qAt -c $probe
    Assert-NativeExit 'Read migration ledger state'
} finally { Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue }
if ($state.Trim() -eq 'old-ledger') { throw 'This database already has business tables and no Flyway history. Rebuild that volume instead of baselining or replaying V001.' }
$env:FLYWAY_URL = "jdbc:postgresql://host.docker.internal:${Port}/${Database}"
$env:FLYWAY_USER = $env:POSTGRES_USER
$env:FLYWAY_PASSWORD = $env:POSTGRES_PASSWORD
$env:FLYWAY_LOCATIONS = 'filesystem:/flyway/sql'
$env:FLYWAY_PLACEHOLDER_REPLACEMENT = 'false'
$env:FLYWAY_CLEAN_DISABLED = 'true'
$env:FLYWAY_CONNECT_RETRIES = '0'
try {
    & $dockerCli run --rm --add-host=host.docker.internal:host-gateway `
        -e FLYWAY_URL -e FLYWAY_USER -e FLYWAY_PASSWORD -e FLYWAY_LOCATIONS `
        -e FLYWAY_PLACEHOLDER_REPLACEMENT -e FLYWAY_CLEAN_DISABLED -e FLYWAY_CONNECT_RETRIES `
        -v "${WorkspaceRoot}/database/migrations:/flyway/sql:ro" `
        flyway/flyway:11.7.2 $Command
    Assert-NativeExit "Flyway $Command"
} finally {
    Remove-Item Env:FLYWAY_PASSWORD -ErrorAction SilentlyContinue
}
Write-Host "Flyway $Command finished for database $Database on 127.0.0.1:$Port."
