#requires -Version 7.0
[CmdletBinding()]param([Parameter(Mandatory)][string]$ContextPath)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$taskReady=$false
for($taskAttempt=0;$taskAttempt -lt 30;$taskAttempt++){
 try {$taskValue=Invoke-RestMethod -Uri 'http://127.0.0.1:8082/sports/types' -TimeoutSec 2;if($taskValue.code -eq 200){$taskReady=$true;break}}catch{}
 Start-Sleep -Milliseconds 1000
}
if(!$taskReady){throw 'Isolated backend did not become ready; no model acceptance started'}
$env:AISPORTS_REGRESSION_CONTEXT=(Resolve-Path -LiteralPath $ContextPath).Path
try { & 'D:/dev/nodejs/node.exe' (Join-Path $PSScriptRoot 'Test-AgentRuntimeLive.mjs');Assert-NativeExit 'Real Agent runtime acceptance' }
finally {Remove-Item Env:AISPORTS_REGRESSION_CONTEXT -ErrorAction SilentlyContinue}
