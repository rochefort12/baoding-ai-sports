#requires -Version 7.0
<# .SYNOPSIS 编译正式 B 端和后端，不启动服务、不读取凭据。 #>
[CmdletBinding()]
param([switch]$PackageBackend)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
Push-Location (Join-Path $taskRoot 'plus-ui')
try { & pnpm run check; if($LASTEXITCODE -ne 0){throw 'Frontend check failed.'} } finally {Pop-Location}
Push-Location (Join-Path $taskRoot 'backend')
try {
    $taskGoal=if($PackageBackend){'package'}else{'compile'}
    & mvn '-Plocal' '-pl' 'ruoyi-admin' '-am' '-DskipTests' $taskGoal
    if($LASTEXITCODE -ne 0){throw 'Backend build failed.'}
} finally {Pop-Location}
