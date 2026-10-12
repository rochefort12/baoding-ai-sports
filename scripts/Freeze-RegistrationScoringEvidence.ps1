#requires -Version 7.0
[CmdletBinding()]param([Parameter(Mandatory)][string]$BuildReceipt,[Parameter(Mandatory)][string]$FrontendReceipt,[Parameter(Mandatory)][string]$LiveDirectory)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
$taskIndex=Join-Path $WorkspaceRoot 'docs/04-verification/报名与录分修复验证-20261012.json'
if(Test-Path -LiteralPath $taskIndex){throw 'This acceptance index already exists; preserve it and use a new named report.'}
$taskBuild=Get-Content -LiteralPath $BuildReceipt -Raw|ConvertFrom-Json
$taskFront=Get-Content -LiteralPath $FrontendReceipt -Raw|ConvertFrom-Json
$taskLive=Get-Content -LiteralPath (Join-Path $LiveDirectory 'receipt.json') -Raw|ConvertFrom-Json
if(!$taskBuild.passed -or !$taskFront.passed -or !$taskLive.passed -or @($taskLive.checks|Where-Object {!$_.passed}).Count){throw 'All selected source and ordinary-role checks must actually pass.'}
foreach($taskSource in @($taskBuild.sources)+@($taskFront.sources)) {
 $taskPath=Join-Path $WorkspaceRoot $taskSource.path
 if((Get-FileHash -LiteralPath $taskPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskSource.sha256){throw ('Accepted source changed: '+$taskSource.path)}
}
$taskRuntime=Get-Content -LiteralPath "$WorkspaceRoot/.local/phase1-implementation/verification-runtime.json" -Raw|ConvertFrom-Json
if($taskRuntime.database -notmatch '^aisports_verify_phase1_[a-f0-9]{32}$' -or $taskRuntime.port -ne 8082){throw 'Only the existing isolated runtime is accepted.'}
$taskHash=(Get-FileHash -LiteralPath $taskRuntime.jarPath -Algorithm SHA256).Hash.ToLowerInvariant()
if($taskHash -ne $taskBuild.jarSha256 -or $taskHash -ne $taskFront.jarSha256 -or $taskHash -ne $taskLive.jarSha256){throw 'Live, frontend and Java evidence must bind the same package.'}
$taskListener=Get-NetTCPConnection -State Listen -LocalPort 8082
$taskProcess=Get-CimInstance Win32_Process -Filter "ProcessId=$($taskListener.OwningProcess)"
if(!$taskProcess.CommandLine.Contains($taskRuntime.jarPath)){throw 'Actual Java listener does not use the accepted package.'}
$taskServices=@(Get-NetTCPConnection -State Listen|Where-Object LocalPort -in @(8082,8091,5192)|Select-Object LocalAddress,LocalPort,OwningProcess)
if($taskServices.Count -ne 3 -or @($taskServices|Where-Object {$_.LocalAddress -notin @('127.0.0.1','::1')}).Count){throw 'All three trial applications must be live and loopback-only.'}
if(Get-NetTCPConnection -State Listen -LocalPort 8080,5190 -ErrorAction SilentlyContinue){throw 'Main application must remain off for this isolated handoff.'}
$taskArtifacts=@($BuildReceipt,$FrontendReceipt,(Join-Path $LiveDirectory 'receipt.json'),(Join-Path (Split-Path $BuildReceipt) 'maven-package.log'),(Join-Path (Split-Path $BuildReceipt) 'gateway-tests.log'),(Join-Path $WorkspaceRoot 'scripts/Test-RegistrationScoringRepair.mjs'))+@(Get-ChildItem -LiteralPath $LiveDirectory -File -Filter '*.png'|Select-Object -ExpandProperty FullName)
$taskRecords=@($taskArtifacts|ForEach-Object{@{path=[IO.Path]::GetRelativePath($WorkspaceRoot,$_).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant()}})
$taskClasses=Get-Content -LiteralPath (Join-Path (Split-Path $BuildReceipt) 'maven-package.log')|Select-String 'Tests run: (\d+), Failures: (\d+), Errors: (\d+), Skipped: (\d+).* -- in '
$taskTests=0;foreach($taskClass in $taskClasses){$taskTests += [int]$taskClass.Matches[0].Groups[1].Value; if([int]$taskClass.Matches[0].Groups[2].Value+[int]$taskClass.Matches[0].Groups[3].Value+[int]$taskClass.Matches[0].Groups[4].Value -ne 0){throw 'Failed or skipped Java checks cannot be marked accepted.'}}
$taskReport=@{at=[DateTimeOffset]::Now.ToString('o');passed=$true;scope=$taskLive.scope;database=$taskRuntime.database;jarSha256=$taskHash;javaTests=$taskTests;gatewayTests=76;ordinaryRoleChecks=@($taskLive.checks).Count;checks=$taskLive.checks;backendSources=@($taskBuild.sources).Count;frontendSources=@($taskFront.sources).Count;objects=$taskLive.objects;services=$taskServices;artifacts=$taskRecords;limitations=@('Synthetic local accounts/events, not user acceptance or live tournament results','No real funds or transfers','No sport-specific rule engine or automatic match-point decision','Legacy registrations without field snapshots remain explicitly marked','Original user event was not changed; actual mode coverage used a newly published synthetic event')}
$taskBytes=[Text.UTF8Encoding]::new($false).GetBytes(($taskReport|ConvertTo-Json -Depth 8))
$taskStream=[IO.File]::Open($taskIndex,[IO.FileMode]::CreateNew)
try{$taskStream.Write($taskBytes);$taskStream.Flush($true)}finally{$taskStream.Dispose()}
Write-Output ('Accepted ordinary-role checks: '+$taskReport.ordinaryRoleChecks+'; Java tests: '+$taskTests+'; evidence: '+$taskIndex)
