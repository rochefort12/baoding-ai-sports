#requires -Version 7.0
[CmdletBinding()]
param([switch]$Background)
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) { throw 'Node.js is required for the AI gateway.' }
$entry = Join-Path $WorkspaceRoot 'ai-gateway/server.mjs'
if ($Background) {
    New-Item -ItemType Directory -Path "$WorkspaceRoot/.local" -Force | Out-Null
    $process = Start-Process -FilePath $node.Source -ArgumentList @("`"$entry`"") -WorkingDirectory (Join-Path $WorkspaceRoot 'ai-gateway') -WindowStyle Hidden -RedirectStandardOutput "$WorkspaceRoot/.local/ai-gateway.log" -RedirectStandardError "$WorkspaceRoot/.local/ai-gateway-error.log" -PassThru
    $process.Id | Set-Content "$WorkspaceRoot/.local/ai-gateway.pid"
    if ($process.WaitForExit(750)) { throw 'AI gateway exited during startup; check .local/ai-gateway-error.log.' }
    Write-Host "AI gateway started in background, recorded PID $($process.Id)."
    return
}
& $node.Source $entry
Assert-NativeExit 'AI gateway'
