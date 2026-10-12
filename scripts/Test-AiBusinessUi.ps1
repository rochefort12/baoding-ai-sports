#requires -Version 7.0
<# .SYNOPSIS 使用隔离接口验证正式 AI 办赛交互，不写真实业务或调用模型。 #>
param([string]$NodeModulesRoot=(Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules'))
$ErrorActionPreference='Stop'
& node (Join-Path $PSScriptRoot 'Test-AiBusinessUi.mjs') $NodeModulesRoot
if($LASTEXITCODE -ne 0){throw 'AI business UI verification failed.'}
