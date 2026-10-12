#requires -Version 7.0
<# .SYNOPSIS 检查已启动的正式C端前端；个人页使用隔离网络样例，不写真实业务。 #>
param([int]$Port=5173,[string]$NodeModulesRoot=(Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules'))
$ErrorActionPreference='Stop'
& node (Join-Path $PSScriptRoot 'Test-ConsumerUi.mjs') $NodeModulesRoot $Port
if($LASTEXITCODE -ne 0){throw 'Consumer UI verification failed.'}
