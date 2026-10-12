#requires -Version 7.0
param([switch]$GenerateCopy, [switch]$CaptureOnly, [string]$EvidencePath)
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
# 使用已准备的普通本地试用组织，不登录管理员，不输出密码或令牌。
$trialMatch = [regex]::Match((Get-Content "$WorkspaceRoot/docs/01-development/环境运行.md" -Raw), '本地试用约定：[^\r\n]*密码都用\s*`([^`]+)`')
if (-not $trialMatch.Success) { throw 'Local trial login convention unavailable.' }
$env:AISPORTS_TRIAL_PASSWORD = $trialMatch.Groups[1].Value
$env:AISPORTS_TEST_NODE_MODULES = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules'
& node "$PSScriptRoot/Test-EventPayment.mjs" $(if ($CaptureOnly) {'capture-only'} elseif ($GenerateCopy) {'generate-copy'} else {'local-only'}) $EvidencePath
Assert-NativeExit 'Event payment flow'
