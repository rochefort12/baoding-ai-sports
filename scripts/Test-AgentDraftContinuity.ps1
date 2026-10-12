#requires -Version 7.0
[CmdletBinding()]param()
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
$taskOut=Join-Path $WorkspaceRoot ('.local/agent-draft-continuity-20261012/build-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskOut|Out-Null
$taskReport=@{at=[DateTimeOffset]::Now.ToString('o');passed=$false;checks=@();scope='Offline Java and gateway tests/package, no business or model writes'}
$taskSources=@('ai-gateway/kernel.mjs','ai-gateway/material-reader.mjs','backend/aisports-domains/d04/aisports-table-event/src/main/java/org/dromara/sports/event/ai/DraftChoices.java','backend/aisports-domains/d04/aisports-table-event/src/main/java/org/dromara/sports/event/ai/DraftAnswerPatch.java','backend/aisports-domains/d04/aisports-table-event/src/main/java/org/dromara/sports/event/ai/SportsEventRunAiTaskService.java','backend/aisports-domains/d04/aisports-table-event/src/test/java/org/dromara/sports/event/ai/DraftAnswerContinuityTest.java')
$taskBefore=@($taskSources|ForEach-Object{@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $WorkspaceRoot $_) -Algorithm SHA256).Hash}})
$taskReport.sources=$taskBefore
$taskPackageName='ruoyi-admin-draft-'+[guid]::NewGuid().ToString('N')
$taskStart=[DateTimeOffset]::Now
try {
    $taskGatewayTests=@(Get-ChildItem "$WorkspaceRoot/ai-gateway" -Filter '*.test.mjs'|ForEach-Object{$_.FullName})
    & node --test @taskGatewayTests *> (Join-Path $taskOut 'gateway-tests.log')
    Assert-NativeExit 'Gateway draft tests'
    $taskReport.checks+='gateway draft tests'
    $env:JAVA_HOME='D:/dev/jdk17';$env:PATH=$env:JAVA_HOME+'/bin;'+$env:PATH
    Push-Location "$WorkspaceRoot/backend"
    try { & mvn '-Plocal' '-pl' 'ruoyi-admin' '-am' '-DskipTests=false' ('-Daisports.package.name='+$taskPackageName) 'package' *> (Join-Path $taskOut 'maven-package.log'); Assert-NativeExit 'Java tests and package' } finally { Pop-Location }
    $taskReport.checks+='Java tests and package'
    $taskTestFile=Get-Item -LiteralPath "$WorkspaceRoot/backend/aisports-domains/d04/aisports-table-event/target/surefire-reports/TEST-org.dromara.sports.event.ai.DraftAnswerContinuityTest.xml"
    [xml]$taskTests=Get-Content -LiteralPath $taskTestFile.FullName -Raw
    if($taskTestFile.LastWriteTime -lt $taskStart.LocalDateTime -or [int]$taskTests.testsuite.tests -ne 18 -or [int]$taskTests.testsuite.failures -ne 0 -or [int]$taskTests.testsuite.errors -ne 0 -or [int]$taskTests.testsuite.skipped -ne 0){throw 'All eighteen new draft cases must actually execute in this build'}
    $taskReport.checks+='18 new continuity and review-default tests actually executed'
    $taskAfter=@($taskSources|ForEach-Object{@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $WorkspaceRoot $_) -Algorithm SHA256).Hash}})
    if(($taskBefore|ConvertTo-Json -Compress) -ne ($taskAfter|ConvertTo-Json -Compress)){throw 'Affected source changed while building'}
    $taskPackage=Join-Path $WorkspaceRoot ('backend/ruoyi-admin/target/'+$taskPackageName+'.jar')
    $taskReport.package=@{path=$taskPackage;sha256=(Get-FileHash -LiteralPath $taskPackage -Algorithm SHA256).Hash.ToLowerInvariant()}
    $taskReport.passed=$true
} finally { $taskReport.finishedAt=[DateTimeOffset]::Now.ToString('o');$taskReport|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $taskOut 'receipt.json');Write-Output ('Draft build evidence: '+$taskOut) }
