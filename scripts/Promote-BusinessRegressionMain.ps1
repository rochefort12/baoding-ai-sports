#requires -Version 7.0
<# Promote an already tested immutable local package, preserving prior channels and business data. #>
[CmdletBinding()]param([Parameter(Mandatory)][string]$BindingPath)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
if($env:POSTGRES_DB -ne 'aisports'){throw 'Main database identity changed'}
$bindingFile=(Resolve-Path -LiteralPath $BindingPath).Path
if(-not $bindingFile.StartsWith($WorkspaceRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Binding escaped workspace'}
$binding=Get-Content -LiteralPath $bindingFile -Raw | ConvertFrom-Json
if(-not $binding.passed -or $binding.backendJarSha256 -notmatch '^[a-f0-9]{64}$'){throw 'Successful candidate binding required'}
if(@($binding.sourceFiles).Count -lt 5 -or @($binding.requiredEvidence).Count -lt 5){throw 'Source and actual candidate evidence are required'}
foreach($required in @('canonical-proof','canonical-results','canonical-closure','canonical-team-closure','received-link')){if(@($binding.requiredEvidence | Where-Object {$_.gate -eq $required}).Count -ne 1){throw 'A required candidate business gate is missing'}}
foreach($gate in $binding.requiredEvidence){
 $file=Join-Path $WorkspaceRoot $gate.path
 if((Get-FileHash -LiteralPath $file).Hash.ToLowerInvariant() -ne $gate.sha256){throw 'Candidate evidence changed'}
 if(-not (Get-Content -LiteralPath $file -Raw | ConvertFrom-Json).passed){throw 'Candidate gate did not pass'}
}
foreach($source in $binding.sourceFiles){if((Get-FileHash -LiteralPath (Join-Path $WorkspaceRoot $source.path)).Hash.ToLowerInvariant() -ne $source.sha256){throw 'Verified source changed'}}
$sourceJar=(Resolve-Path -LiteralPath (Join-Path $WorkspaceRoot $binding.backendJarPath)).Path
if(-not $sourceJar.StartsWith($WorkspaceRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or (Get-FileHash -LiteralPath $sourceJar).Hash.ToLowerInvariant() -ne $binding.backendJarSha256){throw 'Tested package changed'}
$taskPid=[int](Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.local/backend.pid') -Raw).Trim()
$taskProcess=Get-CimInstance Win32_Process -Filter "ProcessId=$taskPid"
$oldJarMatch=[regex]::Match([string]$taskProcess.CommandLine,'-jar\s+(?:"(?<quoted>[^"]+)"|(?<bare>\S+))')
if(-not $taskProcess -or $taskProcess.Name -notmatch '^java(w)?\.exe$' -or -not $oldJarMatch.Success){throw 'Main process ownership changed'}
$oldJar=(Resolve-Path -LiteralPath $(if($oldJarMatch.Groups['quoted'].Success){$oldJarMatch.Groups['quoted'].Value}else{$oldJarMatch.Groups['bare'].Value})).Path
$packageRoot=[IO.Path]::GetFullPath((Join-Path $WorkspaceRoot '.local/runtime-packages'))+[IO.Path]::DirectorySeparatorChar
if(-not $oldJar.StartsWith($packageRoot,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($oldJar) -ne 'ruoyi-admin.jar' -or (Get-FileHash -LiteralPath $oldJar).Hash.ToLowerInvariant() -ne (Split-Path (Split-Path $oldJar -Parent) -Leaf)){throw 'Original runtime package ownership changed'}
$listeners=@(Get-NetTCPConnection -State Listen -LocalPort 8080)
if(-not $listeners.Count -or @($listeners | Where-Object {$_.OwningProcess -ne $taskPid -or $_.LocalAddress -notin @('127.0.0.1','::1')}).Count){throw 'Main listener ownership changed'}
$out=Join-Path $WorkspaceRoot ('.local/main-access/business-regression-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $out | Out-Null
$secret=ConvertTo-SecureString ([IO.File]::ReadAllText((Join-Path $WorkspaceRoot '.local/main-access/administrator.dpapi')).Trim());$pointer=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
try{$packet=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) | ConvertFrom-Json}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer);$secret.Dispose()}
if($packet.username -ne 'admin' -or $packet.baseUri -ne 'http://127.0.0.1:8080'){throw 'Protected main credential identity changed'}
$headers=@{clientid=$packet.clientId;Authorization=('Bearer '+$packet.token)}
function Main-Api([string]$Route,[string]$Method='GET',$Body=$null){
 $parameters=@{Uri=('http://127.0.0.1:8080'+$Route);Method=$Method;Headers=$headers;TimeoutSec=45}
 if($null -ne $Body){$parameters.ContentType='application/json';$parameters.Body=($Body | ConvertTo-Json -Depth 25 -Compress)}
 try{$reply=Invoke-RestMethod @parameters}catch{throw 'Main request unavailable; private diagnostics omitted'}
 if($reply.code -ne 200){throw ('Main business request rejected: '+$Route)}
 return $reply.data
}
$tables=@('event','event_field','event_payment_config','competition_unit','capacity_pool','capacity_occupation','org_field','entry_field_value','declaration_ack','qualification_review','team','team_member','team_room','team_room_member','registration','registration_member','registration_payment_proof','roster_version','roster_member','fee_policy','fee_obligation','payment','payment_allocation','refund','payment_action','payment_exception','match','match_entry','result_version','result_item','checkin','growth_record','growth_profile','honor','title_equipment','complaint','complaint_message','notification','notification_delivery','file','organization','organization_application','organization_application_version','qualification','staff_grant','governance_grant')
function Business-Facts{
 $sql=($tables | ForEach-Object {"SELECT '$_='||count(*)||':'||md5(COALESCE(string_agg(row_to_json(t)::text,'|' ORDER BY id),'')) FROM asp_$_ t;"}) -join "`n"
 $priorPg=[Environment]::GetEnvironmentVariable('PGPASSWORD','Process');$env:PGPASSWORD=$env:POSTGRES_PASSWORD
 try{$result=('BEGIN READ ONLY;'+"`n"+$sql+"`nROLLBACK;") | & 'C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin/psql.exe' -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d aisports -At -v ON_ERROR_STOP=1 2>$null;if($LASTEXITCODE -ne 0){throw 'Main business fingerprint query failed'};return ($result | Where-Object {$_ -notin @('BEGIN','ROLLBACK')}) -join "`n"}
 finally{[Environment]::SetEnvironmentVariable('PGPASSWORD',$priorPg,'Process')}
}
$receipt=@{at=[DateTimeOffset]::Now.ToString('o');scope='Main loopback tested package replacement; no tournament or monetary business writes';passed=$false;jarSha256=$binding.backendJarSha256;priorJarSha256=(Get-FileHash -LiteralPath $oldJar).Hash.ToLowerInvariant();priorJarPath=$oldJar;rebound=@();businessFactsUnchanged=$false;fingerprintTableCount=$tables.Count}
$started=$false
try{
 $before=Main-Api '/sports/platform/management'
 $before | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $out 'prior-catalog.json')
 $facts=Business-Facts;$facts | Set-Content -LiteralPath (Join-Path $out 'before-facts.txt')
 $dump=Join-Path $out 'before.dump';$priorPg=[Environment]::GetEnvironmentVariable('PGPASSWORD','Process');$env:PGPASSWORD=$env:POSTGRES_PASSWORD
 try{& 'C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin/pg_dump.exe' -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d aisports -Fc -f $dump 2>$null;Assert-NativeExit 'Main pre-promotion backup'}finally{[Environment]::SetEnvironmentVariable('PGPASSWORD',$priorPg,'Process')}
 $receipt.backupSha256=(Get-FileHash -LiteralPath $dump).Hash.ToLowerInvariant()
 Copy-Item -LiteralPath (Join-Path $WorkspaceRoot '.local/backend-default-runtime.log') -Destination (Join-Path $out 'prior-runtime.log')
 Copy-Item -LiteralPath (Join-Path $WorkspaceRoot '.local/backend-default-error.log') -Destination (Join-Path $out 'prior-error.log')
 Stop-Process -Id $taskPid
 for($attempt=0;$attempt -lt 50;$attempt++){$listener=Get-NetTCPConnection -State Listen -LocalPort 8080 -ErrorAction SilentlyContinue;if(-not $listener){break};if($listener.OwningProcess -ne $taskPid){throw 'Main port changed owner'};Start-Sleep -Milliseconds 100}
 if(Get-NetTCPConnection -State Listen -LocalPort 8080 -ErrorAction SilentlyContinue){throw 'Main listener did not release'}
 Copy-Item -LiteralPath $sourceJar -Destination (Join-Path $WorkspaceRoot 'backend/ruoyi-admin/target/ruoyi-admin.jar')
 & "$PSScriptRoot/Start-Backend.ps1" -JavaHome 'D:/dev/jdk17' -Background
 $started=$true
 $ready=$false;for($attempt=0;$attempt -lt 50;$attempt++){try{$after=Main-Api '/sports/platform/management';$ready=$true;break}catch{Start-Sleep -Milliseconds 800}}
 if(-not $ready){throw 'Main startup business session not ready'}
 $allowed=@('registration.create','registration.submit','registration.mine')
 foreach($activation in @($before.activations | Where-Object {$_.enabled})){
  $current=@($after.definitions | Where-Object {$_.definition.code -eq $activation.code})[0]
  if(-not $current){throw 'Previously enabled main definition disappeared'}
  if($activation.source_hash -eq $current.definitionHash){continue}
  if($activation.code -notin $allowed -or $activation.channel -notin @('ui','agent')){throw 'An unverified capability changed during main promotion'}
  if($activation.channel -eq 'agent' -and ($activation.code -ne 'registration.mine' -or $current.definition.mutation -or @($current.definition.writes).Count)){throw 'Agent write activation is prohibited'}
  Main-Api '/sports/platform/management/release' 'POST' @{code=$activation.code;channel=$activation.channel;enabled=$true;definitionHash=$current.definitionHash;evidenceHash=(Get-FileHash -LiteralPath $bindingFile).Hash.ToLowerInvariant()} | Out-Null
  $receipt.rebound+=@{code=$activation.code;channel=$activation.channel;definitionHash=$current.definitionHash}
 }
 $final=Main-Api '/sports/platform/management'
 $beforeKeys=@($before.activations | ForEach-Object {$_.code+'|'+$_.channel} | Sort-Object)
 $finalKeys=@($final.activations | ForEach-Object {$_.code+'|'+$_.channel} | Sort-Object)
 if(($beforeKeys -join "`n") -ne ($finalKeys -join "`n")){throw 'Main activation key set changed'}
 foreach($previous in $before.activations){$now=@($final.activations | Where-Object {$_.code -eq $previous.code -and $_.channel -eq $previous.channel});if($now.Count -ne 1 -or $now[0].enabled -ne $previous.enabled){throw 'Main channel flags changed'};if($previous.code -notin $allowed -and ($now[0] | ConvertTo-Json -Compress) -ne ($previous | ConvertTo-Json -Compress)){throw 'An unrelated activation changed'}}
 $agents=@($final.activations | Where-Object {$_.enabled -and $_.channel -eq 'agent'} | ForEach-Object {$_.code} | Sort-Object)
 if(($agents -join ',') -ne 'event.mine,growth.card,registration.mine,room.query,type.catalog'){throw 'Main read-only Agent boundary changed'}
 foreach($code in $agents){$definition=@($final.definitions | Where-Object {$_.definition.code -eq $code})[0].definition;if(-not $definition.agent -or $definition.mutation -or @($definition.writes).Count){throw 'An enabled main Agent capability writes data'}}
 if((Business-Facts) -ne $facts){throw 'Main tournament business facts changed'}
 $public=Invoke-RestMethod -Uri 'http://127.0.0.1:8080/sports/public/events' -TimeoutSec 20
 if($public.code -ne 200){throw 'Main public event service failed'}
 $receipt.businessFactsUnchanged=$true;$receipt.passed=$true;$receipt.mainPid=[int](Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.local/backend.pid') -Raw).Trim();$receipt.uiEnabled=@($final.activations | Where-Object {$_.enabled -and $_.channel -eq 'ui'}).Count;$receipt.agentEnabled=$agents.Count;$receipt.agentWrites=0
 Write-Host 'PASS tested local main package, prior channel flags and business facts preserved'
}catch{
 $receipt.failure=$_.Exception.Message
 $receipt.state='FAILED_REQUIRES_RECOVERY'
 $receipt.recovery=if($started){'Stop release work and recover only recorded changed targets using preserved prior package/catalog. This is not a successful release.'}else{'Inspect recorded owned process and preserved prior package; no database restoration attempted. This is not a successful release.'}
 throw
}finally{
 $receipt.finishedAt=[DateTimeOffset]::Now.ToString('o');$receipt | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $out 'receipt.json');$packet=$null
 Write-Host ('Evidence '+$out)
}
