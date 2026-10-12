#requires -Version 7.0
$ErrorActionPreference = 'Stop'
Push-Location -LiteralPath (Split-Path $PSScriptRoot -Parent)
try {
    & 'D:/dev/nodejs/node.exe' (Join-Path $PSScriptRoot 'Test-MobileManagementEntry.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'Mobile management navigation check failed; sanitized receipt retained.' }
} finally { Pop-Location }
