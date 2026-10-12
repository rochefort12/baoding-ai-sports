#requires -Version 7.0
<# Resume checks after the recorded installation, without repeating restart or business writes. #>
[CmdletBinding()]param([Parameter(Mandatory)][string]$FailedReceipt)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
if($env:POSTGRES_DB -ne 'aisports'){throw 'Main database identity changed'}
function LocalFile([string]$Path){
 $file=(Resolve-Path -LiteralPath $Path).Path
 if(-not $file.StartsWith($WorkspaceRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'File escaped workspace'}
 $cursor=$file
 while($cursor -ne $WorkspaceRoot){if((Get-Item -LiteralPath $cursor).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Reparse paths are not permitted'};$cursor=Split-Path $cursor -Parent}
 return $file
}
function Hash([string]$Path){(Get-FileHash -LiteralPath (LocalFile $Path)).Hash.ToLowerInvariant()}
function Json([string]$Path){Get-Content -LiteralPath (LocalFile $Path) -Raw|ConvertFrom-Json}
function Api([string]$Route,[string]$Method='GET',$Body=$null){
 $args=@{Uri=('http://127.0.0.1:8080'+$Route);Headers=$headers;Method=$Method;TimeoutSec=30}
 if($null -ne $Body){$args.ContentType='application/json';$args.Body=$Body|ConvertTo-Json -Compress}
 try{$result=Invoke-RestMethod @args}catch{throw 'Actual main request unavailable; private response omitted'}
 if($result.code -ne 200){throw 'Actual main request rejected; private response omitted'}
 # An empty successful result is still valid data; preserve arrays instead of
 # allowing PowerShell's pipeline to turn [] into a null/no-output value.
 return ,$result.data
}
function CanonicalObject($Value){
 if($null -eq $Value){return $null}
 if($Value -is [pscustomobject]){
  $object=[ordered]@{}
  foreach($name in @($Value.psobject.Properties.Name|Sort-Object)){$object[$name]=CanonicalObject $Value.$name}
  return $object
 }
 if($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]){
  $items=@(foreach($item in $Value){,(CanonicalObject $item)})
  return ,$items
 }
 return $Value
}
function CanonicalDefinitions($Catalog){
 # Only these three fields are Set<String> in CapabilityDefinition.java.
 # Sorting them preserves semantics; all other fields and hashes compare exactly.
 $copy=$Catalog.definitions|ConvertTo-Json -Depth 40|ConvertFrom-Json
 foreach($entry in $copy){foreach($field in @('actorTypes','reads','writes')){$entry.definition.$field=@($entry.definition.$field|Sort-Object)}}
 # JSON object property order also has no semantic meaning (Map.of can reorder
 # between JVMs). Preserve all values and non-set array order while sorting keys.
 (CanonicalObject @($copy|Sort-Object {$_.definition.code})|ConvertTo-Json -Depth 40 -Compress)
}
$failedFile=LocalFile $FailedReceipt;$failed=Json $failedFile;$parent=Split-Path $failedFile -Parent
if($failed.passed -or -not $failed.stoppedOwnedProcess -or -not $failed.startedReplacement -or $failed.failure.stage -ne 'actual main authentication and unchanged catalog'){throw 'Only the recorded installed-package check can resume'}
$binding=Json (Join-Path $parent 'source-binding.json')
if($binding.jarSha256 -ne $failed.jarSha256){throw 'Recorded source binding differs'}
foreach($source in $binding.sources){if((Hash (Join-Path $WorkspaceRoot $source.path)) -ne $source.sha256){throw 'Recorded source changed'}}
foreach($gate in $failed.requiredEvidence){if((Hash (Join-Path $WorkspaceRoot $gate.path)) -ne $gate.sha256 -or -not (Json (Join-Path $WorkspaceRoot $gate.path)).passed){throw 'Recorded acceptance evidence changed'}}
$out=Join-Path $parent ('completion-'+[guid]::NewGuid().ToString('N'));[IO.Directory]::CreateDirectory($out)|Out-Null
$receipt=@{at=[DateTimeOffset]::Now.ToString('o');passed=$false;scope='Complete existing main installation checks; no repeated restart, capability release or tournament write';priorFailedReceipt=[IO.Path]::GetRelativePath($WorkspaceRoot,$failedFile).Replace('\','/');priorFailedReceiptSha256=(Hash $failedFile);checks=@();jarSha256=$failed.jarSha256;restartRepeated=$false;capabilityMutations=0;fingerprintTableCount=46}
function Check([string]$Name,[bool]$Condition){$receipt.checks+=@{name=$Name;passed=$Condition};if(-not $Condition){throw 'Main completion check failed'}}
$packet=$null;$headers=$null
try{
 $mainId=[int]([IO.File]::ReadAllText((LocalFile '.local/backend.pid')).Trim())
 $process=Get-CimInstance Win32_Process -Filter "ProcessId=$mainId"
 $jar=LocalFile ('.local/runtime-packages/'+$failed.jarSha256+'/ruoyi-admin.jar')
 $listeners=@(Get-NetTCPConnection -State Listen -LocalPort 8080)
 Check 'actual new immutable package owns main loopback' ($process.Name -match '^java(w)?\.exe$' -and $process.CommandLine.Contains($jar) -and (Hash $jar) -eq $failed.jarSha256 -and $listeners.Count -gt 0 -and @($listeners|Where-Object {$_.OwningProcess -ne $mainId -or $_.LocalAddress -notin @('127.0.0.1','::1')}).Count -eq 0)
 $dump=LocalFile (Join-Path $parent 'before.dump')
 Check 'original main pre-install backup bytes retained' ((Hash $dump) -eq $failed.backupSha256)
 & 'C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin/pg_restore.exe' --list $dump *> (Join-Path $out 'backup-directory.log')
 Check 'backup archive directory can be read' ($LASTEXITCODE -eq 0)
 $s=ConvertTo-SecureString ([IO.File]::ReadAllText((LocalFile '.local/main-access/administrator.dpapi')).Trim());$pointer=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
 try{$packet=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)|ConvertFrom-Json}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer);$s.Dispose()}
 Check 'protected original credential still belongs to main administrator' ($packet.username -eq 'admin' -and $packet.baseUri -eq 'http://127.0.0.1:8080')
 $headers=@{clientid=$packet.clientId}
 $login=Api '/auth/login' 'POST' @{username='admin';password=$packet.password;clientId=$packet.clientId;grantType='work-password'}
 Check 'actual main work-password login returns a session without tenant input' ([bool]$login.access_token)
 $headers.Authorization='Bearer '+$login.access_token
 $identity=Api '/system/user/getInfo'
 Check 'actual main administrator resolves its original organization' ([string]$identity.user.userId -eq '1' -and $identity.user.tenantId -eq '000000')
 $before=Json (Join-Path $parent 'prior-catalog.json');$after=Api '/sports/platform/management'
 Check 'all activation records and flags are exactly unchanged' ((@($before.activations|Sort-Object code,channel)|ConvertTo-Json -Depth 40 -Compress) -eq (@($after.activations|Sort-Object code,channel)|ConvertTo-Json -Depth 40 -Compress))
 Check 'all definition content and hashes match after sorting only declared set fields' ((CanonicalDefinitions $before) -eq (CanonicalDefinitions $after))
 $after|ConvertTo-Json -Depth 40|Set-Content -LiteralPath (Join-Path $out 'after-catalog.json')
 $agents=@($after.activations|Where-Object {$_.enabled -and $_.channel -eq 'agent'})
 Check 'existing enabled Agent capabilities remain read-only' (@($agents|Where-Object {$code=$_.code;$d=@($after.definitions|Where-Object {$_.definition.code -eq $code})[0].definition;$d.mutation -or @($d.writes).Count -gt 0}).Count -eq 0)
 $beforeFacts=[IO.File]::ReadAllText((LocalFile (Join-Path $parent 'before-facts.txt')))
 $tables=@($beforeFacts -split "`n"|ForEach-Object {if($_ -match '^([a-z_]+)=\d+:[a-f0-9]{32}$'){$Matches[1]}else{throw 'Invalid original table fingerprint'}})
 Check 'original fingerprint covers all 46 declared tables' ($tables.Count -eq 46 -and @($tables|Sort-Object -Unique).Count -eq 46)
 $sql=($tables|ForEach-Object {"SELECT '$_='||count(*)||':'||md5(COALESCE(string_agg(row_to_json(t)::text,'|' ORDER BY id),'')) FROM asp_$_ t;"}) -join "`n"
 $oldPg=[Environment]::GetEnvironmentVariable('PGPASSWORD','Process');$env:PGPASSWORD=$env:POSTGRES_PASSWORD
 try{$facts=('BEGIN READ ONLY;'+"`n"+$sql+"`nROLLBACK;")|& 'C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin/psql.exe' -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d aisports -At -v ON_ERROR_STOP=1 2>$null;if($LASTEXITCODE -ne 0){throw 'Main fingerprint read failed'}}finally{[Environment]::SetEnvironmentVariable('PGPASSWORD',$oldPg,'Process')}
 $afterFacts=($facts|Where-Object {$_ -notin @('BEGIN','ROLLBACK')}) -join "`n"
 Check 'all 46 full business row fingerprints are unchanged from before installation' ($afterFacts -eq $beforeFacts)
 [IO.File]::WriteAllText((Join-Path $out 'after-facts.txt'),$afterFacts,[Text.UTF8Encoding]::new($false))
 $events=Api '/sports/public/events';$methods=Api '/auth/work-methods'
 Check 'public events read and actual WeChat-unavailable metadata succeed' ($null -ne $events -and $methods.wechat.available -eq $false)
 foreach($source in $binding.sources){if((Hash (Join-Path $WorkspaceRoot $source.path)) -ne $source.sha256){throw 'Source changed during completion'}}
 $receipt.passed=$true;$receipt.mainPid=$mainId;$receipt.mainJarPath=$jar;$receipt.mainJarSha256=$failed.jarSha256;$receipt.businessFactsUnchanged=$true;$receipt.catalogUnchanged=$true;$receipt.backupSha256=$failed.backupSha256;$receipt.sourceBindingSha256=Hash (Join-Path $parent 'source-binding.json');$receipt.uiEnabled=@($after.activations|Where-Object {$_.enabled -and $_.channel -eq 'ui'}).Count;$receipt.agentEnabled=$agents.Count;$receipt.agentWrites=0;$receipt.wechatAvailable=$false;$receipt.setOrderCorrection='Only declared Set<String> actorTypes, reads and writes were sorted; full remaining content, each definitionHash and every activation row still compare exactly'
}catch{$receipt.failure='Current completion check failed; private diagnostics omitted';throw 'Work-login completion failed; prior journal preserved'}
finally{
 $packet=$null;$headers=$null;$login=$null;$receipt.finishedAt=[DateTimeOffset]::Now.ToString('o');$file=Join-Path $out 'receipt.json';$bytes=[Text.UTF8Encoding]::new($false).GetBytes(($receipt|ConvertTo-Json -Depth 15));$stream=[IO.File]::Open($file,[IO.FileMode]::CreateNew);try{$stream.Write($bytes);$stream.Flush($true)}finally{$stream.Dispose()};Write-Host ('Evidence '+$out)
}
Write-Host 'PASS current main login package, unchanged capability content and 46 business facts; prior failures retained'
