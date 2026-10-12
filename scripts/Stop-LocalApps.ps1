#requires -Version 7.0
[CmdletBinding()]
param([switch]$Backend, [switch]$Frontend)
. "$PSScriptRoot/Common.ps1"
if (!$Backend -and !$Frontend) { $Backend=$true; $Frontend=$true }
$targets=@()
if ($Backend) { $targets += @{name='backend';argument="$WorkspaceRoot/backend/ruoyi-admin/target/ruoyi-admin.jar";executable='java.exe'} }
if ($Frontend) { $targets += @{name='frontend';argument="$WorkspaceRoot/plus-ui/node_modules/vite/bin/vite.js";executable='node.exe'} }
foreach ($target in $targets) {
    $pidFile = "$WorkspaceRoot/.local/$($target.name).pid"
    if (!(Test-Path -LiteralPath $pidFile)) { continue }
    $recordedPid = [int](Get-Content -LiteralPath $pidFile)
    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$recordedPid"
    if (!$process) { Write-Host "$($target.name) already stopped."; continue }
    $commandLine = $process.CommandLine.Replace('\','/')
    $expectedArgument = $target.argument.Replace('\','/')
    if ([IO.Path]::GetFileName($process.ExecutablePath) -ne $target.executable -or $commandLine.IndexOf($expectedArgument, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "Recorded $($target.name) PID does not match this workspace; no process was stopped."
    }
    Stop-Process -Id $recordedPid
    Write-Host "Stopped recorded $($target.name) PID $recordedPid."
}
