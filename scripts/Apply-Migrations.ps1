#requires -Version 7.0
# Existing V001 is initialized by Compose. Future migrations and history are atomic.
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
Set-Location -LiteralPath $WorkspaceRoot
$dockerCli = Get-DockerCommand
$files = Get-ChildItem -LiteralPath 'database/migrations' -File | Where-Object Name -Match '^V[0-9]+__[a-z0-9_]+\.sql$' | Sort-Object { [int]([regex]::Match($_.Name,'^V([0-9]+)').Groups[1].Value) }
$duplicates = $files | Group-Object { [int]([regex]::Match($_.Name,'^V([0-9]+)').Groups[1].Value) } | Where-Object Count -GT 1
if ($duplicates) { throw 'Duplicate migration versions are not allowed.' }
foreach ($file in $files) {
    $version = [regex]::Match($file.Name,'^(V[0-9]+)').Groups[1].Value
    $checksum = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $previous = & $dockerCli exec aisports-dev-postgres psql -U $env:POSTGRES_USER -d $env:POSTGRES_DB -Atc "SELECT checksum FROM aisports_schema_history WHERE version='$version'"
    Assert-NativeExit 'Migration ledger read'
    if ($previous) {
        if ($previous.Trim() -ne $checksum) { throw "$version checksum changed after application" }
        Write-Host "$version already applied, checksum verified."
        continue
    }
    $sql = Get-Content -LiteralPath $file.FullName -Raw
    if ($sql -match '(?im)^\s*(BEGIN|COMMIT|ROLLBACK)\s*;') { throw 'Future migrations must not contain transaction controls; this runner owns the transaction.' }
    # Serialize DDL; a racing duplicate ledger insert fails and rolls back the whole transaction.
    $script = @"
BEGIN;
SELECT pg_advisory_xact_lock(621045012);
$sql
INSERT INTO aisports_schema_history(version, checksum) VALUES ('$version', '$checksum');
COMMIT;
"@
    $script | & $dockerCli exec -i aisports-dev-postgres psql -U $env:POSTGRES_USER -d $env:POSTGRES_DB -v ON_ERROR_STOP=1
    Assert-NativeExit "Migration $version"
    Write-Host "$version applied."
}
