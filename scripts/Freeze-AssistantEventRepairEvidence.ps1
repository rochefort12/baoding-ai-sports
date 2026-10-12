#requires -Version 7.0
[CmdletBinding()]param(
 [Parameter(Mandatory)][string]$BuildReceipt,
 [Parameter(Mandatory)][string]$FrontendReceipt,
 [Parameter(Mandatory)][string]$LiveReceipt,
 [Parameter(Mandatory)][string]$ActivationReceipt,
 [string]$FrontendReloadReceipt
)
# Bind accepted checks to current bytes and the actual isolated listener, without replaying writes.
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
$taskTarget=Join-Path $WorkspaceRoot 'docs/04-verification/悬浮办赛与草稿修复验证-20261012.json'
if(Test-Path -LiteralPath $taskTarget){throw 'Existing evidence is immutable; use a new generation.'}
function Hash-Artifact([string]$Path){(Get-FileHash -LiteralPath (Join-Path $WorkspaceRoot $Path) -Algorithm SHA256).Hash.ToLowerInvariant()}
function Read-Artifact([string]$Path){Get-Content -LiteralPath (Join-Path $WorkspaceRoot $Path) -Raw|ConvertFrom-Json}
function Assert-Inputs($Sources){foreach($taskSource in $Sources){if((Hash-Artifact $taskSource.path) -ne $taskSource.sha256){throw "Checked source changed: $($taskSource.path)"}}}
$taskBuild=Read-Artifact $BuildReceipt;$taskFrontend=Read-Artifact $FrontendReceipt;$taskLive=Read-Artifact $LiveReceipt;$taskActivation=Read-Artifact $ActivationReceipt
foreach($taskAccepted in @($taskBuild,$taskFrontend,$taskLive)){if(!$taskAccepted.passed){throw 'Only passing final receipts may be accepted.'}}
Assert-Inputs $taskBuild.sources;Assert-Inputs $taskFrontend.sources;Assert-Inputs $taskFrontend.assets
$taskRuntime=Read-Artifact '.local/phase1-implementation/verification-runtime.json'
$taskJarHash=(Get-FileHash -LiteralPath $taskRuntime.jarPath -Algorithm SHA256).Hash.ToLowerInvariant()
if($taskRuntime.port -ne 8082 -or $taskRuntime.database -notmatch '^aisports_verify_phase1_[a-f0-9]{32}$' -or $taskJarHash -ne $taskRuntime.jarSHA256 -or $taskJarHash -ne $taskBuild.package.sha256 -or $taskJarHash -ne $taskFrontend.jarSha256 -or $taskJarHash -ne $taskLive.jarSha256 -or $taskJarHash -ne $taskActivation.newPackage){throw 'Final checks and activation must bind the same isolated package.'}
$taskListeners=@(Get-NetTCPConnection -State Listen|Where-Object LocalPort -In @(8080,5190,8082,8091,5192,5193))
if(@($taskListeners|Where-Object {$_.LocalPort -in @(8080,5190)}).Count){throw 'Main site must remain stopped.'}
foreach($taskPort in @(8082,8091,5192)){if(@($taskListeners|Where-Object {$_.LocalPort -eq $taskPort -and $_.LocalAddress -eq '127.0.0.1'}).Count -ne 1 -or @($taskListeners|Where-Object {$_.LocalPort -eq $taskPort -and $_.LocalAddress -ne '127.0.0.1'}).Count){throw "Unexpected listener for $taskPort"}}
$taskJava=Get-CimInstance Win32_Process -Filter "ProcessId=$(( $taskListeners|Where-Object LocalPort -eq 8082).OwningProcess)"
if(!$taskJava.CommandLine.Replace('\','/').Contains($taskRuntime.jarPath.Replace('\','/'))){throw 'Actual Java listener does not use the accepted package.'}
$taskGateway=Get-CimInstance Win32_Process -Filter "ProcessId=$(( $taskListeners|Where-Object LocalPort -eq 8091).OwningProcess)"
if(!$taskGateway.CommandLine.Contains('ai-gateway') -or !$taskGateway.CommandLine.Contains('server.mjs')){throw 'Unexpected gateway listener owner.'}
$taskPaths=@($BuildReceipt,$FrontendReceipt,$LiveReceipt,$ActivationReceipt)
if($FrontendReloadReceipt){if(!(Read-Artifact $FrontendReloadReceipt).passed){throw 'Frontend reload receipt must pass.'};$taskPaths+=$FrontendReloadReceipt;$taskPaths+='scripts/Restart-AssistantTrialFrontends.ps1'}
$taskChain=$taskLive;$taskPredecessors=@()
while($taskChain.resumedFrom){
 $taskPrevious=$taskChain.resumedFrom.path
 if($taskPredecessors.Count -ge 12 -or $taskPrevious -notmatch '^\.local[\\/]+assistant-event-repair-20261012[\\/]+[a-f0-9]{32}[\\/]+live-receipt\.json$' -or $taskPrevious -in $taskPredecessors){throw 'Invalid live receipt predecessor.'}
 if((Hash-Artifact $taskPrevious) -ne $taskChain.resumedFrom.sha256){throw 'Live predecessor changed.'}
 $taskPredecessors+=$taskPrevious;$taskChain=Read-Artifact $taskPrevious
}
$taskPaths+=$taskPredecessors
foreach($taskPriorPath in $taskPredecessors){$taskPriorDir=Split-Path $taskPriorPath -Parent;$taskPaths+=@(Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot $taskPriorDir) -Filter '*.png'|ForEach-Object{[IO.Path]::GetRelativePath($WorkspaceRoot,$_.FullName)})}
foreach($taskReceiptPath in @($BuildReceipt,$FrontendReceipt)){
 $taskData=Read-Artifact $taskReceiptPath;$taskDir=Split-Path $taskReceiptPath -Parent
 foreach($taskLog in $taskData.logs){$taskLogPath=Join-Path $taskDir $taskLog.file;if((Hash-Artifact $taskLogPath) -ne $taskLog.sha256){throw 'Accepted log changed.'};$taskPaths+=$taskLogPath}
}
$taskLiveDir=Split-Path $LiveReceipt -Parent
$taskScreens=@(Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot $taskLiveDir) -Filter '*.png'|ForEach-Object{[IO.Path]::GetRelativePath($WorkspaceRoot,$_.FullName)})
$taskPaths+=$taskScreens
$taskPaths+=@('docs/04-verification/悬浮办赛与草稿修复验证-20261012.md','scripts/Test-AssistantEventRepair.ps1','scripts/Test-AssistantChatPublish.mjs','scripts/Test-AssistantChatState.mjs','scripts/Freeze-AssistantEventRepairEvidence.ps1')
$taskBuildLog=Get-Content -LiteralPath (Join-Path $WorkspaceRoot (Join-Path (Split-Path $BuildReceipt -Parent) 'maven-package.log')) -Raw
$taskJavaSummaries=[regex]::Matches($taskBuildLog,'(?m)^\[INFO\] Tests run: (\d+), Failures: (\d+), Errors: (\d+), Skipped: (\d+)\s*$')
$taskJavaTotals=@{tests=0;failures=0;errors=0;skipped=0};foreach($taskSummary in $taskJavaSummaries){$taskJavaTotals.tests+=[int]$taskSummary.Groups[1].Value;$taskJavaTotals.failures+=[int]$taskSummary.Groups[2].Value;$taskJavaTotals.errors+=[int]$taskSummary.Groups[3].Value;$taskJavaTotals.skipped+=[int]$taskSummary.Groups[4].Value}
if(!$taskJavaTotals.tests -or $taskJavaTotals.failures -or $taskJavaTotals.errors -or $taskJavaTotals.skipped){throw 'Final Java checks contain failures or skipped cases.'}
$taskGatewayLog=Get-Content -LiteralPath (Join-Path $WorkspaceRoot (Join-Path (Split-Path $BuildReceipt -Parent) 'gateway-tests.log')) -Raw
$taskGatewayTests=[regex]::Match($taskGatewayLog,'(?m)^# tests (\d+)\s*$').Groups[1].Value
if(!$taskGatewayTests -or $taskGatewayLog -notmatch '(?m)^# fail 0\s*$' -or $taskGatewayLog -notmatch '(?m)^# skipped 0\s*$'){throw 'Final gateway checks contain failures or skips.'}
$taskIndex=[ordered]@{
 at=[DateTimeOffset]::Now.ToString('o');passed=$true;scope='Current local assistant repair; fictional ordinary-role browser and actual-model observation. Not full phase-one or real-money acceptance.'
 backendJarSha256=$taskJarHash;sourceInputsMatched=$taskBuild.sources.Count;frontendInputsMatched=$taskFrontend.sources.Count
 java=$taskJavaTotals;gatewayTests=[int]$taskGatewayTests;frontendChecks=$taskFrontend.checks;liveChecks=$taskLive.checks;priorChecksReferenced=$taskLive.previouslyVerified;objects=$taskLive.objects
 listeners=@($taskListeners|Select-Object LocalAddress,LocalPort,OwningProcess);livePredecessorHashesMatched=$true
 artifacts=@($taskPaths|Select-Object -Unique|ForEach-Object{@{path=$_.Replace('\','/');sha256=Hash-Artifact $_}})
 unverified=@('Physical document dragging, real phone keyboards and WeChat','Additional complex/low-quality documents','Actual registrations, bank receipts, refunds and SMS','Original user event publication and full phase-one acceptance')
}
$taskBytes=[Text.UTF8Encoding]::new($false).GetBytes(($taskIndex|ConvertTo-Json -Depth 12))
$taskTemp=$taskTarget+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
$taskStream=[IO.File]::Open($taskTemp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$taskStream.Write($taskBytes);$taskStream.Flush($true)}finally{$taskStream.Dispose()}
Move-Item -LiteralPath $taskTemp -Destination $taskTarget
Write-Output 'Current sources, accepted logs, live receipt chain and actual isolated package verified; new sanitized index created.'
