#requires -Version 7.0
<# .SYNOPSIS 检查已启动的本地 UI 原型，仅验证虚构交互与截图，不代表业务验收。 #>
param([int]$Port=5188,[string]$NodeModulesRoot=(Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules'))
$ErrorActionPreference='Stop'
$prototypeRoot=Join-Path (Split-Path $PSScriptRoot -Parent) 'docs/05-ui/prototype'
& node (Join-Path $prototypeRoot 'verify.mjs') $NodeModulesRoot $Port
if($LASTEXITCODE -ne 0){throw 'UI prototype verification failed.'}
