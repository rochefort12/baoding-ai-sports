#requires -Version 7.0
# Freeze preparation evidence without executing any human business step.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Common.ps1"
$taskBatch = Join-Path $WorkspaceRoot '.local/three-person-test-20261012/d23b25203cba4df8b509ee77d8be1249'
$taskEvidence = [ordered]@{
    backup = '.local/business-regression-20261011/d32bff962337431daf467558d3bd2a50/preflight-receipt.json'
    accounts = '.local/three-person-test-20261012/d23b25203cba4df8b509ee77d8be1249/receipt-30d1a675-5577-40d1-8a8d-a383fa6bff8a.json'
    acl = '.local/three-person-test-20261012/d23b25203cba4df8b509ee77d8be1249/acl-receipt.json'
    lanFirewall = '.local/three-person-lan-20261012/01e7d76b-4080-4ee1-93ca-308c9160699d/receipt.json'
    lanFinal = '.local/three-person-lan-20261012/4e9db7e9-a8fd-4aaa-a788-c69e307bce3a/receipt.json'
    frontend = '.local/product-release-20261011/frontend-refinement-a9d5497db79b4d3d833b096ae291a468/receipt.json'
    browser = '.local/three-person-test-20261012/d23b25203cba4df8b509ee77d8be1249/ui-readonly-515773a3-56f6-41a3-9122-9f0efd4b56c3/receipt.json'
}
$taskReferences = @()
foreach ($taskEntry in $taskEvidence.GetEnumerator()) {
    $taskPath = Join-Path $WorkspaceRoot $taskEntry.Value
    $taskRecord = Get-Content -LiteralPath $taskPath -Raw | ConvertFrom-Json
    if (!$taskRecord.passed) { throw ('Preparation evidence did not pass: ' + $taskEntry.Key) }
    $taskReferences += @{ kind=$taskEntry.Key; path=$taskEntry.Value; sha256=(Get-FileHash -LiteralPath $taskPath -Algorithm SHA256).Hash.ToLowerInvariant() }
}
$taskRuntime = Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.local/phase1-implementation/verification-runtime.json') -Raw | ConvertFrom-Json
if ($taskRuntime.database -ne 'aisports_verify_phase1_242ded43673246699be6bb0f596aa59b' -or $taskRuntime.port -ne 8082) { throw 'Unexpected isolated runtime.' }
$taskListeners = @(Get-NetTCPConnection -State Listen | Where-Object LocalPort -in @(5192,5193,8082,8091,25432,26379,29000,29001))
if (@($taskListeners | Where-Object { $_.LocalPort -eq 5193 -and $_.LocalAddress -eq '192.168.1.236' }).Count -ne 1 -or @($taskListeners | Where-Object { $_.LocalPort -ne 5193 -and ![Net.IPAddress]::IsLoopback([Net.IPAddress]::Parse($_.LocalAddress)) }).Count -ne 0) { throw 'The prepared frontend/service exposure changed.' }
$taskPreserved = [ordered]@{
    'docs/04-verification/助手按钮横向交互验证-20261012.json' = '6973d323857b5a005774bfdb0071b01f8df3fbbee56568127650a38a9da5181c'
    'docs/04-verification/队伍邀请场次与体验修复验证-20261012.json' = '6b7ec11f4db3c27d9a609bc9fd9fa973953c6d1ad4394029aa1897f4fafbf06d'
    'docs/04-verification/奖项材料与队伍报名修复验证-20261012.json' = 'f16dfda1da798b604e0f053acd50f33239645a2d5ec0236d2821770e7e93f3da'
}
foreach ($taskEntry in $taskPreserved.GetEnumerator()) {
    if ((Get-FileHash -LiteralPath (Join-Path $WorkspaceRoot $taskEntry.Key) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskEntry.Value) { throw 'An existing sealed business index changed.' }
}
$taskGuide = Join-Path $WorkspaceRoot 'docs/04-verification/三人联测流程草案-20261012.md'
$taskRows = @(Get-Content -LiteralPath $taskGuide | Where-Object { $_ -match '^\| \d{2}-\d{2} \|' })
if ($taskRows.Count -ne 169 -or @($taskRows | Where-Object { $_ -notmatch '\| 未执行 \|$' }).Count) { throw 'Manual steps must retain their initial NOT_RUN state.' }
# This additional short sheet makes sharing the three primary logins simple.
# It inherits owner + SYSTEM access from the previously verified batch directory.
$taskState = Get-Content -LiteralPath (Join-Path $taskBatch 'state.private.json') -Raw | ConvertFrom-Json
$taskSheet = @('AI体育｜三人主账号（模拟）', '登录网址：http://192.168.1.236:5193/portal/login', '')
foreach ($taskRole in @('A','B','C')) {
    $taskAccount = $taskState.accounts | Where-Object code -eq $taskRole
    if (!$taskAccount -or $taskAccount.profileKind -ne 'blank-primary') { throw 'Primary identity preparation changed.' }
    $taskSheet += @(('操作人 ' + $taskRole), ('手机号：' + $taskAccount.phone), ('密码：' + $taskAccount.password), '')
}
$taskSheet += @('先各自登录，确认成功后再继续下一步。备用及工作角色账号另在分人账号单中。', '仅用于本轮测试，请勿将这份账号单公开或上传到项目。')
$taskSheetPath = Join-Path $taskBatch '三人主账号.private.txt'
$taskSheetBytes = [Text.UTF8Encoding]::new($false).GetBytes(($taskSheet -join "`r`n"))
if (Test-Path -LiteralPath $taskSheetPath) { throw 'Primary credential sheet already exists; do not recreate it.' }
$taskStream = [IO.File]::Open($taskSheetPath, [IO.FileMode]::CreateNew)
try { $taskStream.Write($taskSheetBytes); $taskStream.Flush($true) } finally { $taskStream.Dispose() }
$taskAllowed = @([Security.Principal.WindowsIdentity]::GetCurrent().User.Value,'S-1-5-18')
foreach ($taskRule in (Get-Acl -LiteralPath $taskSheetPath).Access) {
    if ($taskRule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -notin $taskAllowed) { throw 'Primary credential file has broader readers than the protected batch.' }
}
$taskInputs = @('scripts/Prepare-ThreePersonTest.ps1','scripts/Prepare-ThreePersonTest.mjs','scripts/Start-ThreePersonLanTrial.ps1','scripts/Test-ThreePersonPreparationUi.ps1','scripts/Test-ThreePersonPreparationUi.mjs','scripts/Seal-ThreePersonPreparation.ps1','docs/04-verification/三人联测流程草案-20261012.md') + @(Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot 'docs/04-verification/three-person-fixtures-20261012') -File | ForEach-Object { [IO.Path]::GetRelativePath($WorkspaceRoot,$_.FullName).Replace('\','/') })
$taskIndex = [ordered]@{
    schemaVersion=1; at=[DateTimeOffset]::Now.ToString('o'); status='READY_FOR_FIRST_MANUAL_STEP'
    scope='Preparation with synthetic identities and browser sessions on the host; full human and physical-device business acceptance remains NOT_RUN.'
    login='http://192.168.1.236:5193/portal/login'; database=$taskRuntime.database; jarSha256=$taskRuntime.jarSHA256
    primaryAccounts=@(@{person='A';phone='16694001001';role='organizer-applicant'},@{person='B';phone='16694001002';role='captain'},@{person='C';phone='16694001003';role='member'})
    accountPreparationChecks=34; browserChecks=27; frontendUtilityTests=54
    manualStepCount=169; manualStepStatus='NOT_RUN'; physicalDevices='NOT_RUN'
    primaryCredentialSheet='.local/three-person-test-20261012/d23b25203cba4df8b509ee77d8be1249/三人主账号.private.txt'
    evidence=$taskReferences; preservedIndices=$taskPreserved
    sources=@($taskInputs | ForEach-Object { @{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $WorkspaceRoot $_) -Algorithm SHA256).Hash.ToLowerInvariant()} })
    liveListeners=@($taskListeners | Select-Object LocalAddress,LocalPort,OwningProcess)
    failuresRetained=@('Original startup firewall permission denial and early wrapper check','Initial account guard and login-contract failures','Mobile nickname selector failures before current page-aware read-only verification')
    limitations=@('Six fixtures do not validate real SMS registration','Browser sessions on one host do not validate three physical devices','Synthetic funds and scores do not validate real payments or sport adjudication','Original 21/17/7 acceptance items remain tracked individually')
}
$taskTarget = Join-Path $WorkspaceRoot 'docs/04-verification/三人联测准备-20261012.json'
$taskBytes = [Text.UTF8Encoding]::new($false).GetBytes(($taskIndex | ConvertTo-Json -Depth 12))
$taskStream = [IO.File]::Open($taskTarget,[IO.FileMode]::CreateNew)
try { $taskStream.Write($taskBytes); $taskStream.Flush($true) } finally { $taskStream.Dispose() }
Write-Output ('Prepared manual entry: ' + $taskIndex.login)
Write-Output ('Preparation index: ' + $taskTarget)
