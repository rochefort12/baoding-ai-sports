#requires -Version 7.0
[CmdletBinding()]param()
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$env:AISPORTS_REGRESSION_CONTEXT=Join-Path $WorkspaceRoot '.local/business-regression-20261011/a006561dd66540c2b383415b02480f2c/context.private.json'
$taskTarget=Join-Path $WorkspaceRoot 'docs/04-verification/强Agent材料与交互验证-20261012.json'
if(Test-Path -LiteralPath $taskTarget){throw 'The evidence index already exists; retain it and create a new dated generation.'}
function Read-Receipt([string]$Relative){Get-Content -LiteralPath (Join-Path $WorkspaceRoot $Relative) -Raw | ConvertFrom-Json}
function Hash-Local([string]$Relative){(Get-FileHash -LiteralPath (Join-Path $WorkspaceRoot $Relative) -Algorithm SHA256).Hash.ToLowerInvariant()}
function Assert-Sources($Sources){foreach($taskSource in $Sources){if((Hash-Local $taskSource.path) -ne $taskSource.sha256){throw "Checked source changed: $($taskSource.path)"}}}
$taskBuild='.local/agent-runtime-20261012/build-8c8dd822bfa641839ac9a66024f2a7e9/receipt.json'
$taskFrontend='.local/product-release-20261011/frontend-refinement-7444caeb80ec443a8d602fecc11afeac/receipt.json'
$taskMaterial='.local/agent-material-progress-20261012/live-63c3401e-6552-4217-a1f1-5e29b247579d/receipt.json'
$taskForm='.local/agent-material-progress-20261012/form-7248ec9d-0791-4450-9417-e7af893f5a1a/receipt.json'
$taskUi='.local/agent-material-progress-20261012/ui-a57f9713-dd55-4183-bfd1-1707fb5684ab/receipt.json'
$taskIntent='.local/agent-material-progress-20261012/intent-3e7376f5-e7f2-43ea-b850-ab810ca0888b/receipt.json'
$taskReceipts=@($taskBuild,$taskFrontend,$taskMaterial,$taskForm,$taskUi,$taskIntent)
$taskBuildData=Read-Receipt $taskBuild;$taskFrontendData=Read-Receipt $taskFrontend
foreach($taskPath in $taskReceipts){if(!(Read-Receipt $taskPath).passed){throw "Acceptance receipt did not pass: $taskPath"}}
Assert-Sources $taskBuildData.sources;Assert-Sources $taskFrontendData.sources
$taskRuntime=Read-Receipt '.local/phase1-implementation/verification-runtime.json'
$taskJarHash=(Get-FileHash -LiteralPath $taskRuntime.jarPath -Algorithm SHA256).Hash.ToLowerInvariant()
if($taskRuntime.port -ne 8082 -or $taskRuntime.database -ne 'aisports_verify_phase1_242ded43673246699be6bb0f596aa59b' -or $taskJarHash -ne $taskBuildData.jarSha256 -or $taskJarHash -ne $taskRuntime.jarSHA256){throw 'The accepted isolated runtime package is not current.'}
$taskListeners=@(Get-NetTCPConnection -State Listen | Where-Object LocalPort -In @(8080,5190,8082,5192,8091))
if(@($taskListeners | Where-Object {$_.LocalPort -in @(8080,5190) -or $_.LocalAddress -ne '127.0.0.1'}).Count -or @($taskListeners.LocalPort|Sort-Object -Unique).Count -ne 3){throw 'Unexpected application listener boundary.'}
$taskJavaOwner=Get-CimInstance Win32_Process -Filter "ProcessId=$(( $taskListeners | Where-Object LocalPort -eq 8082).OwningProcess)"
if(!$taskJavaOwner.CommandLine.Replace('\','/').Contains($taskRuntime.jarPath.Replace('\','/'))){throw 'The Java listener does not use the accepted package.'}
$taskMaterialData=Read-Receipt $taskMaterial
if($taskMaterialData.jarSha256 -ne $taskJarHash){throw 'Material acceptance did not run this package.'}
$taskFormData=Read-Receipt $taskForm
# Verify the predecessor chain instead of presenting inherited checks as a fresh rerun.
$taskPredecessors=@();$taskChain=$taskFormData
while($taskChain.resumedFrom){$taskPrevious=$taskChain.resumedFrom.path;if($taskPredecessors.Count -ge 4 -or $taskPrevious -notmatch '^\.local[\\/]+agent-material-progress-20261012[\\/]+form-[a-f0-9-]{36}[\\/]+receipt\.json$'){throw 'Unexpected candidate predecessor path or cycle.'};if((Hash-Local $taskPrevious) -ne $taskChain.resumedFrom.sha256){throw 'Candidate predecessor changed.'};$taskPredecessors+=$taskPrevious;$taskChain=Read-Receipt $taskPrevious}
$taskState=& node --input-type=module -e 'import fs from "node:fs";import assert from "node:assert/strict";import {context,api,readSql} from "./scripts/lib/BusinessRegression.mjs";const s=JSON.parse(fs.readFileSync(".local/phase1-implementation/verification-session.json","utf8").replace(/^\uFEFF/,""));let a={token:(await api(null,"/auth/login","POST",{username:s.people[0].phone,password:s.password,grantType:"platform",tenantId:"900001",clientId:context.clientId})).access_token};a={token:(await api(a,"/auth/organization/enter","POST",{})).access_token};const original=await api(a,"/sports/b/ai/tasks/2109468287808057346"),form=await api(a,"/sports/b/ai/tasks/2109506239355441154"),event=await api(a,"/sports/b/events/2109508372331048961");assert.equal(original.status,"PENDING_CONFIRMATION");assert.ok(!original.resultObjectId);assert.equal(form.status,"CREATED");assert.equal(form.resultObjectId,"2109508372331048961");assert.equal(event.publicationStatus,"draft");assert.ok(event.bannerFileId);assert.ok(Number(readSql("SELECT count(*) FROM asp_ai_invocation WHERE task_id=2109468287808057346 AND attempt_no=1 AND error_code=$code$SOURCE_FIELDS_INCOMPLETE$code$;"))>0);console.log(JSON.stringify({sourceStatus:original.status,originalEventCreated:false,syntheticStatus:form.status,syntheticPublication:event.publicationStatus,coverPresent:true,firstFailureRetained:true}));'
Assert-NativeExit 'Current ordinary organizer state'
$taskStateData=$taskState|ConvertFrom-Json
$taskArtifacts=@($taskReceipts)+$taskPredecessors+@('.local/agent-runtime-20261012/build-8c8dd822bfa641839ac9a66024f2a7e9/gateway-tests.log','.local/agent-runtime-20261012/build-8c8dd822bfa641839ac9a66024f2a7e9/maven-package.log','docs/04-verification/强Agent材料与交互验证-20261012.md','scripts/Test-AiDraftInteraction.mjs','scripts/Test-AgentConversationUi.mjs','scripts/Freeze-AgentMaterialEvidence.ps1')
$taskIndex=[ordered]@{
  at=[DateTimeOffset]::Now.ToString('o');scope='Implemented local material and candidate interaction acceptance; not production or full phase-one acceptance'
  passed=$true;database=$taskRuntime.database;backendJarSha256=$taskJarHash;sourceInputsMatched=$taskBuildData.sources.Count;frontendInputsMatched=$taskFrontendData.sources.Count
  checks=@{javaTests=431;gatewayTests=76;frontendTypecheck=$true;frontendBuild=$true;actualMaterialChecks=$taskMaterialData.checks.Count;actualUiChecks=(Read-Receipt $taskUi).checks.Count;candidateChainChecks=$taskFormData.checks.Count;actualIntentChecks=(Read-Receipt $taskIntent).checks.Count;candidatePredecessorHashesMatched=$true}
  currentState=$taskStateData;listeners=@($taskListeners|Select-Object LocalAddress,LocalPort,OwningProcess)
  originalSha256='0b2140be2f395b2f1c7659c28ee77022ce02637b5cfda50d2530d28cacd2c646'
  artifacts=@($taskArtifacts|Select-Object -Unique|ForEach-Object {@{path=$_.Replace('\','/');sha256=Hash-Local $_}})
  unverified=@('Word headers/footers/VML/textboxes/other objects','Graphics on text-bearing PDF pages','Low-quality OCR and all visual text accuracy','Full official attachments and additional formats','Load, physical-device and all disconnect submission timings','Main-site activation, real external services and full phase-one acceptance')
}
$taskBytes=[Text.UTF8Encoding]::new($false).GetBytes(($taskIndex|ConvertTo-Json -Depth 10))
$taskTemp=$taskTarget+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
$taskStream=[IO.File]::Open($taskTemp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$taskStream.Write($taskBytes);$taskStream.Flush($true)}finally{$taskStream.Dispose()}
Move-Item -LiteralPath $taskTemp -Destination $taskTarget
Write-Host 'Current source hashes, actual accepted package, receipt chain and ordinary-role state verified. New sanitized evidence index created.'
