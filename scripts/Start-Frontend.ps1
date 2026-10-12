#requires -Version 7.0
[CmdletBinding()]
param([string]$NodeHome = $env:AISPORTS_NODE_HOME, [string]$PnpmCommand = 'pnpm', [switch]$Background)
. "$PSScriptRoot/Common.ps1"
if ($NodeHome) { $env:PATH = "$NodeHome;$env:PATH" }
& node --version
Assert-NativeExit 'Node runtime check (requires >=20.19)'
Push-Location "$WorkspaceRoot/plus-ui"
try {
& $PnpmCommand install --frozen-lockfile
Assert-NativeExit 'Frontend dependency installation'
if ($Background) {
    $nodeCommand = (Get-Command node).Source
    $vitePath = "$WorkspaceRoot/plus-ui/node_modules/vite/bin/vite.js"
    New-Item -ItemType Directory -Path "$WorkspaceRoot/.local" -Force | Out-Null
    $process = Start-Process -FilePath $nodeCommand -ArgumentList @("`"$vitePath`"", '--mode', 'development') -WorkingDirectory "$WorkspaceRoot/plus-ui" -WindowStyle Hidden -RedirectStandardOutput "$WorkspaceRoot/.local/frontend-runtime.log" -RedirectStandardError "$WorkspaceRoot/.local/frontend-runtime-error.log" -PassThru
    $process.Id | Set-Content "$WorkspaceRoot/.local/frontend.pid"
    Write-Host "Frontend started in background, recorded PID $($process.Id)."
    return
}
& $PnpmCommand run dev
Assert-NativeExit 'Frontend development server'
} finally { Pop-Location }
