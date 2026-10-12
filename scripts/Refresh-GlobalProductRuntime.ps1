#requires -Version 7.0
<# Refresh only the recorded AISports processes; preserve the existing rehearsal store. #>
[CmdletBinding()]param([switch]$ResumeStopped)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$jar=Join-Path $WorkspaceRoot 'backend/ruoyi-admin/target/ruoyi-admin.jar'
$runtimeFile=Join-Path $WorkspaceRoot '.local/phase1-implementation/verification-runtime.json'
$runtime=Get-Content -LiteralPath $runtimeFile -Raw|ConvertFrom-Json
if($runtime.database-notmatch '^aisports_verify_phase1_[a-f0-9]{32}$' -or $runtime.redisPrefix-notmatch '^aisports:verify:phase1:[a-f0-9]{32}:$'){throw 'Existing rehearsal identity changed.'}
$run=[guid]::NewGuid().ToString('N');$out=Join-Path $WorkspaceRoot ('.local/product-release-20261011/runtime-refresh-'+$run)
New-Item -ItemType Directory -Path $out|Out-Null
$receipt=@{startedAt=[DateTimeOffset]::Now.ToString('o');scope='Owned local product refresh; existing database/session facts retained';passed=$false;stopped=@();started=@()}
function Stop-Owned([int]$taskPid,[int]$port,[string]$entry,[string]$marker){
 $process=Get-CimInstance Win32_Process -Filter "ProcessId=$taskPid"
 if(!$process){throw 'A recorded project process is missing; inspect before refresh.'}
 $command=([string]$process.CommandLine).Replace('/','\')
 if(!$command.Contains($entry.Replace('/','\'),[StringComparison]::OrdinalIgnoreCase) -or ($marker -and !$command.Contains($marker))){throw 'A PID no longer belongs to the expected project entry.'}
 $listeners=@(Get-NetTCPConnection -State Listen -LocalPort $port)
 if(!$listeners.Count -or @($listeners|Where-Object {$_.OwningProcess-ne $taskPid -or $_.LocalAddress-notin @('127.0.0.1','::1')}).Count){throw 'Project listener ownership changed.'}
 Stop-Process -Id $taskPid
 for($i=0;$i-lt 15;$i++){if(!(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue)){break};Start-Sleep -Milliseconds 300}
 if(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue){throw 'Owned process did not release its listener.'}
 $receipt.stopped+=@{pid=$taskPid;port=$port}
}
try{
 $mainPid=[int]([IO.File]::ReadAllText((Join-Path $WorkspaceRoot '.local/backend.pid')).Trim())
 $gatewayPid=[int]([IO.File]::ReadAllText((Join-Path $WorkspaceRoot '.local/ai-gateway.pid')).Trim())
 Copy-Item -LiteralPath $jar -Destination (Join-Path $out 'previous.jar')
 $receipt.previousJarSha256=(Get-FileHash -LiteralPath $jar).Hash.ToLowerInvariant()
 foreach($relative in @('.local/backend-default-runtime.log','.local/backend-default-error.log','.local/ai-gateway.log','.local/ai-gateway-error.log','.local/phase1-implementation/http-test-runtime.log','.local/phase1-implementation/http-test-error.log')){if(Test-Path -LiteralPath (Join-Path $WorkspaceRoot $relative)){Copy-Item -LiteralPath (Join-Path $WorkspaceRoot $relative) -Destination (Join-Path $out ($relative.Replace('/','-').TrimStart('.','-')))}}
 if($ResumeStopped){
  if(Get-NetTCPConnection -State Listen -LocalPort 8080,8082,8091 -ErrorAction SilentlyContinue){throw 'Resume requires the previously stopped project ports to be free.'}
  $receipt.resumedStoppedBuild=$true
 }else{
  Stop-Owned $mainPid 8080 $jar '--spring.profiles.active=local'
  Stop-Owned ([int]$runtime.pid) 8082 $jar '--server.port=8082'
  Stop-Owned $gatewayPid 8091 (Join-Path $WorkspaceRoot 'ai-gateway/server.mjs') ''
 }
 $env:JAVA_HOME='D:/dev/jdk17';$env:PATH='D:/dev/jdk17/bin;D:/dev/nodejs;'+$env:PATH
 Push-Location (Join-Path $WorkspaceRoot 'backend')
 try{& 'D:/dev/maven/bin/mvn.cmd' '-Plocal' '-pl' 'ruoyi-admin' '-am' '-DskipTests=false' '-Dtest.groups=local' '-Dtest=GrowthRankPresentationTest,GrowthPoliciesCompatibilityTest,GrowthTitlePresentationTest,HonorCertificationTest,HonorProofStorageTest,HonorProofCleanupTest,AgentPlaybookRulesTest,AgentGuidanceAuthorizationTest,LegacyMcpRunIsolationTest,EventActionQueryContractTest,ProfileAvatarStorageTest,ProfileAvatarServiceTest,EventMaterialServiceTest' '-Dsurefire.failIfNoSpecifiedTests=false' package *> (Join-Path $out 'backend-build-tests.log');Assert-NativeExit 'Global product build and selected tests'}finally{Pop-Location}
 $receipt.jarSha256=(Get-FileHash -LiteralPath $jar).Hash.ToLowerInvariant()
 & "$PSScriptRoot/Start-Backend.ps1" -JavaHome 'D:/dev/jdk17' -Background
 & "$PSScriptRoot/Restart-Phase1Verification.ps1"
 & "$PSScriptRoot/Start-AiGateway.ps1" -Background
 foreach($port in @(8080,8082)){
   $ready=$false;for($i=0;$i-lt 50;$i++){try{$code=Invoke-RestMethod -Uri ('http://127.0.0.1:'+ $port +'/auth/code') -TimeoutSec 3;if($code.code-eq 200){$ready=$true;break}}catch{};Start-Sleep -Seconds 2}
   if(!$ready){throw 'A refreshed backend did not become ready in the bounded window.'}
 }
 $receipt.started=@(Get-NetTCPConnection -State Listen -LocalPort 8080,8082,8091|Select-Object LocalAddress,LocalPort,OwningProcess)
 $receipt.passed=$true;Write-Host 'PASS main, existing rehearsal and gateway refreshed with new product build.'
}finally{$receipt.finishedAt=[DateTimeOffset]::Now.ToString('o');$receipt|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $out 'receipt.json')}
