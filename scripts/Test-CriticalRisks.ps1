#requires -Version 7.0
<# .SYNOPSIS 关键风险集中入口；数据库临时隔离、UI模拟响应、HTTP匿名；不替代普通角色验收。 #>
param([string]$NodeModulesRoot=(Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules'),[string]$BaseUrl='http://127.0.0.1:5173')
$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
Push-Location (Join-Path $taskRoot 'backend')
try {
 & mvn '-Plocal' '-pl' 'aisports-api' '-DskipTests' 'install'
 if($LASTEXITCODE -ne 0){throw 'API contract install failed'}
 foreach($group in @(
  @('registration','RegistrationInviteAccessTest,RegistrationRulesTest,RegistrationApprovalWindowTest,RegistrationOperationsTest,AiUnpricedUnitTest'),
  @('finance','FundRecordsTest,FeeRulesTest,ManualFundsTest'),
  @('event','InvitationNoticeTest,PromotionVisualTest,AiDraftReadinessTest,AiTaskConfirmationTest,AiProposalConcurrencyTest,EventPublicationContactTest,EventAssistantTest,OperationsChatDocumentTest,OperationsChatLimitTest,ConsumerAssistantTest,PublicEventSearchTest,DraftMergeTest,EventCreationConsentTest,AiDocumentPolicyTest,EventPhaseCalculatorTest,EventOperationsTest,PromotionCopyGuardTest,LocalDocumentExtractorTest'),
  @('competition','CompetitionRulesTest,CompetitionEndWindowTest'),
  @('team','InvitationAccessTest,TeamRulesTest'))){
  & mvn '-Plocal' '-pl' ('ruoyi-modules/ruoyi-sports-'+$group[0]) '-DskipTests=false' ('-Dtest='+$group[1]) 'test'
  if($LASTEXITCODE -ne 0){throw "Backend critical tests failed: $($group[0])"}
 }
} finally {Pop-Location}
Push-Location (Join-Path $taskRoot 'plus-ui')
try {
 & node 'node_modules/vitest/vitest.mjs' 'run' '--config' 'vitest.config.ts'
 if($LASTEXITCODE -ne 0){throw 'Frontend unit tests failed'}
} finally {Pop-Location}
& (Join-Path $PSScriptRoot 'Test-CriticalDatabase.ps1')
& (Join-Path $PSScriptRoot 'Test-CriticalHttp.ps1') -BaseUrl $BaseUrl
Push-Location $taskRoot
try {
 & node (Join-Path $PSScriptRoot 'Test-CriticalUi.mjs') $NodeModulesRoot $BaseUrl
 if($LASTEXITCODE -ne 0){throw 'Frontend critical interaction tests failed'}
 & node (Join-Path $PSScriptRoot 'Test-PublicationContactUi.mjs') $NodeModulesRoot $BaseUrl
 if($LASTEXITCODE -ne 0){throw 'Publication contact confirmation tests failed'}
 & node '--test' (Join-Path $PSScriptRoot 'lib/UiFixtureAudit.test.mjs') (Join-Path $taskRoot 'ai-gateway/kernel.test.mjs') (Join-Path $taskRoot 'ai-gateway/visual.test.mjs')
 if($LASTEXITCODE -ne 0){throw 'AI gateway or fixture guard tests failed'}
 & node (Join-Path $PSScriptRoot 'Test-AiBusinessUi.mjs') $NodeModulesRoot $BaseUrl
 if($LASTEXITCODE -ne 0){throw 'AI business interaction tests failed'}
 & node (Join-Path $PSScriptRoot 'Test-AiConsumerUi.mjs') $NodeModulesRoot $BaseUrl
 if($LASTEXITCODE -ne 0){throw 'AI consumer interaction tests failed'}
}finally{Pop-Location}
Write-Host 'CRITICAL RISK TESTS PASSED; scope restrictions in docs/04-verification'
