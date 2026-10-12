#requires -Version 7.0
[CmdletBinding()]param([Parameter(Mandatory)][string]$PackagePath)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$taskRuntime=Get-Content -LiteralPath "$WorkspaceRoot/.local/phase1-implementation/verification-runtime.json" -Raw|ConvertFrom-Json
if($taskRuntime.database -notmatch '^aisports_verify_phase1_[a-f0-9]{32}$' -or $taskRuntime.port -ne 8082){throw 'Only the existing isolated trial may be activated'}
$taskPsql='C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin/psql.exe'
$taskPriorPgPassword=$env:PGPASSWORD
try{
 $env:PGPASSWORD=$env:POSTGRES_PASSWORD
 $taskActive=& $taskPsql '-X' '-h' '127.0.0.1' '-p' $env:POSTGRES_PORT '-U' $env:POSTGRES_USER '-d' $taskRuntime.database '-At' '-v' 'ON_ERROR_STOP=1' '-c' "SELECT (SELECT count(*) FROM asp_agent_run WHERE status='running' AND expires_at>CURRENT_TIMESTAMP)+(SELECT count(*) FROM asp_ai_task WHERE status='PROCESSING');"
 Assert-NativeExit 'Read-only active task check'
 if([int]$taskActive -ne 0){throw 'Trial has active work; activation deferred without interrupting it'}
}finally{$env:PGPASSWORD=$taskPriorPgPassword}
$taskOut=Join-Path $WorkspaceRoot ('.local/agent-material-progress-20261012/activation-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskOut|Out-Null
Copy-Item -LiteralPath "$WorkspaceRoot/.local/phase1-implementation/verification-runtime.json" -Destination (Join-Path $taskOut 'previous-runtime.json')
$taskGatewayPid=[int](Get-Content -LiteralPath "$WorkspaceRoot/.local/ai-gateway.pid" -Raw)
$taskGatewayProcess=Get-CimInstance Win32_Process -Filter "ProcessId=$taskGatewayPid"
if($taskGatewayProcess){if($taskGatewayProcess.CommandLine -notlike ('*'+$WorkspaceRoot+'*ai-gateway*server.mjs*')){throw 'Gateway process ownership changed'};Stop-Process -Id $taskGatewayPid;Wait-Process -Id $taskGatewayPid -Timeout 10 -ErrorAction SilentlyContinue}
foreach($taskLog in @('.local/ai-gateway.log','.local/ai-gateway-error.log','.local/phase1-implementation/http-test-runtime.log','.local/phase1-implementation/http-test-error.log')){if(Test-Path -LiteralPath (Join-Path $WorkspaceRoot $taskLog)){Copy-Item -LiteralPath (Join-Path $WorkspaceRoot $taskLog) -Destination (Join-Path $taskOut ($taskLog.Replace('/','_')+'.before'))}}
& "$PSScriptRoot/Start-AiGateway.ps1" -Background
& "$PSScriptRoot/Restart-Phase1Verification.ps1" -PackagePath $PackagePath
$taskDeadline=[DateTimeOffset]::Now.AddSeconds(45);$taskReady=$false
while([DateTimeOffset]::Now -lt $taskDeadline){try{$taskProbe=Invoke-WebRequest 'http://127.0.0.1:8082/sports/public/events' -TimeoutSec 3;if($taskProbe.StatusCode -eq 200){$taskReady=$true;break}}catch{};Start-Sleep -Milliseconds 500}
if(!$taskReady){throw 'Trial HTTP startup timed out; package and failure evidence retained. No business request was replayed.'}
@{at=[DateTimeOffset]::Now.ToString('o');scope='Existing isolated trial only; no seeds, migration, public listener, or main activation';database=$taskRuntime.database;previousPackage=$taskRuntime.jarSHA256;newPackage=(Get-FileHash -LiteralPath $PackagePath -Algorithm SHA256).Hash.ToLowerInvariant()}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $taskOut 'receipt.json')
Write-Host ('Activation evidence: '+$taskOut)
