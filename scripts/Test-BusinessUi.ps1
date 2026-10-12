#requires -Version 7.0
<# .SYNOPSIS 使用隔离只读样例验证已启动的正式 B 端，不操作真实业务。 #>
param([string]$NodeModulesRoot=(Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules'))
$ErrorActionPreference='Stop'
& node (Join-Path $PSScriptRoot 'Test-BusinessUi.mjs') $NodeModulesRoot
if($LASTEXITCODE -ne 0){throw 'Business UI verification failed.'}
