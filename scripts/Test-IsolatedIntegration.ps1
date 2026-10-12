#requires -Version 7.0
<# .SYNOPSIS 身份服务与运营会话真实存储验证；只复制结构，临时库与随机Redis命名空间，不调用短信/模型。 #>
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
Import-LocalEnvironment
$docker=Get-DockerCommand
$sourceDatabase=$env:POSTGRES_DB
$nonce=[guid]::NewGuid().ToString('N')
$database='aisports_verify_identity_'+$nonce
$prefix='aisports:verify:'+ $nonce + ':'
if($database -notmatch '^aisports_verify_identity_[a-f0-9]{32}$' -or $database -eq $sourceDatabase){throw 'Unsafe integration database'}
if($env:APP_DB_USER -notmatch '^[a-zA-Z_][a-zA-Z0-9_]*$'){throw 'Invalid application database role'}
$dump='/tmp/'+$database+'.sql'; $created=$false; $completed=$false; $removed=$false
$out=Join-Path $WorkspaceRoot '.local/isolated-integration'; New-Item -ItemType Directory -Force -Path $out | Out-Null
try {
    & $docker exec aisports-dev-postgres pg_dump -U $env:POSTGRES_USER -d $sourceDatabase --schema-only --no-owner --no-privileges -f $dump
    Assert-NativeExit 'Schema-only export'
    & $docker exec aisports-dev-postgres createdb -U $env:POSTGRES_USER -T template0 $database
    Assert-NativeExit 'Temporary database creation'; $created=$true
    & $docker exec aisports-dev-postgres psql -U $env:POSTGRES_USER -d $database -v ON_ERROR_STOP=1 -q -f $dump *> (Join-Path $out 'schema.log')
    Assert-NativeExit 'Isolated schema restore'
    $grant='GRANT USAGE ON SCHEMA public TO "'+$env:APP_DB_USER+'"; GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO "'+$env:APP_DB_USER+'"; GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA public TO "'+$env:APP_DB_USER+'";'
    $grant | & $docker exec -i aisports-dev-postgres psql -U $env:POSTGRES_USER -d $database -v ON_ERROR_STOP=1 -q
    Assert-NativeExit 'Isolated application permissions'
    $env:POSTGRES_DB=$database
    Push-Location (Join-Path $WorkspaceRoot 'backend')
    try {
        & mvn '-Plocal' '-pl' 'ruoyi-admin' '-am' '-DskipTests=false' '-Dtest.groups=integration-local' '-Dtest=IdentitySliceTest' '-Dsurefire.failIfNoSpecifiedTests=false' ('-Dredisson.keyPrefix='+$prefix) 'test' *> (Join-Path $out 'tests.log')
        Assert-NativeExit 'Isolated Spring service and Redis integration'
        $completed=$true
    } finally {Pop-Location}
} finally {
    $env:POSTGRES_DB=$sourceDatabase
    if($created){
        & $docker exec aisports-dev-postgres dropdb -U $env:POSTGRES_USER --force $database
        Assert-NativeExit 'Temporary database cleanup'; $removed=$true
    }
    & $docker exec aisports-dev-postgres rm -f $dump
    Assert-NativeExit 'Temporary schema dump cleanup'
    # Only this run's exact prefix may be removed. Never flush Redis or touch local application keys.
    $keys=@(& $docker exec aisports-dev-redis redis-cli --scan --pattern ($prefix+'*'))
    Assert-NativeExit 'Isolated Redis cleanup inventory'
    foreach($key in $keys){
        if(!$key.StartsWith($prefix,[StringComparison]::Ordinal)){throw 'Unsafe Redis cleanup key'}
        & $docker exec aisports-dev-redis redis-cli DEL $key | Out-Null
        Assert-NativeExit 'Isolated Redis key cleanup'
    }
    @{scope='Real isolated Spring identity services and OperationsChatStore Redis, not ordinary-role acceptance';completed=$completed;temporaryDatabaseRemoved=$removed;redisPrefixRemoved=$prefix;time=[DateTimeOffset]::Now.ToString('o')} | ConvertTo-Json | Set-Content (Join-Path $out 'results.json') -Encoding utf8
}
Write-Host 'ISOLATED INTEGRATION PASS; temporary database and Redis namespace removed'
