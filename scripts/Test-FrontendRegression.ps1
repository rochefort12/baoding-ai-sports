#requires -Version 7.0
<# .SYNOPSIS 顺序运行正式页面/认证/关键写交互/AI隔离检查；公开页可读真实接口，不调用真实模型、不写业务。 #>
param([string]$NodeModulesRoot=(Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules'),[string]$BaseUrl='http://127.0.0.1:5173')
$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
Push-Location $taskRoot
try {
 foreach($testFile in @('Test-AuthUi.mjs','Test-BusinessUi.mjs','Test-ConsumerUi.mjs','Test-CriticalUi.mjs','Test-PublicationContactUi.mjs','Test-AiBusinessUi.mjs','Test-AiConsumerUi.mjs')) {
  & node (Join-Path $PSScriptRoot $testFile) $NodeModulesRoot $BaseUrl
  if($LASTEXITCODE -ne 0){throw "Frontend verification failed: $testFile"}
 }
} finally {Pop-Location}
