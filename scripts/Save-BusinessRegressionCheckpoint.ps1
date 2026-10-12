#requires -Version 7.0
[CmdletBinding()]param([Parameter(Mandatory)][string]$ReportPath)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$reportFile=(Resolve-Path -LiteralPath $ReportPath).Path
if(-not $reportFile.StartsWith($WorkspaceRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Report escaped workspace'}
$report=Get-Content -LiteralPath $reportFile -Raw | ConvertFrom-Json
if(-not $report.passed -or $report.state -ne 'LOCAL_MULTI_ROLE_SYNTHETIC_BADMINTON_REGRESSION_PASSED_WITH_EXTERNAL_GATES_OPEN'){throw 'Successful bounded business report required'}
$candidate=Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.local/phase1-implementation/verification-runtime.json') -Raw | ConvertFrom-Json
$mainProcessId=[int](Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.local/backend.pid') -Raw).Trim()
$checks=@()
foreach($runtime in @(@{port=8080;processId=$mainProcessId},@{port=8082;processId=[int]$candidate.pid})){
 $process=Get-CimInstance Win32_Process -Filter "ProcessId=$($runtime.processId)"
 $argument=[regex]::Match([string]$process.CommandLine,'-jar\s+(?:"(?<quoted>[^"]+)"|(?<bare>\S+))')
 if(-not $process -or $process.Name -notmatch '^java(w)?\.exe$' -or -not $argument.Success){throw 'Recorded backend process ownership changed'}
 $jar=(Resolve-Path -LiteralPath $(if($argument.Groups['quoted'].Success){$argument.Groups['quoted'].Value}else{$argument.Groups['bare'].Value})).Path
 $expectedRoot=[IO.Path]::GetFullPath((Join-Path $WorkspaceRoot '.local/runtime-packages'))+[IO.Path]::DirectorySeparatorChar
 if(-not $jar.StartsWith($expectedRoot,[StringComparison]::OrdinalIgnoreCase) -or (Get-FileHash -LiteralPath $jar).Hash.ToLowerInvariant() -ne $report.backendJarSha256){throw 'Actual running JAR differs from the tested package'}
 $listeners=@(Get-NetTCPConnection -State Listen -LocalPort $runtime.port)
 if(-not $listeners.Count -or @($listeners | Where-Object {$_.OwningProcess -ne $runtime.processId -or $_.LocalAddress -notin @('127.0.0.1','::1')}).Count){throw 'Backend listener identity or local boundary changed'}
 $reply=Invoke-RestMethod -Uri ('http://127.0.0.1:'+$runtime.port+'/sports/public/events') -TimeoutSec 15
 if($reply.code -ne 200){throw 'Actual public tournament query failed'}
 $checks+=@{port=$runtime.port;processId=$runtime.processId;actualJvmJarMatches=$true;actualPublicBusinessQuery=$true}
}
foreach($frontPort in @(5190,5192)){
 $response=Invoke-WebRequest -Uri ('http://127.0.0.1:'+$frontPort+'/portal/home') -TimeoutSec 15
 if($response.StatusCode -ne 200){throw 'Frontend entry unavailable'}
 $checks+=@{port=$frontPort;actualEntryHttpStatus=200}
}
$ports=@(Get-NetTCPConnection -State Listen -LocalPort 5190,5192,5193,8080,8082,8091,25432,26379,29000 | Select-Object LocalAddress,LocalPort,OwningProcess)
if(@($ports | Where-Object {$_.LocalAddress -notin @('127.0.0.1','::1')}).Count){throw 'Local service exposure changed'}
$out=Join-Path $WorkspaceRoot ('.local/business-regression-20261011/'+$report.runId+'/checkpoint-'+[guid]::NewGuid().ToString('N')+'.json')
$receipt=@{at=[DateTimeOffset]::Now.ToString('o');passed=$true;scope='Actual local process/package ownership and listed GET queries; not new tournament, SMS or bank acceptance';state=$report.state;reportPath=$ReportPath;reportSha256=(Get-FileHash -LiteralPath $reportFile).Hash.ToLowerInvariant();jarSha256=$report.backendJarSha256;checks=$checks;listeners=$ports;safeResume='Read docs/01-development/交接记录.md and this immutable checkpoint. Revalidate owned processes and packages; recover sessions only. Never initialize or replay completed admission, registration, receipt, refund, score, award or capability actions.';externalGatesRemainOpen=$true}
$stage=$out+'.stage'
$bytes=[Text.UTF8Encoding]::new($false).GetBytes(($receipt | ConvertTo-Json -Depth 12)+"`n")
$stream=[IO.File]::Open($stage,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
[IO.File]::Move($stage,$out)
Write-Host ('PASS actual local package ownership and listed queries; checkpoint '+$out)
