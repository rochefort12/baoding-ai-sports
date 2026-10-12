#requires -Version 7.0
# Reload verified trial Vite processes so Windows file-watch caches cannot serve old exports.
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
$taskOut=Join-Path $WorkspaceRoot ('.local/assistant-event-repair-20261012/frontend-reload-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskOut|Out-Null
$taskDemoPath=Join-Path $WorkspaceRoot '.local/demo-20261011/frontend-runtime.json'
$taskDemo=Get-Content -LiteralPath $taskDemoPath -Raw|ConvertFrom-Json
$taskLanListener=@(Get-NetTCPConnection -State Listen -LocalPort 5193)
if($taskLanListener.Count -ne 1 -or $taskLanListener[0].LocalAddress -ne '192.168.1.236'){throw 'Unexpected LAN trial listener.'}
$taskLan=Get-CimInstance Win32_Process -Filter "ProcessId=$($taskLanListener[0].OwningProcess)"
if($taskLan.ExecutablePath -ne 'D:\dev\nodejs\node.exe' -or $taskLan.CommandLine -notmatch '"([^"\r\n]+vite-lan-trial\.mjs)"$'){throw 'LAN process ownership could not be verified.'}
$taskLanWrapper=$Matches[1];$taskLanRoot=[IO.Path]::GetFullPath((Join-Path $WorkspaceRoot '.local/three-person-lan-20261012'))+[IO.Path]::DirectorySeparatorChar
if(![IO.Path]::GetFullPath($taskLanWrapper).StartsWith($taskLanRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'LAN wrapper is outside the known trial area.'}
$taskLanReceipt=Get-Content -LiteralPath (Join-Path (Split-Path $taskLanWrapper -Parent) 'receipt.json') -Raw|ConvertFrom-Json
if($taskLanReceipt.frontend.pid -ne $taskLan.ProcessId -or $taskLanReceipt.frontend.wrapper -ne $taskLanWrapper -or (Get-FileHash -LiteralPath $taskLanWrapper -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskLanReceipt.frontend.wrapperSha256){throw 'LAN wrapper does not match its receipt.'}
$taskDemoProcess=Get-CimInstance Win32_Process -Filter "ProcessId=$($taskDemo.pid)"
$taskDemoListener=@(Get-NetTCPConnection -State Listen -LocalPort 5192)
if($taskDemoListener.Count -ne 1 -or $taskDemoListener[0].LocalAddress -ne '127.0.0.1' -or $taskDemoListener[0].OwningProcess -ne $taskDemo.pid -or !$taskDemoProcess.CommandLine.Contains($taskDemo.wrapper)){throw 'Loopback process ownership could not be verified.'}
Copy-Item -LiteralPath $taskDemoPath -Destination (Join-Path $taskOut 'previous-demo-runtime.json')
Copy-Item -LiteralPath (Join-Path (Split-Path $taskLanWrapper -Parent) 'receipt.json') -Destination (Join-Path $taskOut 'previous-lan-receipt.json')
foreach($taskLog in @('frontend.out.log','frontend.err.log')){Copy-Item -LiteralPath (Join-Path $WorkspaceRoot ('.local/demo-20261011/'+$taskLog)) -Destination (Join-Path $taskOut ('demo-'+$taskLog))}
Stop-Process -Id $taskLan.ProcessId;Wait-Process -Id $taskLan.ProcessId -Timeout 10 -ErrorAction SilentlyContinue
Stop-Process -Id $taskDemo.pid;Wait-Process -Id $taskDemo.pid -Timeout 10 -ErrorAction SilentlyContinue
& "$PSScriptRoot/Start-DemoFrontend.ps1"
for($taskAttempt=0;$taskAttempt -lt 40;$taskAttempt++){if(Get-NetTCPConnection -State Listen -LocalPort 5192 -ErrorAction SilentlyContinue){break};Start-Sleep -Milliseconds 250}
& "$PSScriptRoot/Start-ThreePersonLanTrial.ps1"
$taskLoopback=(Invoke-WebRequest 'http://127.0.0.1:5192/src/utils/aiCandidateForm.ts' -TimeoutSec 10).Content
$taskLanSource=(Invoke-WebRequest 'http://192.168.1.236:5193/src/utils/aiCandidateForm.ts' -TimeoutSec 10).Content
if(!$taskLoopback.Contains('canRestoreCandidateUnits') -or !$taskLanSource.Contains('canRestoreCandidateUnits')){throw 'Trial still serves an old candidate form module.'}
@{at=[DateTimeOffset]::Now.ToString('o');passed=$true;scope='Reloaded verified trial frontends only; no business data, firewall, backend or main-site change';currentModuleOnBoth=$true;oldDemoPid=$taskDemo.pid;oldLanPid=$taskLan.ProcessId}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $taskOut 'receipt.json')
Write-Output ('Trial frontend reload evidence: '+$taskOut)
