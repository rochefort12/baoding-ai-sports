#requires -Version 7.0
[CmdletBinding()]
param()
. "$PSScriptRoot/Common.ps1"
$taskRoot=Join-Path $WorkspaceRoot '.local/docker-stack'
$taskEnv=Join-Path $taskRoot 'runtime.env'
New-Item -ItemType Directory -Path $taskRoot -Force | Out-Null
if (!(Test-Path -LiteralPath $taskEnv)) {
    Import-LocalEnvironment
    $taskKeys=@('POSTGRES_IMAGE','REDIS_IMAGE','POSTGRES_USER','POSTGRES_PASSWORD','APP_DB_USER','APP_DB_PASSWORD','REDIS_PASSWORD','JWT_SECRET','MONITOR_PASSWORD','DEEPSEEK_API_KEY','DASHSCOPE_API_KEY','MCP_ENABLED','PARTICIPANT_SMS_ECHO_CODE')
    $taskKeys+=@(Get-ChildItem Env: | Where-Object Name -Match '^(AI_|TENCENT_SMS_|ALIYUN_CAPTCHA_)' | ForEach-Object Name)
    $taskLines=foreach($taskKey in $taskKeys|Select-Object -Unique){$taskValue=[Environment]::GetEnvironmentVariable($taskKey);if($null-ne $taskValue){"$taskKey='"+$taskValue.Replace("'","\'")+"'"}}
    $taskLines+=@('POSTGRES_DB=aisports_docker_fresh','POSTGRES_PORT=55432','REDIS_PORT=56379','MINIO_API_PORT=29000','MINIO_CONSOLE_PORT=29001','DOCKER_WEB_PORT=5193','MINIO_ROOT_USER=aisportsdocker',('MINIO_ROOT_PASSWORD='+[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant()))
    [IO.File]::WriteAllText($taskEnv,($taskLines -join "`n")+"`n")
}
. "$PSScriptRoot/DockerStack.Common.ps1"
$taskStatePath=Join-Path $taskRoot 'fresh-bootstrap.json'
if (!(Test-Path -LiteralPath $taskStatePath)) {
    # The retained dump and trial database are deliberately outside this lifecycle.
    Copy-Item -LiteralPath $taskEnv -Destination "$taskRoot/runtime-before-fresh.env"
    $taskContent=Get-Content -LiteralPath $taskEnv -Raw
    $taskContent=[regex]::Replace($taskContent,'(?m)^POSTGRES_DB=.*$','POSTGRES_DB=aisports_docker_fresh')
    [IO.File]::WriteAllText($taskEnv,$taskContent)
    Import-DockerEnvironment
    $taskState=@{mode='fresh-baseline';database='aisports_docker_fresh';createdAt=[DateTimeOffset]::Now.ToString('o');frameworkReady=$false;initialized=$false}
    $taskState|ConvertTo-Json|Set-Content -LiteralPath $taskStatePath -Encoding utf8
}else{$taskState=Get-Content -LiteralPath $taskStatePath -Raw|ConvertFrom-Json -AsHashtable}
if($env:POSTGRES_DB-ne'aisports_docker_fresh' -or $taskState.database-ne$env:POSTGRES_DB){throw 'Fresh database metadata/configuration mismatch.'}
foreach($taskKey in @('POSTGRES_USER','APP_DB_USER')){if([Environment]::GetEnvironmentVariable($taskKey)-notmatch'^[a-z][a-z0-9_]{0,62}$'){throw 'Invalid database role identifier.'}}
if($env:APP_DB_PASSWORD-notmatch'^[a-f0-9]{64}$'){throw 'Application password must be generated hex.'}
Write-DockerApplicationEnvironment
New-Item -ItemType Directory -Path "$taskRoot/backend-logs",(Join-Path $WorkspaceRoot '.local/organization-files') -Force|Out-Null
[IO.File]::WriteAllText("$taskRoot/redis.conf","bind 0.0.0.0`nprotected-mode yes`nport 6379`nappendonly yes`nrequirepass $env:REDIS_PASSWORD`n")
& $taskDocker @taskCompose config --quiet
Assert-NativeExit 'Validate full Docker configuration'
& $taskDocker @taskCompose up -d --wait --wait-timeout 120 postgres redis minio
Assert-NativeExit 'Docker infrastructure readiness'
$taskExists=Invoke-DockerSql "SELECT count(*) FROM pg_database WHERE datname='$env:POSTGRES_DB'" 'postgres'
if([int]$taskExists-eq0){Invoke-DockerSql "CREATE DATABASE $env:POSTGRES_DB OWNER $env:POSTGRES_USER" 'postgres'|Out-Null}
if(!$taskState.frameworkReady){
    $taskTables=Invoke-DockerSql "SELECT count(*) FROM pg_tables WHERE schemaname='public'"
    if([int]$taskTables-ne0){throw 'Fresh initialization refuses an existing or partially initialized database.'}
    $taskSql="BEGIN;`n"+[IO.File]::ReadAllText("$WorkspaceRoot/backend/script/sql/postgres/postgres_ry_vue_5.X.sql")+"`n"+[IO.File]::ReadAllText("$WorkspaceRoot/backend/script/sql/postgres/postgres_ry_workflow.sql")+"`nCOMMIT;"
    Invoke-DockerSql $taskSql|Set-Content -LiteralPath "$taskRoot/framework-init.log"
    $taskRoleExists=Invoke-DockerSql "SELECT count(*) FROM pg_roles WHERE rolname='$env:APP_DB_USER'"
    if([int]$taskRoleExists-eq0){Invoke-DockerSql "CREATE ROLE $env:APP_DB_USER LOGIN PASSWORD '$env:APP_DB_PASSWORD' NOSUPERUSER NOCREATEDB NOCREATEROLE"|Out-Null}
    Invoke-DockerSql "GRANT CONNECT ON DATABASE $env:POSTGRES_DB TO $env:APP_DB_USER; GRANT USAGE ON SCHEMA public TO $env:APP_DB_USER; GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO $env:APP_DB_USER; GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA public TO $env:APP_DB_USER; ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO $env:APP_DB_USER; ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE,SELECT ON SEQUENCES TO $env:APP_DB_USER;"|Out-Null
    # A random local platform password replaces upstream's public default. pgcrypto
    # creates the BCrypt hash in the new database; plaintext remains in the private file.
    $taskPassword='A!9x'+[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(12)).ToLowerInvariant()
    Invoke-DockerSql "CREATE EXTENSION IF NOT EXISTS pgcrypto; UPDATE sys_user SET password=crypt('$taskPassword',gen_salt('bf',12)) WHERE user_id=1; UPDATE sys_user SET status='1' WHERE user_id=2;"|Out-Null
    @{username='admin';password=$taskPassword;tenantId='000000';clientId='e5cd7e4891bf95d1d19206ce24a7b32e';entry='http://localhost:5193/login'}|ConvertTo-Json|Set-Content -LiteralPath "$taskRoot/platform-admin.json" -Encoding utf8
    $taskPassword=$null
    $taskState.frameworkReady=$true
    $taskState|ConvertTo-Json|Set-Content -LiteralPath $taskStatePath -Encoding utf8
}
$taskHasHistory=Invoke-DockerSql "SELECT to_regclass('public.flyway_schema_history') IS NOT NULL"
if($taskHasHistory.Trim()-eq'f'){& "$PSScriptRoot/Apply-DockerMigrations.ps1" -Command baseline}
if(!$taskState.initialized){
    function Quote-DockerSql([string]$Value){return "'"+$Value.Replace("'","''")+"'"}
    $taskAccess=Quote-DockerSql $env:MINIO_ROOT_USER;$taskSecret=Quote-DockerSql $env:MINIO_ROOT_PASSWORD
    Invoke-DockerSql "UPDATE sys_oss_config SET endpoint='minio:9000',domain='http://127.0.0.1:29000',access_key=$taskAccess,secret_key=$taskSecret,bucket_name='aisports-docker-fresh',is_https='N',access_policy='0' WHERE config_key='minio';"|Out-Null
    $taskStorageInput=@{bucket='aisports-docker-fresh';accessKey=$env:MINIO_ROOT_USER;secretKey=$env:MINIO_ROOT_PASSWORD}|ConvertTo-Json -Compress
    # A clean checkout can initialize storage before application images exist.
    $taskStorageImage='aisports-dev-ai-gateway:local'
    & $taskDocker image inspect $taskStorageImage --format '{{.Id}}' *> $null
    if($LASTEXITCODE-ne0){$taskStorageImage='node:24-bookworm-slim'}
    $taskStorage=$taskStorageInput|& $taskDocker run --rm -i --name ('aisports-dev-docker-storage-init-'+[guid]::NewGuid().ToString('N')) --network aisports-dev-docker-network --user 1000:1000 --cap-drop ALL --security-opt no-new-privileges:true --read-only -v "${WorkspaceRoot}/scripts/Prepare-DockerStorage.mjs:/task/storage.mjs:ro" $taskStorageImage node /task/storage.mjs 2> "$taskRoot/storage-init-error.log"
    Assert-NativeExit 'Prepare a separate fresh MinIO bucket'
    $taskStorageInput=$null
    $taskStorage|Set-Content -LiteralPath "$taskRoot/storage-init.json" -Encoding utf8
    if(!($taskStorage|ConvertFrom-Json).empty){throw 'Fresh storage initialization unexpectedly contains objects.'}
    $taskState.initialized=$true;$taskState.initializedAt=[DateTimeOffset]::Now.ToString('o');$taskState.bucket='aisports-docker-fresh'
    $taskState|ConvertTo-Json|Set-Content -LiteralPath $taskStatePath -Encoding utf8
}
Write-Host 'Docker framework database and private storage ready. Spring Boot executes pending Flyway business migrations.'
