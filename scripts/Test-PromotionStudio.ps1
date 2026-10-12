#requires -Version 7.0
param([string]$NodeModulesRoot=(Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules'))
$ErrorActionPreference='Stop'
& node "$PSScriptRoot/Test-PromotionStudio.mjs" $NodeModulesRoot
if ($LASTEXITCODE -ne 0) { throw 'Promotion studio isolated UI verification failed.' }
