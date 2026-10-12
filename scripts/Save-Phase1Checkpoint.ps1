#requires -Version 7.0
<# Preserve an immutable recovery checkpoint and a linked UI verification supplement. #>
[CmdletBinding()]param()
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$out=Join-Path $WorkspaceRoot '.local/phase1-implementation'
$evidence=Join-Path $WorkspaceRoot 'docs/04-verification/羽毛球一期闭环本机验证-20261010.json'
$releaseFile=Get-ChildItem -LiteralPath $out -Filter 'local-capability-release-receipt-*.json'|Sort-Object LastWriteTime -Descending|Select-Object -First 1
if(!$releaseFile){throw 'A successful local release receipt is required'}
$release=Get-Content $releaseFile.FullName -Raw|ConvertFrom-Json
$jarHash=(Get-FileHash (Join-Path $WorkspaceRoot 'backend/ruoyi-admin/target/ruoyi-admin.jar')).Hash.ToLowerInvariant()
$evidenceHash=(Get-FileHash $evidence).Hash.ToLowerInvariant()
if($release.rollback -or $jarHash -ne $release.jarSha256 -or $evidenceHash -ne $release.evidenceSha256){throw 'Published build/evidence changed'}
if((Get-FileHash (Join-Path $out $release.backup)).Hash.ToLowerInvariant() -ne $release.backupSha256){throw 'Pre-release backup does not match its receipt'}
$typeLog=Join-Path $out 'product-task-return-typecheck.log'
$buildLog=Join-Path $out 'product-task-return-build.log'
$returnLog=Join-Path $out 'product-return-to-final.log'
if([IO.File]::ReadAllText($typeLog).Trim() -or [IO.File]::ReadAllText($buildLog) -notmatch '✓ built in' -or [IO.File]::ReadAllText($returnLog) -notmatch '9 passed'){throw 'Final UI/task-return verification is incomplete'}
$main=Get-Content (Join-Path $out 'main-product-receipt.json') -Raw|ConvertFrom-Json
if($main.errors.Count -ne 0 -or $main.checks.Count -ne 6){throw 'Main-service smoke checks incomplete'}
$env:PGPASSWORD=$env:POSTGRES_PASSWORD
try{
 $bin='C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin'
 $channels=& "$bin/psql.exe" -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d $env:POSTGRES_DB -At -v ON_ERROR_STOP=1 -c "SELECT count(*) FILTER(WHERE channel='ui' AND enabled),count(*) FILTER(WHERE channel='agent' AND enabled) FROM asp_capability_activation"
 Assert-NativeExit 'Verify released local channels'
 if($channels.Trim() -ne '47|0'){throw 'Channel state differs from the tested local release'}
}finally{Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue}
function Write-ImmutableJson([string]$path,$value){
 if(Test-Path -LiteralPath $path){throw 'Immutable receipt already exists'}
 $stage=$path+'.stage-'+[guid]::NewGuid().ToString('N')
 $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($value|ConvertTo-Json -Depth 14)+"`n")
 $stream=[IO.File]::Open($stage,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
 [IO.File]::Move($stage,$path)
}
$ports=@(Get-NetTCPConnection -State Listen -LocalPort 5190,8080,8082,8091,25432,26379,29000 | Select-Object LocalAddress,LocalPort,OwningProcess)
if(($ports |Where-Object {$_.LocalAddress -notin @('127.0.0.1','::1')}).Count){throw 'Local service boundary changed'}
$supplement=@{timestamp=[DateTimeOffset]::Now.ToString('o');scope='local-controlled-trial';failures=0;parentEvidenceSha256=$evidenceHash;jarSha256=$jarHash;
 changes=@('Organizer reauthentication preserves registrations, competition, issues and closure task','Private/external redirect rejection retained');
 tests=@{returnTargetTests=9;mainAnonymousBrowserAndAuthorizationChecks=6;typecheck='PASS';build='PASS with existing chunk-size warning'};
 humanUiEnabled=47;agentEnabled=0;releaseReceiptSha256=(Get-FileHash $releaseFile.FullName).Hash.ToLowerInvariant();
 evidence=@(@('product-return-to-final.log','product-task-return-typecheck.log','product-task-return-build.log','main-product-receipt.json')|ForEach-Object {@{path='.local/phase1-implementation/'+$_;sha256=(Get-FileHash (Join-Path $out $_)).Hash.ToLowerInvariant()}})
}
$supplementPath=Join-Path $WorkspaceRoot 'docs/04-verification/羽毛球一期产品交互补验-20261010.json'
Write-ImmutableJson $supplementPath $supplement
$checkpoint=@{timestamp=[DateTimeOffset]::Now.ToString('o');scope='local-controlled-trial';branch=(& git -C $WorkspaceRoot branch --show-current);jarSha256=$jarHash;evidenceSha256=$evidenceHash;supplementSha256=(Get-FileHash $supplementPath).Hash.ToLowerInvariant();releaseReceipt=$releaseFile.Name;
 migrations='V030-V033';humanUiEnabled=47;agentEnabled=0;ports=$ports;modelCredentialPresent=(Test-Path (Join-Path $WorkspaceRoot '.local/secrets/deepseek.dpapi'));
 nextGate='Protected model credential, live material/tool verification and legacy writer hardening; then actual-role/event/SMS/funds acceptance';
 resume='Resume-Phase1.ps1 for existing dependencies/frontend/AI, Start-Backend.ps1 -JavaHome D:/dev/jdk17 -Background only when main backend is absent. Do not replay test init or facts.'}
Write-ImmutableJson (Join-Path $out ('implementation-checkpoint-'+[guid]::NewGuid().ToString('N')+'.json')) $checkpoint
Write-Host 'Immutable supplement and recovery checkpoint saved; published evidence bytes unchanged.'
