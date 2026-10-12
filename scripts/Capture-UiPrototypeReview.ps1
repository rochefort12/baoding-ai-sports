#requires -Version 7.0
param([ValidateSet('before','after')][string]$Stage='after',[int]$Port=5188)
$ErrorActionPreference='Stop'
$prototypeRoot=Join-Path (Split-Path $PSScriptRoot -Parent) 'docs/05-ui/prototype'
$nodeModulesRoot=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules'
& node (Join-Path $prototypeRoot 'capture-review.mjs') $nodeModulesRoot $Port $Stage
if($LASTEXITCODE -ne 0){throw 'Review capture failed.'}
