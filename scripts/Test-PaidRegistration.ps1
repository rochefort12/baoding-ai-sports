#requires -Version 7.0
param([ValidateSet('preflight','flow','cleanup')][string]$Mode='preflight')
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
# 仅使用文档约定的本地试用口令，不打印或写入测试证据。
$trialMatch = [regex]::Match((Get-Content "$WorkspaceRoot/docs/01-development/环境运行.md" -Raw), '本地试用约定：[^\r\n]*密码都用\s*`([^`]+)`')
if (-not $trialMatch.Success) { throw 'Local trial login convention is unavailable.' }
$env:AISPORTS_TRIAL_PASSWORD = $trialMatch.Groups[1].Value
$env:AISPORTS_TEST_NODE_MODULES = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules'
if ($Mode -eq 'flow' -and -not $env:AISPORTS_TEST_ADMIN_PASSWORD) {
    # 仅用已有本地助手中的管理员口令批准模拟组织，不参与赛事/付款业务操作。
    $helper = Get-Content "$WorkspaceRoot/.local/walk-flow.ps1" -Raw
    $adminMatch = [regex]::Match($helper, '(?s)function Login-Admin.*?password\s*=\s*''([^'']+)''')
    if (-not $adminMatch.Success) { throw 'Local organization admission credential unavailable.' }
    $env:AISPORTS_TEST_ADMIN_PASSWORD = $adminMatch.Groups[1].Value
}
& node "$PSScriptRoot/Test-PaidRegistration.mjs" $Mode
Assert-NativeExit 'Paid registration flow'
