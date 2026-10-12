#requires -Version 7.0
$ErrorActionPreference = 'Stop'
$taskWorkspace = Split-Path $PSScriptRoot -Parent
$taskNode = 'D:/dev/nodejs/node.exe'
if (!(Test-Path -LiteralPath $taskNode)) { throw 'Expected project Node runtime is unavailable.' }
Push-Location -LiteralPath $taskWorkspace
try {
    & $taskNode (Join-Path $PSScriptRoot 'Test-ThreePersonPreparationUi.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'Read-only preparation UI check failed; inspect its protected sanitized receipt.' }
} finally { Pop-Location }
