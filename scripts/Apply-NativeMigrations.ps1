#requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$PostgreSQLBin,[string]$Database)
$ErrorActionPreference = 'Stop'
$psql = Join-Path ([IO.Path]::GetFullPath($PostgreSQLBin)) 'psql.exe'
if (!(Test-Path -LiteralPath $psql)) { throw 'Native PostgreSQL client unavailable' }
& "$PSScriptRoot/Invoke-Flyway.ps1" -Command migrate -Database $Database
