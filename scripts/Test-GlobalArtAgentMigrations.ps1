#requires -Version 7.0
<# Snapshot both owned stores, restore a new copy, test/replay before activation. #>
[CmdletBinding()]param([switch]$Apply,[string[]]$MigrationVersions=@('V035','V036'))
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
if($env:POSTGRES_DB -ne 'aisports' -or $env:POSTGRES_PORT -ne '25432'){throw 'Expected native AISports main database.'}
$runtime=Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.local/phase1-implementation/verification-runtime.json') -Raw|ConvertFrom-Json
if($runtime.database -notmatch '^aisports_verify_phase1_[a-f0-9]{32}$' -or $runtime.port-ne 8082){throw 'Existing isolated database identity required.'}
$client='C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin'
$run=[guid]::NewGuid().ToString('N');$out=Join-Path $WorkspaceRoot ('.local/product-release-20261011/global-migration-'+$run)
New-Item -ItemType Directory -Path $out|Out-Null
$migrations=$MigrationVersions;if(@($migrations|Where-Object {$_ -notmatch '^V0(35|36|37|38)$'}).Count){throw 'Only the current exact product migrations may be requested.'};$bindings=@();foreach($version in $migrations){$file=Get-ChildItem -LiteralPath "$WorkspaceRoot/database/migrations" -Filter ($version+'__*.sql');if(@($file).Count-ne 1){throw 'Migration version ambiguity.'};$bindings+=@{version=$version;file=$file.Name;sha256=(Get-FileHash -LiteralPath $file.FullName).Hash.ToLowerInvariant()}}
$receipt=@{startedAt=[DateTimeOffset]::Now.ToString('o');scope='Owned PostgreSQL snapshots, actual restore, forward and replay; not tournament acceptance';migrations=$bindings;backups=@();checks=@();applied=@();passed=$false}
$copy='aisports_global_restore_'+$run;$created=$false
function Query([string]$db,[string]$sql){$env:PGPASSWORD=$env:POSTGRES_PASSWORD;$result=& "$client/psql.exe" -X -h 127.0.0.1 -p 25432 -U $env:POSTGRES_USER -d $db -At -v ON_ERROR_STOP=1 -c $sql;Assert-NativeExit 'Bounded migration verification';return ($result-join "`n").Trim()}
$factsSql=@'
SELECT json_build_object(
 'events',(SELECT md5(COALESCE(string_agg(row_to_json(t)::text,'' ORDER BY id),'')) FROM asp_event t),
 'registrations',(SELECT md5(COALESCE(string_agg(row_to_json(t)::text,'' ORDER BY id),'')) FROM asp_registration t),
 'obligations',(SELECT md5(COALESCE(string_agg(row_to_json(t)::text,'' ORDER BY id),'')) FROM asp_fee_obligation t),
 'growthFacts',(SELECT md5(COALESCE(string_agg(row_to_json(t)::text,'' ORDER BY id),'')) FROM asp_growth_record t),
 'honors',(SELECT md5(COALESCE(string_agg((to_jsonb(t)-ARRAY['applicant_account_id','certification_status','certification_details','verified_snapshot','certification_history','certification_public','certification_worn'])::text,'' ORDER BY id),'')) FROM asp_honor t),
 'titles',(SELECT md5(COALESCE(string_agg(row_to_json(t)::text,'' ORDER BY id),'')) FROM asp_title_equipment t),
 'results',(SELECT md5(COALESCE(string_agg(row_to_json(t)::text,'' ORDER BY id),'')) FROM asp_result_version t))::text
'@
function CheckNew([string]$db){
 $ranks=Query $db "SELECT rules->'rankNames' FROM asp_growth_policy WHERE code='participation' AND status='active' ORDER BY id;"
 if($ranks-notmatch '星耀' -or $ranks-notmatch '王者'){throw 'New rank identity is missing.'}
 if($migrations -contains 'V037' -and ($ranks-notmatch '传奇')){throw 'Legend participation rule missing.'}
 if($migrations -contains 'V038'){
  $honorColumns=Query $db "SELECT count(*) FROM information_schema.columns WHERE table_name='asp_honor' AND column_name IN ('applicant_account_id','certification_status','certification_details','verified_snapshot','certification_history','certification_public','certification_worn');"
  if($honorColumns-ne '7'){throw 'Certification schema incomplete.'}
 }
 $playbooks=Query $db "SELECT count(*) FROM asp_agent_version WHERE revision=2 AND jsonb_array_length(tool_catalog->'entries')=11 AND jsonb_array_length(skill_catalog->'entries')=6 AND jsonb_array_length(business_map->'flows')=5;"
 if($playbooks.Trim()-ne '8'){throw 'Expected eight retained/versioned playbook definitions.'}
 $ledger=Query $db "SELECT version||':'||checksum FROM aisports_schema_history WHERE version IN ('V035','V036','V037','V038') ORDER BY version;"
 foreach($binding in $bindings){if($ledger-notmatch ([regex]::Escape($binding.version+':'+$binding.sha256))){throw 'Migration ledger checksum differs.'}}
 return @{ranks=$ranks;playbookVersions=[int]$playbooks;ledger=$ledger}
}
try{
 $mainBefore=Query 'aisports' $factsSql
 foreach($db in @('aisports',$runtime.database)){
  $dump=Join-Path $out ($db+'.dump');$env:PGPASSWORD=$env:POSTGRES_PASSWORD
  & "$client/pg_dump.exe" -h 127.0.0.1 -p 25432 -U $env:POSTGRES_USER -Fc -d $db -f $dump;Assert-NativeExit 'Project database snapshot'
  & "$client/pg_restore.exe" --list $dump *> (Join-Path $out ($db+'-archive-list.log'));Assert-NativeExit 'Snapshot archive structure'
  $receipt.backups+=@{database=$db;path=[IO.Path]::GetRelativePath($WorkspaceRoot,$dump).Replace('\','/');sha256=(Get-FileHash -LiteralPath $dump).Hash.ToLowerInvariant();bytes=(Get-Item -LiteralPath $dump).Length}
 }
 & "$client/createdb.exe" -h 127.0.0.1 -p 25432 -U $env:POSTGRES_USER -T template0 $copy;Assert-NativeExit 'Create owned restore copy';$created=$true
 & "$client/pg_restore.exe" -h 127.0.0.1 -p 25432 -U $env:POSTGRES_USER -d $copy --exit-on-error (Join-Path $out 'aisports.dump') *> (Join-Path $out 'restore.log');Assert-NativeExit 'Restore exact current snapshot'
 if((Query $copy $factsSql)-ne $mainBefore){throw 'Restored protected facts differ from source snapshot.'}
 & "$PSScriptRoot/Apply-NativeMigrations.ps1" -PostgreSQLBin $client -Database $copy
 $first=CheckNew $copy
 & "$PSScriptRoot/Apply-NativeMigrations.ps1" -PostgreSQLBin $client -Database $copy
 $second=CheckNew $copy
 if(($first|ConvertTo-Json -Compress)-ne($second|ConvertTo-Json -Compress)){throw 'Replay altered versioned definitions.'}
 if((Query $copy $factsSql)-ne $mainBefore){throw 'Protected facts changed after migrations.'}
 $receipt.checks+=@{name='Actual main snapshot restore, two new migrations and replay';passed=$true;definitions=$first;protectedFactsUnchanged=$true}
 if($Apply){foreach($db in @('aisports',$runtime.database)){
   $before=Query $db $factsSql
   & "$PSScriptRoot/Apply-NativeMigrations.ps1" -PostgreSQLBin $client -Database $db
   $details=CheckNew $db
   if((Query $db $factsSql)-ne $before){throw 'Protected business facts changed in target.'}
   $receipt.applied+=@{database=$db;definitions=$details;protectedFactsUnchanged=$true}
 }}
 $receipt.passed=$true;Write-Host ('PASS '+($migrations -join '/')+' actual restore/replay; protected business facts unchanged.')
}catch{$receipt.failure='Migration/restore check failed; inspect the protected local log.';throw}
finally{
 $env:PGPASSWORD=$env:POSTGRES_PASSWORD
 if($created -and $copy-match '^aisports_global_restore_[a-f0-9]{32}$'){& "$client/dropdb.exe" -h 127.0.0.1 -p 25432 -U $env:POSTGRES_USER $copy;if($LASTEXITCODE-ne 0){Write-Warning 'Owned restore copy retained for diagnosis.'}}
 $receipt.finishedAt=[DateTimeOffset]::Now.ToString('o');$receipt|ConvertTo-Json -Depth 14|Set-Content -LiteralPath (Join-Path $out 'receipt.json')
 Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}
