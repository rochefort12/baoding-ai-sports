#requires -Version 7.0
[CmdletBinding()]
param([ValidateSet('migrate','validate','info','baseline')][string]$Command='migrate')
. "$PSScriptRoot/DockerStack.Common.ps1"
if ($env:POSTGRES_DB -ne 'aisports_docker_fresh') { throw 'Flyway is only permitted on the new Docker baseline database, never the retained legacy copy.' }
if ($env:POSTGRES_USER -eq $env:APP_DB_USER) { throw 'Flyway requires a separate database owner.' }
$taskLedger = Invoke-DockerSql "SELECT CASE WHEN to_regclass('public.asp_account') IS NOT NULL AND to_regclass('public.flyway_schema_history') IS NULL THEN 'old-ledger' ELSE 'ok' END"
if ($taskLedger.Trim() -ne 'ok') { throw 'An existing business database without Flyway history cannot receive the new baseline.' }
if ($Command -eq 'baseline') {
    $taskFresh = Get-Content -LiteralPath "$taskRoot/fresh-bootstrap.json" -Raw | ConvertFrom-Json
    $taskBusiness = Invoke-DockerSql "SELECT count(*) FROM pg_tables WHERE schemaname='public' AND tablename LIKE 'asp_%'"
    $taskHistory = Invoke-DockerSql "SELECT to_regclass('public.flyway_schema_history') IS NOT NULL"
    if (!$taskFresh.frameworkReady -or $taskFresh.initialized -or [int]$taskBusiness -ne 0 -or $taskHistory.Trim() -ne 'f') { throw 'Version-zero marker is allowed only before business migration on this newly initialized framework-only database.' }
}
# The application receives neither migration credentials nor migration responsibility.
$env:FLYWAY_URL = "jdbc:postgresql://postgres:5432/$env:POSTGRES_DB"
$env:FLYWAY_USER = $env:POSTGRES_USER
$env:FLYWAY_PASSWORD = $env:POSTGRES_PASSWORD
try {
    & $taskDocker run --rm --name ('aisports-dev-docker-flyway-'+[guid]::NewGuid().ToString('N')) --network aisports-dev-docker-network --security-opt no-new-privileges:true `
        -e FLYWAY_URL -e FLYWAY_USER -e FLYWAY_PASSWORD -e FLYWAY_PLACEHOLDER_REPLACEMENT=false -e FLYWAY_CLEAN_DISABLED=true -e FLYWAY_BASELINE_ON_MIGRATE=false -e FLYWAY_BASELINE_VERSION=0 -e FLYWAY_BASELINE_DESCRIPTION=framework-only-initialization `
        -v "${WorkspaceRoot}/database/migrations:/flyway/sql:ro" flyway/flyway:11.7.2 $Command *> "$taskRoot/flyway-$Command.log"
    Assert-NativeExit "Flyway $Command (private migration log)"
} finally { Remove-Item Env:FLYWAY_PASSWORD -ErrorAction SilentlyContinue }
Write-Host "Flyway $Command passed on the isolated fresh Docker database."
