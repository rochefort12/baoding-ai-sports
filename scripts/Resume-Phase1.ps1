#requires -Version 7.0
[CmdletBinding()]param([switch]$DependenciesOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$alias='C:/ProgramData/AISports/desktop-sports-e3000ec'
$link=Get-Item -LiteralPath $alias
if($link.LinkType -ne 'Junction' -or [IO.Path]::GetFullPath($link.Target) -ne [IO.Path]::GetFullPath("$WorkspaceRoot/.local")){throw 'Project runtime alias changed'}
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
function Preserve-Log([string]$path){if(Test-Path -LiteralPath $path){Copy-Item -LiteralPath $path -Destination ($path+'.before-resume-'+$stamp)}}
if(!(Get-NetTCPConnection -State Listen -LocalPort $env:POSTGRES_PORT -ErrorAction SilentlyContinue)){
 Preserve-Log "$WorkspaceRoot/.local/postgres-start.log"
 $control=Start-Process "$alias/toolchains/postgresql-17.11/pgsql/bin/pg_ctl.exe" -ArgumentList @('-D',"`"$alias/postgres-data`"",'-l',"`"$alias/postgres-runtime.log`"",'-w','start') -WindowStyle Hidden -RedirectStandardOutput "$WorkspaceRoot/.local/postgres-start.log" -RedirectStandardError "$WorkspaceRoot/.local/postgres-start-error.log" -PassThru
 if(!$control.WaitForExit(30000) -or $control.ExitCode -ne 0){throw 'PostgreSQL recovery failed; preserve and inspect local log'}
}
$env:PGPASSWORD=$env:POSTGRES_PASSWORD
try{& "$alias/toolchains/postgresql-17.11/pgsql/bin/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $env:POSTGRES_DB -At -v ON_ERROR_STOP=1 -c "SELECT version,checksum FROM aisports_schema_history WHERE version IN ('V030','V031','V032','V033','V034','V035','V036','V037','V038') ORDER BY version";Assert-NativeExit 'Durable migration ledger'}finally{Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue}
if(!(Get-NetTCPConnection -State Listen -LocalPort $env:REDIS_PORT -ErrorAction SilentlyContinue)){
 Preserve-Log "$WorkspaceRoot/.local/redis-runtime.log"
 $redis=Start-Process "$alias/toolchains/redis-7.4.11/Redis-7.4.11-Windows-x64-msys2/redis-server.exe" -ArgumentList @('redis-native.conf') -WorkingDirectory $alias -WindowStyle Hidden -RedirectStandardOutput "$WorkspaceRoot/.local/redis-runtime.log" -RedirectStandardError "$WorkspaceRoot/.local/redis-error.log" -PassThru
 $redis.Id|Set-Content "$WorkspaceRoot/.local/redis.pid"
}
if(!(Get-NetTCPConnection -State Listen -LocalPort $env:MINIO_API_PORT -ErrorAction SilentlyContinue)){
 Preserve-Log "$WorkspaceRoot/.local/minio-runtime.log"
 $storage=Start-Process 'D:/RetailOS AI 零售全域经营平台/.runtime/toolchains/minio/minio.exe' -ArgumentList @('server',"`"$WorkspaceRoot/.local/minio-data`"",'--address',"127.0.0.1:$env:MINIO_API_PORT",'--console-address',"127.0.0.1:$env:MINIO_CONSOLE_PORT",'--quiet') -WorkingDirectory "$WorkspaceRoot/.local" -WindowStyle Hidden -RedirectStandardOutput "$WorkspaceRoot/.local/minio-runtime.log" -RedirectStandardError "$WorkspaceRoot/.local/minio-error.log" -PassThru
 $storage.Id|Set-Content "$WorkspaceRoot/.local/minio.pid"
}
if(!$DependenciesOnly){
 $env:PATH='D:/dev/nodejs;'+$env:PATH
 if(!(Get-NetTCPConnection -State Listen -LocalPort 8091 -ErrorAction SilentlyContinue)){Preserve-Log "$WorkspaceRoot/.local/ai-gateway.log";& "$PSScriptRoot/Start-AiGateway.ps1" -Background}
 if(!(Get-NetTCPConnection -State Listen -LocalPort 5190 -ErrorAction SilentlyContinue)){Preserve-Log "$WorkspaceRoot/.local/frontend-runtime.log";& "$PSScriptRoot/Start-Frontend.ps1" -NodeHome 'D:/dev/nodejs' -PnpmCommand 'C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/pnpm.cmd' -Background}
}
Write-Host 'Resumed existing project storage without re-seeding business records.'
