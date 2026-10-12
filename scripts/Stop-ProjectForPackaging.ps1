#requires -Version 7.0
<# Stop only currently verified project services; preserve all durable files. #>
[CmdletBinding()]param()
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$alias='C:/ProgramData/AISports/desktop-sports-e3000ec'
$link=Get-Item -LiteralPath $alias
if($link.LinkType -ne 'Junction' -or [IO.Path]::GetFullPath($link.Target) -ne [IO.Path]::GetFullPath((Join-Path $WorkspaceRoot '.local'))){throw 'Runtime alias does not resolve to this project'}
$targets=@(
 @{name='main-frontend';port=5190;exe='node.exe';argument="$WorkspaceRoot/plus-ui/node_modules/vite/bin/vite.js"},
 @{name='demo-frontend';port=5192;exe='node.exe';argument="$WorkspaceRoot/.local/demo-20261011/vite-demo.mjs"},
 @{name='lan-frontend';port=5193;exe='node.exe';argument="$WorkspaceRoot/.local/three-person-lan-20261012/"},
 @{name='main-backend';port=8080;exe='java.exe';argument="$WorkspaceRoot/.local/runtime-packages/"},
 @{name='demo-backend';port=8082;exe='java.exe';argument="$WorkspaceRoot/.local/runtime-packages/"},
 @{name='ai-gateway';port=8091;exe='node.exe';argument="$WorkspaceRoot/ai-gateway/server.mjs"},
 @{name='object-storage';port=29000;exe='minio.exe';argument="$WorkspaceRoot/.local/minio-data"},
 @{name='redis';port=26379;exe='redis-server.exe';argument='redis-native.conf'},
 @{name='postgresql';port=25432;exe='postgres.exe';argument="$alias/postgres-data"}
)
function Normalize([string]$Text){$Text.Replace('\','/')}
function Verify($Target){
 $listeners=@(Get-NetTCPConnection -State Listen -LocalPort $Target.port -ErrorAction SilentlyContinue)
 if(-not $listeners.Count){return $null}
 $ids=@($listeners.OwningProcess|Sort-Object -Unique)
 $allowedAddresses=if($Target.name -eq 'lan-frontend'){@('192.168.1.236')}else{@('127.0.0.1','::1')}
 if($ids.Count -ne 1 -or @($listeners|Where-Object LocalAddress -notin $allowedAddresses).Count){throw 'Service ownership or exposure changed'}
 $process=Get-CimInstance Win32_Process -Filter "ProcessId=$($ids[0])"
 if(-not $process -or $process.Name -ne $Target.exe -or (Normalize ([string]$process.CommandLine)).IndexOf((Normalize $Target.argument),[StringComparison]::OrdinalIgnoreCase) -lt 0){throw 'Listener does not belong to this project'}
 if($Target.name -eq 'lan-frontend'){
  $wrapperMatch=[regex]::Match([string]$process.CommandLine,'"([^"\r\n]+vite-lan-trial\.mjs)"$')
  if(-not $wrapperMatch.Success){throw 'LAN frontend wrapper cannot be verified'}
  $wrapper=$wrapperMatch.Groups[1].Value
  if(-not [IO.Path]::GetFullPath($wrapper).StartsWith([IO.Path]::GetFullPath((Join-Path $WorkspaceRoot '.local/three-person-lan-20261012'))+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'LAN frontend wrapper is outside this project'}
  $saved=Get-Content -LiteralPath (Join-Path (Split-Path $wrapper -Parent) 'receipt.json') -Raw|ConvertFrom-Json
  if($saved.frontend.pid -ne $process.ProcessId -or $saved.frontend.wrapper -ne $wrapper -or (Get-FileHash -LiteralPath $wrapper -Algorithm SHA256).Hash.ToLowerInvariant() -ne $saved.frontend.wrapperSha256){throw 'LAN frontend differs from its activation receipt'}
 }
 if($Target.name -in @('redis','postgresql') -and -not (Normalize $process.ExecutablePath).StartsWith($alias+'/toolchains/',[StringComparison]::OrdinalIgnoreCase)){throw 'Dependency executable belongs to another runtime'}
 if($Target.exe -eq 'java.exe'){
  $match=[regex]::Match([string]$process.CommandLine,'-jar\s+(?:"(?<quoted>[^"]+)"|(?<bare>\S+))')
  if(-not $match.Success){throw 'Actual backend package not identified'}
  $file=(Resolve-Path -LiteralPath $(if($match.Groups['quoted'].Success){$match.Groups['quoted'].Value}else{$match.Groups['bare'].Value})).Path
  $hash=(Get-FileHash -LiteralPath $file).Hash.ToLowerInvariant()
  if(-not (Normalize $file).StartsWith((Normalize $Target.argument),[StringComparison]::OrdinalIgnoreCase) -or (Split-Path (Split-Path $file -Parent) -Leaf) -ne $hash){throw 'Backend immutable package ownership differs'}
 }
 return @{pid=[int]$process.ProcessId;created=$process.CreationDate;name=$Target.name;port=$Target.port}
}
# Verify all live targets before any stop, and revalidate each just before use.
$planned=@{}
foreach($target in $targets){$owner=Verify $target;if($owner){$planned[$target.name]=$owner}}
$allPorts=@($targets.port)+29001
$before=@(Get-NetTCPConnection -State Listen|Where-Object LocalPort -in $allPorts|Select-Object LocalAddress,LocalPort,OwningProcess)
$receipt=@{at=[DateTimeOffset]::Now.ToString('o');passed=$false;scope='Project-local service shutdown for user packaging; no files/data deleted or archive created';before=$before;stopped=@();alreadyStopped=@();childProcessesStopped=@();redisGraceful=$false;postgresGraceful=$false;filesDeleted=0}
$out=Join-Path $WorkspaceRoot ('.local/shutdown-'+(Get-Date -Format yyyyMMdd)+'-'+[guid]::NewGuid().ToString('N')+'.json')
try{
 foreach($target in $targets){
  $owner=Verify $target
  if(-not $owner){$receipt.alreadyStopped+=@{name=$target.name;port=$target.port};continue}
  if(-not $planned.ContainsKey($target.name) -or $owner.pid -ne $planned[$target.name].pid -or $owner.created -ne $planned[$target.name].created){throw 'Service changed during shutdown; no unverified process stopped'}
  # Stop only esbuild children owned by the verified frontend, not shared Node shells.
  if($target.name -in @('main-frontend','demo-frontend','lan-frontend')){
   foreach($child in @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($owner.pid)")){
    if($child.Name -eq 'esbuild.exe' -and (Normalize $child.ExecutablePath).StartsWith((Normalize "$WorkspaceRoot/plus-ui/node_modules/"),[StringComparison]::OrdinalIgnoreCase)){
     Stop-Process -Id $child.ProcessId;$receipt.childProcessesStopped+=@{name='owned-esbuild';pid=$child.ProcessId}
    }
   }
  }
  if($target.name -eq 'redis'){
   $priorAuth=[Environment]::GetEnvironmentVariable('REDISCLI_AUTH','Process');$env:REDISCLI_AUTH=$env:REDIS_PASSWORD
   try{& "$alias/toolchains/redis-7.4.11/Redis-7.4.11-Windows-x64-msys2/redis-cli.exe" -h 127.0.0.1 -p $target.port --no-auth-warning shutdown save *> $null;if($LASTEXITCODE -ne 0){throw 'Redis graceful shutdown failed'}}finally{[Environment]::SetEnvironmentVariable('REDISCLI_AUTH',$priorAuth,'Process')}
   $receipt.redisGraceful=$true
  }elseif($target.name -eq 'postgresql'){
   & "$alias/toolchains/postgresql-17.11/pgsql/bin/pg_ctl.exe" -D "$alias/postgres-data" -m fast -w -t 30 stop *> $null
   if($LASTEXITCODE -ne 0){throw 'PostgreSQL checkpoint shutdown failed'}
   $receipt.postgresGraceful=$true
  }else{Stop-Process -Id $owner.pid}
  $receipt.stopped+=@{name=$target.name;pid=$owner.pid;port=$target.port}
 }
 for($attempt=0;$attempt -lt 40;$attempt++){
  $remaining=@(Get-NetTCPConnection -State Listen|Where-Object LocalPort -in $allPorts)
  $living=@($receipt.stopped+$receipt.childProcessesStopped|Where-Object {Get-Process -Id $_.pid -ErrorAction SilentlyContinue})
  if(-not $remaining.Count -and -not $living.Count){break};Start-Sleep -Milliseconds 250
 }
 $receipt.remainingListeners=@($remaining|Select-Object LocalAddress,LocalPort,OwningProcess);$receipt.remainingOwnedProcesses=@($living)
 if($remaining.Count -or $living.Count){throw 'A targeted service or listener is still running'}
 $receipt.passed=$true
 Write-Host ('PASS '+$receipt.stopped.Count+' project services stopped; all '+$allPorts.Count+' ports released; persistent files retained')
}catch{$receipt.failure='Project shutdown incomplete; inspect sanitized receipt, do not stop unrelated processes';throw 'Project shutdown incomplete; prior evidence retained'}
finally{
 $receipt.finishedAt=[DateTimeOffset]::Now.ToString('o');$bytes=[Text.UTF8Encoding]::new($false).GetBytes(($receipt|ConvertTo-Json -Depth 12));$stream=[IO.File]::Open($out,[IO.FileMode]::CreateNew);try{$stream.Write($bytes);$stream.Flush($true)}finally{$stream.Dispose()};Write-Host ('Receipt '+$out)
}
