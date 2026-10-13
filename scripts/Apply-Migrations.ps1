#requires -Version 7.0
# Apply pending Flyway migrations. Does not start PostgreSQL or the application.
[CmdletBinding()]
param([string]$Database)
$ErrorActionPreference = 'Stop'
& "$PSScriptRoot/Invoke-Flyway.ps1" -Command migrate -Database $Database
