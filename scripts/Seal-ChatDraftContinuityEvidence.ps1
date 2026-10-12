#requires -Version 7.0
[CmdletBinding()]param(
 [Parameter(Mandatory)][string]$BuildReceipt,
 [Parameter(Mandatory)][string]$FrontendReceipt,
 [Parameter(Mandatory)][string]$DocumentReceipt,
 [Parameter(Mandatory)][string]$UiReceipt,
 [Parameter(Mandatory)][string]$CombinedReceipt,
 [Parameter(Mandatory)][string]$ActivationReceipt
)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
$taskRoot='.local/agent-draft-continuity-20261012'
$taskEvidence=@(
 $BuildReceipt,
 $BuildReceipt,
 $DocumentReceipt,
 $UiReceipt,
 $CombinedReceipt,
 "$taskRoot/readonly-d515a5d6-2bc5-445c-b323-fcf10fc4c38c/receipt.json",
 $FrontendReceipt
)
$taskReceipts=@($taskEvidence|ForEach-Object{Get-Content -LiteralPath (Join-Path $WorkspaceRoot $_) -Raw|ConvertFrom-Json})
foreach($taskRecord in $taskReceipts){if(!$taskRecord.passed){throw 'Only observed accepted evidence can be sealed'}}
foreach($taskSource in $taskReceipts[0].sources){if((Get-FileHash -LiteralPath (Join-Path $WorkspaceRoot $taskSource.path)).Hash -ne $taskSource.sha256){throw 'Accepted backend or gateway source changed'}}
foreach($taskSource in @($taskReceipts[6].sources)+@($taskReceipts[6].assets)){if((Get-FileHash -LiteralPath (Join-Path $WorkspaceRoot $taskSource.path)).Hash -ne $taskSource.sha256){throw 'Accepted frontend source or asset changed'}}
$taskRuntime=Get-Content -LiteralPath "$WorkspaceRoot/.local/phase1-implementation/verification-runtime.json" -Raw|ConvertFrom-Json
if($taskRuntime.port -ne 8082 -or $taskRuntime.database -notmatch '^aisports_verify_phase1_[a-f0-9]{32}$' -or $taskRuntime.jarSHA256 -ne $taskReceipts[0].package.sha256){throw 'Runtime package or isolated scope changed'}
if((Get-FileHash -LiteralPath $taskReceipts[0].package.path).Hash -ne $taskRuntime.jarSHA256){throw 'Accepted package bytes changed'}
$taskPorts=@(Get-NetTCPConnection -State Listen -ErrorAction Stop|Where-Object{$_.LocalPort -in @(8080,8082,8091,5190,5192,5193)})
if(@($taskPorts|Where-Object{$_.LocalPort -in @(8080,5190)}).Count){throw 'Main-site activation is outside this evidence scope'}
foreach($taskPort in @(8082,8091,5192,5193)){if(!($taskPorts|Where-Object{$_.LocalPort -eq $taskPort})){throw 'A required trial listener is unavailable'}}
$taskGatewayPid=[int](Get-Content -LiteralPath "$WorkspaceRoot/.local/ai-gateway.pid" -Raw)
$taskGateway=Get-CimInstance Win32_Process -Filter "ProcessId=$taskGatewayPid"
if(!$taskGateway -or $taskGateway.CommandLine -notlike ('*'+$WorkspaceRoot+'*ai-gateway*server.mjs*')){throw 'Gateway ownership is unavailable'}
$taskFiles=@($taskEvidence)+@(
 'ai-gateway/kernel.mjs','ai-gateway/material-reader.mjs','ai-gateway/source-price.test.mjs','ai-gateway/dialogue-price.test.mjs','ai-gateway/review-default.test.mjs',
 'plus-ui/src/components/business/BusinessAssistant.vue','plus-ui/src/components/business/AiDraftDialog.vue','plus-ui/src/components/business/AssistantPublishReview.vue',
 'docs/03-architecture/ADR-044-聊天草稿创建发布与连续补充.md','docs/04-verification/聊天连续办赛验证-20261012.md',
 'scripts/Test-AgentDraftContinuity.ps1','scripts/Test-ChatDraftContinuity.ps1','scripts/Test-ChatDraftContinuity.mjs','scripts/Test-CombinedDraftReply.ps1','scripts/Test-CombinedDraftReply.mjs','scripts/Test-DocumentDraftPrices.ps1','scripts/Test-DocumentDraftPrices.mjs','scripts/Seal-ChatDraftContinuityEvidence.ps1',
 ((Split-Path $UiReceipt -Parent)+'/mobile-created-published.png'),
 ((Split-Path $BuildReceipt -Parent)+'/gateway-tests.log'),
 $ActivationReceipt
)
$taskOut=Join-Path $WorkspaceRoot ($taskRoot+'/final-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskOut|Out-Null
@{at=[DateTimeOffset]::Now.ToString('o');passed=$true;scope='Accepted isolated fictional flows and current source/package binding, not physical-device or real-money acceptance';packageSHA256=$taskRuntime.jarSHA256;gatewayPID=$taskGatewayPid;ports=@($taskPorts|Select-Object LocalAddress,LocalPort,OwningProcess);artifacts=@($taskFiles|ForEach-Object{@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $WorkspaceRoot $_)).Hash.ToLowerInvariant()}})}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $taskOut 'index.json')
Write-Output ('Accepted chat evidence: '+$taskOut)
