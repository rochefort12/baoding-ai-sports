#requires -Version 7.0
[CmdletBinding()]
param([string]$JavaHome = $env:JAVA_HOME, [string]$MavenCommand = 'mvn', [switch]$Rebuild, [switch]$Background)
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
if ($JavaHome) { $env:JAVA_HOME = $JavaHome; $env:PATH = "$JavaHome/bin;$env:PATH" }
if ($Rebuild -or !(Test-Path -LiteralPath "$WorkspaceRoot/backend/ruoyi-admin/target/ruoyi-admin.jar")) {
    Push-Location "$WorkspaceRoot/backend"
    try {
        & $MavenCommand '-Plocal' '-pl' 'ruoyi-admin' '-am' '-DskipTests' 'package'
        Assert-NativeExit 'Backend build'
    } finally { Pop-Location }
}
$jarPath = "$WorkspaceRoot/backend/ruoyi-admin/target/ruoyi-admin.jar"
# The JVM must not keep Maven's output open while another build rewrites it.
$packageHash=(Get-FileHash -LiteralPath $jarPath).Hash.ToLowerInvariant()
$packageFolder=Join-Path $WorkspaceRoot ('.local/runtime-packages/'+$packageHash)
New-Item -ItemType Directory -Path $packageFolder -Force | Out-Null
$runtimeJar=Join-Path $packageFolder 'ruoyi-admin.jar'
if(Test-Path -LiteralPath $runtimeJar){if((Get-FileHash -LiteralPath $runtimeJar).Hash.ToLowerInvariant() -ne $packageHash){throw 'Immutable runtime package changed'}}else{Copy-Item -LiteralPath $jarPath -Destination $runtimeJar}
$jarPath=$runtimeJar
if ($Background) {
    $javaCommand = (Get-Command java).Source
    New-Item -ItemType Directory -Path "$WorkspaceRoot/.local" -Force | Out-Null
    $process = Start-Process -FilePath $javaCommand -ArgumentList @('-jar', "`"$jarPath`"", '--spring.profiles.active=local') -WorkingDirectory "$WorkspaceRoot/backend" -WindowStyle Hidden -RedirectStandardOutput "$WorkspaceRoot/.local/backend-default-runtime.log" -RedirectStandardError "$WorkspaceRoot/.local/backend-default-error.log" -PassThru
    $process.Id | Set-Content "$WorkspaceRoot/.local/backend.pid"
    Write-Host "Backend started in background, recorded PID $($process.Id)."
    return
}
Push-Location "$WorkspaceRoot/backend"
try {
    & java '-jar' $jarPath '--spring.profiles.active=local'
    Assert-NativeExit 'Backend startup'
} finally { Pop-Location }
