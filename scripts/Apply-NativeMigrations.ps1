#requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$PostgreSQLBin,[string]$Database)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
if (!$Database) { $Database=$env:POSTGRES_DB }
if ($Database -notmatch '^[a-z_][a-z0-9_]*$') { throw 'Invalid database identifier' }
$psql=Join-Path ([IO.Path]::GetFullPath($PostgreSQLBin)) 'psql.exe'
if (!(Test-Path -LiteralPath $psql)) { throw 'Native PostgreSQL client unavailable' }
$out=Join-Path $WorkspaceRoot '.local/phase1-implementation'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$env:PGPASSWORD=$env:POSTGRES_PASSWORD
try {
 $files=Get-ChildItem -LiteralPath "$WorkspaceRoot/database/migrations" -File | Where-Object Name -Match '^V[0-9]+__[a-z0-9_]+\.sql$' | Sort-Object { [int]([regex]::Match($_.Name,'^V([0-9]+)').Groups[1].Value) }
 if ($files | Group-Object { [regex]::Match($_.Name,'^V[0-9]+').Value } | Where-Object Count -GT 1) { throw 'Duplicate migration version' }
 foreach ($file in $files) {
  $version=[regex]::Match($file.Name,'^V[0-9]+').Value
  $checksum=(Get-FileHash -LiteralPath $file.FullName).Hash.ToLowerInvariant()
  $previous=& $psql -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $Database -At -c "SELECT checksum FROM aisports_schema_history WHERE version='$version'"
  Assert-NativeExit 'Read migration ledger'
  if ($previous) { if ($previous.Trim() -ne $checksum) { throw "$version checksum differs from applied history" }; continue }
  $sql=Get-Content -LiteralPath $file.FullName -Raw
  if ($sql -match '(?im)^\s*(BEGIN|COMMIT|ROLLBACK)\s*;') { throw 'Runner owns migration transaction' }
  $script="BEGIN; SELECT pg_advisory_xact_lock(621045012);`n$sql`nINSERT INTO aisports_schema_history(version,checksum) VALUES ('$version','$checksum'); COMMIT;"
  $script | & $psql -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $Database -v ON_ERROR_STOP=1 *> (Join-Path $out ("migration-$version-"+$Database+'.log'))
  Assert-NativeExit "Apply $version"
  Write-Host "$version applied atomically."
 }
} finally { Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue }
