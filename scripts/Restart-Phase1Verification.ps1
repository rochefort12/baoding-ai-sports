#requires -Version 7.0
[CmdletBinding()]param([switch]$Main,[string]$PackagePath)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$folder=Join-Path $WorkspaceRoot '.local/phase1-implementation'
$receiptFile=Join-Path $folder 'verification-runtime.json'
$receipt=Get-Content -LiteralPath $receiptFile -Raw|ConvertFrom-Json
if($receipt.database -notmatch '^aisports_verify_phase1_[a-f0-9]{32}$' -or $receipt.redisPrefix -notmatch '^aisports:verify:phase1:[a-f0-9]{32}:$'){throw 'Invalid isolated runtime identity'}
$sourceJar=if($PackagePath){(Resolve-Path -LiteralPath $PackagePath).Path}else{Join-Path $WorkspaceRoot 'backend/ruoyi-admin/target/ruoyi-admin.jar'}
$resolvedRoot=(Resolve-Path -LiteralPath $WorkspaceRoot).Path
if(-not $sourceJar.StartsWith($resolvedRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetExtension($sourceJar) -ne '.jar'){throw 'Package must be an existing local project JAR'}
$packageHash=(Get-FileHash -LiteralPath $sourceJar).Hash.ToLowerInvariant()
$packageFolder=Join-Path $WorkspaceRoot ('.local/runtime-packages/'+$packageHash)
New-Item -ItemType Directory -Path $packageFolder -Force | Out-Null
$jar=Join-Path $packageFolder 'ruoyi-admin.jar'
if(Test-Path -LiteralPath $jar){if((Get-FileHash -LiteralPath $jar).Hash.ToLowerInvariant() -ne $packageHash){throw 'Immutable runtime package changed'}}else{Copy-Item -LiteralPath $sourceJar -Destination $jar}
$existing=Get-CimInstance Win32_Process -Filter "ProcessId=$($receipt.pid)"
if($existing){
    if($existing.CommandLine -notlike '*体育*ruoyi-admin.jar*--server.port=8082*'){throw 'Process identity changed'}
    Stop-Process -Id $receipt.pid
    # Windows can retain the listener briefly after process termination. Wait only
    # for this identified listener; never stop a replacement or unrelated owner.
    for($attempt=0;$attempt -lt 50;$attempt++){
        $listener=Get-NetTCPConnection -State Listen -LocalPort 8082 -ErrorAction SilentlyContinue
        if(-not $listener){break}
        if($listener.OwningProcess -ne $receipt.pid){throw 'Verification port changed owner during shutdown'}
        Start-Sleep -Milliseconds 100
    }
}
if(Get-NetTCPConnection -State Listen -LocalPort 8082 -ErrorAction SilentlyContinue){throw 'Verification port is owned by another process'}
if($Main){& "$PSScriptRoot/Start-Backend.ps1" -JavaHome 'D:/dev/jdk17' -Background}
$env:POSTGRES_DB=$receipt.database;$env:MCP_ENABLED='true'
$p=Start-Process -FilePath 'D:/dev/jdk17/bin/java.exe' -ArgumentList @('-Xmx768m','-jar',"`"$jar`"",'--spring.profiles.active=local','--server.port=8082','--server.address=127.0.0.1','--captcha.enable=false',('--redisson.keyPrefix='+$receipt.redisPrefix),'--aisports.ai.daily-tasks=100') -WorkingDirectory "$WorkspaceRoot/backend" -WindowStyle Hidden -RedirectStandardOutput (Join-Path $folder 'http-test-runtime.log') -RedirectStandardError (Join-Path $folder 'http-test-error.log') -PassThru
$receipt.pid=$p.Id;$receipt.jarSHA256=$packageHash;$receipt|Add-Member -NotePropertyName jarPath -NotePropertyValue $jar -Force;$receipt|ConvertTo-Json|Set-Content -LiteralPath $receiptFile
Write-Host 'Restarted the same isolated verification environment with the current build.'
