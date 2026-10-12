#requires -Version 7.0
<# .SYNOPSIS 验证正式 C 端 AI 交互与响应式布局；AI 和个人数据使用隔离夹具，不写业务。 #>
param([int]$Port=5173,[string]$NodeModulesRoot=(Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules'))
$ErrorActionPreference='Stop'
& node (Join-Path $PSScriptRoot 'Test-AiConsumerUi.mjs') $NodeModulesRoot $Port
if($LASTEXITCODE -ne 0){throw 'AI consumer UI verification failed.'}
