#requires -Version 7.0
#requires -RunAsAdministrator
<# .SYNOPSIS 仅放行本项目运行中的前端测试端口，来源限本地子网；在管理员PowerShell 7执行。 #>
[CmdletBinding()]
param([ValidateRange(1024,65535)][int]$Port=5173)
. "$PSScriptRoot/Common.ps1"
$taskPidFile=Join-Path $WorkspaceRoot '.local/frontend.pid'
if(!(Test-Path -LiteralPath $taskPidFile)){throw 'Start the project frontend first.'}
$taskFrontendPid=[int](Get-Content -LiteralPath $taskPidFile)
$taskFrontendProcess=Get-CimInstance Win32_Process -Filter "ProcessId=$taskFrontendPid"
$taskExpectedVite=(Join-Path $WorkspaceRoot 'plus-ui/node_modules/vite/bin/vite.js').Replace('\','/')
if(!$taskFrontendProcess -or [IO.Path]::GetFileName($taskFrontendProcess.ExecutablePath) -ne 'node.exe' -or !$taskFrontendProcess.CommandLine.Replace('\','/').Contains($taskExpectedVite)){
    throw 'Recorded frontend process does not belong to this project.'
}
$taskListener=Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue | Where-Object {$_.OwningProcess -eq $taskFrontendPid -and $_.LocalAddress -in @('0.0.0.0','::')}
if(!$taskListener){throw 'The project frontend must listen on the requested LAN port first.'}
$taskRuleName="AISports-Frontend-LAN-$Port"
$taskRuleParameters=@{Direction='Inbound';Action='Allow';Protocol='TCP';LocalPort=$Port;RemoteAddress='LocalSubnet';Profile='Any';Program=$taskFrontendProcess.ExecutablePath;Enabled='True'}
if(Get-NetFirewallRule -Name $taskRuleName -ErrorAction SilentlyContinue){
    Set-NetFirewallRule -Name $taskRuleName @taskRuleParameters | Out-Null
}else{
    New-NetFirewallRule -Name $taskRuleName -DisplayName "AISports frontend LAN test $Port" @taskRuleParameters | Out-Null
}
Write-Host "AISports frontend TCP $Port is allowed from the local subnet."
