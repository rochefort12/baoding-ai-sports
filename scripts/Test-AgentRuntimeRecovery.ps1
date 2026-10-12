#requires -Version 7.0
[CmdletBinding()]param([Parameter(Mandatory)][string]$ContextPath,[Parameter(Mandatory)][string]$FailedReceipt,[Parameter(Mandatory)][string]$AcceptedReceipt)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$taskRuntime=Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.local/phase1-implementation/verification-runtime.json') -Raw|ConvertFrom-Json
& "$PSScriptRoot/Restart-Phase1Verification.ps1" -PackagePath $taskRuntime.jarPath
$taskReady=$false
for($taskAttempt=0;$taskAttempt -lt 40;$taskAttempt++){try{$taskValue=Invoke-RestMethod 'http://127.0.0.1:8082/sports/types' -TimeoutSec 2;if($taskValue.code -eq 200){$taskReady=$true;break}}catch{};Start-Sleep -Milliseconds 1000}
if(!$taskReady){throw 'Restarted isolated backend did not become ready'}
$env:AISPORTS_REGRESSION_CONTEXT=(Resolve-Path -LiteralPath $ContextPath).Path
try{& 'D:/dev/nodejs/node.exe' "$PSScriptRoot/Test-AgentRuntimeRecovery.mjs" (Resolve-Path -LiteralPath $FailedReceipt).Path (Resolve-Path -LiteralPath $AcceptedReceipt).Path;Assert-NativeExit 'Agent restart recovery'}
finally{Remove-Item Env:AISPORTS_REGRESSION_CONTEXT -ErrorAction SilentlyContinue}
