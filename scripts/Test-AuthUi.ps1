#requires -Version 7.0
param([string]$NodeModulesRoot=(Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules'))
$ErrorActionPreference='Stop'
& node (Join-Path $PSScriptRoot 'Test-AuthUi.mjs') $NodeModulesRoot
if($LASTEXITCODE -ne 0){throw 'Isolated authentication UI verification failed.'}
