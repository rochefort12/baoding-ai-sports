#requires -Version 7.0
<# Local controlled-trial activation. No real business facts, agent channels or network exposure are changed. #>
[CmdletBinding()]
param([switch]$Rollback)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$out=Join-Path $WorkspaceRoot '.local/phase1-implementation'
$manifestPath=Join-Path $out 'verified-ui-capabilities.json'
$evidencePath=Join-Path $WorkspaceRoot 'docs/04-verification/羽毛球一期闭环本机验证-20261010.json'
if(!(Test-Path $manifestPath) -or !(Test-Path $evidencePath)){throw 'Verified release manifest and final evidence are required'}
$manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json
$evidence=Get-Content $evidencePath -Raw|ConvertFrom-Json
if($evidence.failures -ne 0 -or $evidence.scope -ne 'local-controlled-trial'){throw 'Evidence does not authorize this local activation'}
$jar=Join-Path $WorkspaceRoot 'backend/ruoyi-admin/target/ruoyi-admin.jar'
$jarHash=(Get-FileHash $jar).Hash.ToLowerInvariant()
if($jarHash -ne $manifest.jarSha256 -or $jarHash -ne $evidence.jarSha256){throw 'Build differs from the verified release'}
if($manifest.definitions.Count -ne 47 -or ($manifest.definitions.code|Where-Object {$_ -notmatch '^[a-zA-Z]+(\.[a-zA-Z]+)+$'})){throw 'Capability inventory is invalid'}
$dbName=$env:POSTGRES_DB
if($dbName -notmatch '^aisports[_a-z0-9]*$' -or $env:POSTGRES_PORT -ne '25432'){throw 'Only the current native AISports local database is allowed'}
$bin='C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin'
$evidenceHash=(Get-FileHash $evidencePath).Hash.ToLowerInvariant()
$quote={param([string]$value) "'"+$value.Replace("'","''")+"'"}
$statements=[Collections.Generic.List[string]]::new()
$statements.Add('BEGIN; SELECT pg_advisory_xact_lock(621045047);')
$backup=$null;$backupHash=$null
$env:PGPASSWORD=$env:POSTGRES_PASSWORD
try {
 $identity=& "$bin/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $dbName -At -v ON_ERROR_STOP=1 -c 'SELECT current_database()'
 Assert-NativeExit 'Check local database identity'
 if($identity.Trim() -ne $dbName){throw 'Database identity mismatch'}
 $agentCount=& "$bin/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $dbName -At -v ON_ERROR_STOP=1 -c "SELECT count(*) FROM asp_capability_activation WHERE enabled AND channel='agent'"
 Assert-NativeExit 'Check unopened model channel'
 if([int]$agentCount -ne 0){throw 'Model channels are already open; inspect before this local-only release'}
 if(!$Rollback){$backup=Join-Path $out ('pre-capability-release-'+[guid]::NewGuid().ToString('N')+'.dump'); & "$bin/pg_dump.exe" -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $dbName -Fc -f $backup;Assert-NativeExit 'Preserve pre-activation database';$backupHash=(Get-FileHash $backup).Hash.ToLowerInvariant()}
 foreach($entry in $manifest.definitions){
  $code=& $quote $entry.code;$hash=& $quote $entry.definitionHash
  if($entry.definitionHash -notmatch '^[a-f0-9]{64}$'){throw 'Invalid definition fingerprint'}
  $statements.Add("SELECT pg_advisory_xact_lock(hashtextextended('capability:'||$code,0));")
  if(!$Rollback){
   $definition=$entry.definition|ConvertTo-Json -Depth 40 -Compress;$definition=& $quote $definition
   $statements.Add("INSERT INTO asp_capability_version(id,code,revision,definition,source_hash,status,create_by) SELECT (extract(epoch FROM clock_timestamp())*1000000)::bigint+(random()*100000)::bigint,$code,COALESCE((SELECT MAX(revision) FROM asp_capability_version WHERE code=$code),0)+1,$definition`::jsonb||jsonb_build_object('evidenceHash','$evidenceHash'),$hash,'published',0 WHERE NOT EXISTS(SELECT 1 FROM asp_capability_version WHERE code=$code AND source_hash=$hash AND status='published');")
   $statements.Add("INSERT INTO asp_capability_activation(id,code,capability_version_id,channel,enabled,create_by) SELECT (extract(epoch FROM clock_timestamp())*1000000)::bigint+(random()*100000)::bigint,$code,id,'ui',true,0 FROM asp_capability_version WHERE code=$code AND source_hash=$hash AND status='published' ORDER BY revision DESC LIMIT 1 ON CONFLICT(code,channel) DO UPDATE SET capability_version_id=excluded.capability_version_id,enabled=true,version=asp_capability_activation.version+1,update_time=CURRENT_TIMESTAMP,update_by=0;")
  }else{$statements.Add("UPDATE asp_capability_activation a SET enabled=false,version=version+1,update_time=CURRENT_TIMESTAMP,update_by=0 FROM asp_capability_version v WHERE a.capability_version_id=v.id AND a.code=$code AND a.channel='ui' AND v.source_hash=$hash;")}
  $enabled=(!$Rollback).ToString().ToLowerInvariant();$request='local-release:'+([guid]::NewGuid().ToString('N'))
  $record=@{code=$entry.code;channel='ui';enabled=(!$Rollback);definitionHash=$entry.definitionHash;evidenceHash=$evidenceHash;operator='user-authorized-local-implementation';scope='local-controlled-trial'}|ConvertTo-Json -Compress;$record=& $quote $record
  $statements.Add("INSERT INTO asp_action_execution(id,action_code,actor_type,actor_id,channel,request_key,payload_hash,status,result_reference,occurred_at) VALUES((extract(epoch FROM clock_timestamp())*1000000)::bigint+(random()*100000)::bigint,'capability.release','system',0,'system','$request','$evidenceHash','succeeded',$record`::jsonb,CURRENT_TIMESTAMP);")
 }
 $statements.Add('COMMIT;')
 $log=Join-Path $out ('local-capability-release-'+[guid]::NewGuid().ToString('N')+'.log')
 ($statements -join "`n") | & "$bin/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $dbName -v ON_ERROR_STOP=1 *> $log
 Assert-NativeExit 'Commit local capability activation and audit receipts'
 $counts=& "$bin/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $dbName -At -v ON_ERROR_STOP=1 -c "SELECT channel,count(*) FROM asp_capability_activation WHERE enabled GROUP BY channel ORDER BY channel"
 Assert-NativeExit 'Verify activation channels'
 $receipt=@{timestamp=[DateTimeOffset]::Now.ToString('o');scope='local-controlled-trial';rollback=[bool]$Rollback;jarSha256=$jarHash;evidenceSha256=$evidenceHash;definitionCount=$manifest.definitions.Count;enabledChannels=@($counts);backup=if($backup){Split-Path $backup -Leaf}else{$null};backupSha256=$backupHash;log=Split-Path $log -Leaf;actor='system/local operator; not ordinary-role business acceptance'}
 $receipt|ConvertTo-Json -Depth 8|Set-Content (Join-Path $out ('local-capability-release-receipt-'+[guid]::NewGuid().ToString('N')+'.json')) -Encoding utf8
 Write-Host 'Local UI capabilities and audit receipts committed; model/agent channels remain unopened.'
 Write-Host ($counts -join ', ')
}finally{Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue}
