#requires -Version 7.0
# Activate gateway-only changes without replaying AI tasks or restarting the business service.
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$taskRuntime=Get-Content -LiteralPath "$WorkspaceRoot/.local/phase1-implementation/verification-runtime.json" -Raw|ConvertFrom-Json
if($taskRuntime.port -ne 8082 -or $taskRuntime.database -notmatch '^aisports_verify_phase1_[a-f0-9]{32}$'){throw 'Expected the existing isolated trial.'}
$taskListener=@(Get-NetTCPConnection -State Listen -LocalPort 8091)
$taskGatewayPid=[int](Get-Content -LiteralPath "$WorkspaceRoot/.local/ai-gateway.pid" -Raw)
$taskGateway=Get-CimInstance Win32_Process -Filter "ProcessId=$taskGatewayPid"
if($taskListener.Count -ne 1 -or $taskListener[0].LocalAddress -ne '127.0.0.1' -or $taskListener[0].OwningProcess -ne $taskGatewayPid -or !$taskGateway -or !$taskGateway.CommandLine.Replace('\','/').Contains(($WorkspaceRoot+'/ai-gateway/server.mjs').Replace('\','/'))){throw 'Actual gateway ownership must match the local trial.'}
$taskPriorPassword=$env:PGPASSWORD
try{
 $env:PGPASSWORD=$env:POSTGRES_PASSWORD
 $taskPsql='C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin/psql.exe'
 $taskBusy=& $taskPsql '-X' '-h' '127.0.0.1' '-p' $env:POSTGRES_PORT '-U' $env:POSTGRES_USER '-d' $taskRuntime.database '-At' '-v' 'ON_ERROR_STOP=1' '-c' "BEGIN READ ONLY; SELECT (SELECT count(*) FROM asp_ai_task WHERE status='PROCESSING')+(SELECT count(*) FROM asp_agent_run WHERE status='running' AND expires_at>CURRENT_TIMESTAMP); ROLLBACK;"
 Assert-NativeExit 'Read active work before gateway activation'
 $taskCount=@($taskBusy|Where-Object {$_ -match '^\d+$'})
 if($taskCount.Count -ne 1 -or [int]$taskCount[0] -ne 0){throw 'Active work remains; leave it running and activate after it ends.'}
}finally{$env:PGPASSWORD=$taskPriorPassword}
$taskOut=Join-Path $WorkspaceRoot ('.local/assistant-event-repair-20261012/gateway-field-repair-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskOut|Out-Null
foreach($taskLog in @('ai-gateway.log','ai-gateway-error.log')){
 $taskPath=Join-Path $WorkspaceRoot ('.local/'+$taskLog)
 if(Test-Path -LiteralPath $taskPath){Copy-Item -LiteralPath $taskPath -Destination (Join-Path $taskOut ($taskLog+'.before'))}
}
$taskReceipt=@{at=[DateTimeOffset]::Now.ToString('o');scope='Gateway-only activation, no test or task replay';activated=$false;tests='NOT_RUN_BY_USER_REQUEST';priorPid=$taskGatewayPid;backendJarSHA256=$taskRuntime.jarSHA256;source=@{path='ai-gateway/kernel.mjs';sha256=(Get-FileHash -LiteralPath "$WorkspaceRoot/ai-gateway/kernel.mjs" -Algorithm SHA256).Hash.ToLowerInvariant()}}
try{
 Stop-Process -Id $taskGatewayPid
 Wait-Process -Id $taskGatewayPid -Timeout 10 -ErrorAction SilentlyContinue
 & "$PSScriptRoot/Start-AiGateway.ps1" -Background
 $taskReceipt.newPid=[int](Get-Content -LiteralPath "$WorkspaceRoot/.local/ai-gateway.pid" -Raw)
 $taskReceipt.activated=$true
}finally{
 $taskReceipt.finishedAt=[DateTimeOffset]::Now.ToString('o')
 $taskReceipt|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $taskOut 'receipt.json')
 Write-Host ('Gateway activation: '+$taskOut)
}
