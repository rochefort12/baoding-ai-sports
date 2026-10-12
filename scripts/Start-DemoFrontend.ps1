#requires -Version 7.0
param([int]$Port = 5192)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Common.ps1"
$demoRoot = Join-Path $WorkspaceRoot '.local/demo-20261011'
New-Item -ItemType Directory -Path $demoRoot -Force | Out-Null
$runtime = Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.local/phase1-implementation/verification-runtime.json') -Raw | ConvertFrom-Json
if ($runtime.database -notmatch '^aisports_verify_phase1_[a-f0-9]{32}$' -or $runtime.port -ne 8082) { throw 'Expected isolated verification service.' }
if (!(Get-NetTCPConnection -State Listen -LocalPort 8082 -ErrorAction SilentlyContinue)) { throw 'Restart the existing isolated verification service first; do not initialize new data.' }
$receiptPath = Join-Path $demoRoot 'frontend-runtime.json'
$listener = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
if ($listener) {
    if (Test-Path -LiteralPath $receiptPath) {
        $saved = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
        $processInfo = Get-CimInstance Win32_Process -Filter "ProcessId=$($saved.pid)"
        if ($listener.OwningProcess -eq $saved.pid -and $processInfo.CommandLine.Contains($saved.wrapper)) { Write-Output "Demo frontend already running at http://127.0.0.1:$Port"; return }
    }
    throw 'Demo port belongs to an unverified process.'
}
$wrapperPath = Join-Path $demoRoot 'vite-demo.mjs'
$uiRoot = Join-Path $WorkspaceRoot 'plus-ui'
$viteEntry = ([Uri](Join-Path $uiRoot 'node_modules/vite/dist/node/index.js')).AbsoluteUri
$configPath = (Join-Path $uiRoot 'vite.config.ts').Replace('\','/')
$cachePath = (Join-Path $demoRoot 'vite-cache').Replace('\','/')
$wrapper = @"
import {createServer} from '$viteEntry';
const server = await createServer({configFile:'$configPath',cacheDir:'$cachePath',server:{host:'127.0.0.1',port:$Port,strictPort:true,open:false,proxy:{'/dev-api':{target:'http://127.0.0.1:8082',changeOrigin:true,ws:true,rewrite:path=>path.replace(/^\/dev-api/,'')}}}});
await server.listen();
console.log('Isolated demo frontend ready; synthetic business data only.');
"@
[IO.File]::WriteAllText($wrapperPath,$wrapper,[Text.UTF8Encoding]::new($false))
$nodePath = 'D:/dev/nodejs/node.exe'
if (!(Test-Path -LiteralPath $nodePath)) { throw 'Expected local Node runtime is unavailable.' }
$process = Start-Process -FilePath $nodePath -ArgumentList @('"'+$wrapperPath+'"') -WorkingDirectory $uiRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $demoRoot 'frontend.out.log') -RedirectStandardError (Join-Path $demoRoot 'frontend.err.log')
[pscustomobject]@{pid=$process.Id;port=$Port;wrapper=$wrapperPath;backendPort=8082;createdAt=[DateTimeOffset]::Now.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding utf8
Write-Output "Demo frontend starting at http://127.0.0.1:$Port; isolated backend 8082."
