#requires -Version 7.0
[CmdletBinding()]
param()
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment

# Resume the existing synthetic trial without seeds, migrations or main-site writes.
$alias = 'C:/ProgramData/AISports/desktop-sports-e3000ec'
$localRoot = Join-Path $WorkspaceRoot '.local'
$aliasItem = Get-Item -LiteralPath $alias
if ($aliasItem.LinkType -ne 'Junction' -or [IO.Path]::GetFullPath($aliasItem.Target) -ne [IO.Path]::GetFullPath($localRoot)) {
    throw 'The native runtime alias belongs to another workspace.'
}
if ($env:POSTGRES_PORT -ne '25432' -or $env:REDIS_PORT -ne '26379' -or $env:MINIO_API_PORT -ne '29000' -or $env:MINIO_CONSOLE_PORT -ne '29001') {
    throw 'Expected the existing project-local service ports.'
}
$runtimePath = Join-Path $localRoot 'phase1-implementation/verification-runtime.json'
$runtime = Get-Content -LiteralPath $runtimePath -Raw | ConvertFrom-Json
if ($runtime.database -notmatch '^aisports_verify_phase1_[a-f0-9]{32}$' -or $runtime.port -ne 8082) {
    throw 'The existing isolated trial identity is required.'
}
$out = Join-Path $localRoot ('local-trial-' + (Get-Date -Format yyyyMMdd) + '/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $out -Force | Out-Null
$receipt = @{ startedAt = [DateTimeOffset]::Now.ToString('o'); database = $runtime.database; scope = 'Resume existing local synthetic trial; no seeds, migration, new role or main-site startup'; passed = $false; services = @() }

function Test-OwnedListener([int]$Port, [string]$ExpectedCommand, [string]$ExpectedExecutable) {
    $listeners = @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
    if (-not $listeners.Count) { return $false }
    foreach ($listener in $listeners) {
        $owner = Get-CimInstance Win32_Process -Filter "ProcessId=$($listener.OwningProcess)"
        if (-not $owner -or -not $owner.CommandLine -or $owner.CommandLine.Replace('\', '/').IndexOf($ExpectedCommand.Replace('\', '/'), [StringComparison]::OrdinalIgnoreCase) -lt 0 -or [IO.Path]::GetFileName($owner.ExecutablePath) -ne $ExpectedExecutable) {
            throw "Port $Port belongs to an unverified process."
        }
    }
    return $true
}
function Save-PreviousLog([string]$Path) {
    if (Test-Path -LiteralPath $Path) { Copy-Item -LiteralPath $Path -Destination (Join-Path $out ([IO.Path]::GetFileName($Path) + '.previous')) }
}
function Wait-TrialHttp([string]$Url) {
    for ($attempt = 0; $attempt -lt 90; $attempt++) {
        try { $response = Invoke-WebRequest -Uri $Url -TimeoutSec 2; if ($response.StatusCode -eq 200) { return } } catch {}
        Start-Sleep -Milliseconds 700
    }
    throw 'A local trial HTTP endpoint did not become ready; inspect protected local logs.'
}

try {
    $pgBin = Join-Path $alias 'toolchains/postgresql-17.11/pgsql/bin'
    $pgData = Join-Path $alias 'postgres-data'
    $redisBin = Join-Path $alias 'toolchains/redis-7.4.11/Redis-7.4.11-Windows-x64-msys2'
    foreach ($required in @("$pgData/PG_VERSION", "$alias/redis-native.conf", "$WorkspaceRoot/plus-ui/node_modules/vite/dist/node/index.js")) {
        if (-not (Test-Path -LiteralPath $required)) { throw 'An existing trial runtime file is missing; initialization is not permitted here.' }
    }
    if (-not (Test-OwnedListener 25432 $pgData 'postgres.exe')) {
        $pg = Start-Process -FilePath "$pgBin/pg_ctl.exe" -ArgumentList @('-D', "`"$pgData`"", '-l', "`"$out/postgres-runtime.log`"", '-w', '-t', '30', 'start') -WindowStyle Hidden -RedirectStandardOutput "$out/postgres-start.log" -RedirectStandardError "$out/postgres-start-error.log" -PassThru
        if (-not $pg.WaitForExit(35000) -or $pg.ExitCode -ne 0) { throw 'Project PostgreSQL startup failed.' }
    }
    $env:PGPASSWORD = $env:POSTGRES_PASSWORD
    $dbCheck = & "$pgBin/psql.exe" -X -h 127.0.0.1 -p 25432 -U $env:POSTGRES_USER -d $runtime.database -Atc 'SELECT 1;' 2>$null
    if ($LASTEXITCODE -ne 0 -or $dbCheck -ne '1') { throw 'The existing isolated trial database is unavailable.' }
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    if (-not (Test-OwnedListener 26379 'redis-native.conf' 'redis-server.exe')) {
        $redis = Start-Process -FilePath "$redisBin/redis-server.exe" -ArgumentList 'redis-native.conf' -WorkingDirectory $alias -WindowStyle Hidden -RedirectStandardOutput "$out/redis-runtime.log" -RedirectStandardError "$out/redis-error.log" -PassThru
        $redis.Id | Set-Content -LiteralPath "$localRoot/redis.pid"
    }
    $env:REDISCLI_AUTH = $env:REDIS_PASSWORD
    $redisReady = $false
    for ($attempt = 0; $attempt -lt 25; $attempt++) {
        $pong = & "$redisBin/redis-cli.exe" -h 127.0.0.1 -p 26379 ping 2>$null
        if ($pong -eq 'PONG') { $redisReady = $true; break }
        Start-Sleep -Milliseconds 300
    }
    Remove-Item Env:REDISCLI_AUTH -ErrorAction SilentlyContinue
    if (-not $redisReady) { throw 'Project Redis authentication failed.' }
    $minioData = Join-Path $localRoot 'minio-data'
    if (-not (Test-OwnedListener 29000 $minioData 'minio.exe')) {
        if (Get-NetTCPConnection -State Listen -LocalPort 29001 -ErrorAction SilentlyContinue) { throw 'The storage console port is occupied.' }
        $minio = Start-Process -FilePath 'D:/RetailOS AI 零售全域经营平台/.runtime/toolchains/minio/minio.exe' -ArgumentList @('server', "`"$minioData`"", '--address', '127.0.0.1:29000', '--console-address', '127.0.0.1:29001', '--quiet') -WorkingDirectory $localRoot -WindowStyle Hidden -RedirectStandardOutput "$out/minio-runtime.log" -RedirectStandardError "$out/minio-error.log" -PassThru
        $minio.Id | Set-Content -LiteralPath "$localRoot/minio.pid"
    }
    Wait-TrialHttp 'http://127.0.0.1:29000/minio/health/live'
    if (-not (Test-OwnedListener 8091 "$WorkspaceRoot/ai-gateway/server.mjs" 'node.exe')) {
        Save-PreviousLog "$localRoot/ai-gateway.log"
        Save-PreviousLog "$localRoot/ai-gateway-error.log"
        & "$PSScriptRoot/Start-AiGateway.ps1" -Background
    }
    $expectedTrialJar = if ($runtime.jarPath) { $runtime.jarPath } else { "$WorkspaceRoot/backend/ruoyi-admin/target/ruoyi-admin.jar" }
    if (-not (Test-OwnedListener 8082 $expectedTrialJar 'java.exe')) {
        Save-PreviousLog "$localRoot/phase1-implementation/http-test-runtime.log"
        Save-PreviousLog "$localRoot/phase1-implementation/http-test-error.log"
        & "$PSScriptRoot/Restart-Phase1Verification.ps1"
    }
    Wait-TrialHttp 'http://127.0.0.1:8082/auth/code'
    Save-PreviousLog "$localRoot/demo-20261011/frontend.out.log"
    Save-PreviousLog "$localRoot/demo-20261011/frontend.err.log"
    & "$PSScriptRoot/Start-DemoFrontend.ps1"
    Wait-TrialHttp 'http://127.0.0.1:5192/portal/login'
    $receipt.jarSHA256 = (Get-FileHash -LiteralPath $expectedTrialJar).Hash.ToLowerInvariant()
    if ($runtime.jarSHA256 -and $receipt.jarSHA256 -ne $runtime.jarSHA256) { throw 'The isolated runtime package hash changed.' }
    $receipt.services = @(Get-NetTCPConnection -State Listen | Where-Object LocalPort -in @(25432, 26379, 29000, 29001, 8091, 8082, 5192) | Select-Object LocalAddress, LocalPort, OwningProcess)
    $receipt.passed = $true
    Write-Output 'Existing local trial is ready at http://127.0.0.1:5192/portal/login; authentication still needs verification.'
} catch {
    $receipt.failure = 'Startup failed; inspect protected local logs. No initialization or cleanup was performed.'
    throw
} finally {
    Remove-Item Env:PGPASSWORD, Env:REDISCLI_AUTH -ErrorAction SilentlyContinue
    $receipt.finishedAt = [DateTimeOffset]::Now.ToString('o')
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($receipt | ConvertTo-Json -Depth 6))
    $stream = [IO.File]::Open((Join-Path $out 'startup.json'), [IO.FileMode]::CreateNew)
    try { $stream.Write($bytes); $stream.Flush($true) } finally { $stream.Dispose() }
    Write-Output ('Startup receipt: ' + (Join-Path $out 'startup.json'))
}
