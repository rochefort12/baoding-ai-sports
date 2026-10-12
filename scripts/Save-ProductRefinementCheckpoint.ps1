#requires -Version 7.0
# Local continuation evidence only; not a whole-project completion marker.
param([Parameter(Mandatory)][string]$EvidencePath)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
$taskEvidence=Join-Path $taskRoot $EvidencePath
$taskReport=Get-Content -LiteralPath $taskEvidence -Raw | ConvertFrom-Json
if (!$taskReport.passed) { throw 'Final supplemental report did not pass.' }
$taskJar=Join-Path $taskRoot 'backend/ruoyi-admin/target/ruoyi-admin.jar'
$taskJarHash=(Get-FileHash -LiteralPath $taskJar -Algorithm SHA256).Hash.ToLowerInvariant()
if ($taskJarHash -ne $taskReport.jarSha256) { throw 'Current JAR differs from the final evidence.' }
$taskListeners=@(Get-NetTCPConnection -State Listen -LocalPort 5190,5192,5193,8080,8082,8091,25432,26379,29000 | Select-Object LocalAddress,LocalPort,OwningProcess)
if (@(@(5190,5192,5193,8080,8082,8091,25432,26379,29000) | Where-Object { $_ -notin $taskListeners.LocalPort }).Count -gt 0) { throw 'An expected local listener is missing.' }
if (@($taskListeners | Where-Object { $_.LocalAddress -notin '127.0.0.1','::1' }).Count -gt 0) { throw 'Unexpected non-loopback listener.' }
$taskJson=@{
    at=[DateTimeOffset]::Now.ToString('o');state='LOCAL_UI_AND_SYNTHETIC_HONOR_CHECKS_PASSED';
    scope='Current controlled local test version; real tournament, external honor facts, SMS and generic Agent writes remain separate gates';
    evidence=@{path=$EvidencePath;sha256=(Get-FileHash -LiteralPath $taskEvidence -Algorithm SHA256).Hash.ToLowerInvariant()};
    jarSha256=$taskJarHash;listeners=$taskListeners;
    protectedCredentialLocations=@('.local/demo-20261011/演示账号.txt','.local/main-access/主站管理员.txt');
    safeResume='Revalidate owned listeners and existing sessions. Use existing Resume-Phase1/Restart-Phase1Verification/Start-DemoFrontend entries. Never rerun initialization or old successful registration, payment, match, certification or capability activations.';
    nextGates=@('First real world honor certification with independent evidence','Real image provider and multiformat Agent acceptance','Real SMS, first registration/recovery and ordinary-role full tournament including finance/results/complaint closure','Actual mobile soft keyboards, cold start and broader accessibility');
    prohibitedCompletionClaims=@('Public release','Whole phase-one completion','Actual world champion verified','Real financial or SMS acceptance')
}
$taskOut=Join-Path $taskRoot ('.local/product-release-20261011/checkpoint-'+[guid]::NewGuid().ToString('N')+'.json')
[IO.File]::WriteAllText($taskOut,($taskJson | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
Write-Output ('Checkpoint: '+[IO.Path]::GetRelativePath($taskRoot,$taskOut))
