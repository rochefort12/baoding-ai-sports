#requires -Version 7.0
<# Install the tested work-login package locally. No capability release or business data mutation. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PackagePath,
    [Parameter(Mandatory)][string]$ApiReceipt,
    [Parameter(Mandatory)][string]$UiReceipt,
    [Parameter(Mandatory)][string]$BuildReceipt,
    [Parameter(Mandatory)][string]$AuthenticatedUiReceipt,
    [Parameter(Mandatory)][string]$FrontendReceipt
)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"

function Assert-PlainPath([string]$Path) {
    $absolute=[IO.Path]::GetFullPath($(if([IO.Path]::IsPathRooted($Path)){$Path}else{Join-Path $WorkspaceRoot $Path}))
    if(-not $absolute.StartsWith($WorkspaceRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'A selected path escaped the workspace'}
    $cursor=$absolute
    while($cursor -and $cursor -ne $WorkspaceRoot){
        if((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'A selected path contains a reparse point'}
        $cursor=Split-Path $cursor -Parent
    }
    return $absolute
}
function Existing-Path([string]$Path){$absolute=Assert-PlainPath $Path;if(-not (Test-Path -LiteralPath $absolute -PathType Leaf)){throw 'A required file is absent'};return (Resolve-Path -LiteralPath $absolute).Path}
function Hash-File([string]$Path){return (Get-FileHash -LiteralPath (Existing-Path $Path) -Algorithm SHA256).Hash.ToLowerInvariant()}
function Relative-Path([string]$Path){return [IO.Path]::GetRelativePath($WorkspaceRoot,$Path).Replace('\','/')}
function Save-NewJson([string]$Path,$Value){
    $temporary=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($Value|ConvertTo-Json -Depth 40))
    $stream=[IO.File]::Open($temporary,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$stream.Write($bytes);$stream.Flush($true)}finally{$stream.Dispose()}
    [IO.File]::Move($temporary,$Path,$false)
}
function Protect-Directory([string]$Path){
    $directory=[IO.DirectoryInfo]::new($Path)
    $acl=[IO.FileSystemAclExtensions]::GetAccessControl($directory,[Security.AccessControl.AccessControlSections]::Access)
    $acl.SetAccessRuleProtection($true,$false)
    foreach($rule in @($acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]))){$acl.RemoveAccessRuleSpecific($rule)}
    foreach($sid in @([Security.Principal.WindowsIdentity]::GetCurrent().User,[Security.Principal.SecurityIdentifier]::new('S-1-5-18'))){$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))}
    [IO.FileSystemAclExtensions]::SetAccessControl($directory,$acl)
}
function Assert-OwnedBackend([int]$ProcessId,[int]$Port,[string]$ExpectedHash=''){
    $process=Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId"
    $match=[regex]::Match([string]$process.CommandLine,'-jar\s+(?:"(?<quoted>[^"]+)"|(?<bare>\S+))')
    if(-not $process -or $process.Name -notmatch '^java(w)?\.exe$' -or -not $match.Success){throw 'The selected backend process is not owned by this project'}
    $jar=Existing-Path $(if($match.Groups['quoted'].Success){$match.Groups['quoted'].Value}else{$match.Groups['bare'].Value})
    $packageRoot=[IO.Path]::GetFullPath((Join-Path $WorkspaceRoot '.local/runtime-packages'))+[IO.Path]::DirectorySeparatorChar
    $hash=Hash-File $jar
    if(-not $jar.StartsWith($packageRoot,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($jar) -ne 'ruoyi-admin.jar' -or (Split-Path (Split-Path $jar -Parent) -Leaf) -ne $hash -or ($ExpectedHash -and $ExpectedHash -ne $hash)){throw 'An immutable runtime package differs'}
    $listeners=@(Get-NetTCPConnection -State Listen -LocalPort $Port)
    if(-not $listeners.Count -or @($listeners|Where-Object {$_.OwningProcess -ne $ProcessId -or $_.LocalAddress -notin @('127.0.0.1','::1')}).Count){throw 'A backend listener has changed owner or exposure'}
    return @{pid=$ProcessId;port=$Port;jarPath=$jar;jarSha256=$hash}
}
function Read-PassedReceipt([string]$Path,[int]$MinimumChecks=0){
    $file=Existing-Path $Path;$value=Get-Content -LiteralPath $file -Raw|ConvertFrom-Json
    if($value.passed -ne $true -or ($MinimumChecks -gt 0 -and (@($value.checks).Count -lt $MinimumChecks -or @($value.checks|Where-Object {$_.passed -ne $true}).Count))){throw 'Actual passing evidence is required'}
    return @{file=$file;sha256=(Hash-File $file);value=$value}
}
function Verify-ReceiptSources($Value){
    if(@($Value.sources).Count -lt 2){throw 'UI evidence lacks product source hashes'}
    foreach($source in $Value.sources){if($source.sha256 -notmatch '^[a-f0-9]{64}$' -or (Hash-File $source.path) -ne $source.sha256){throw 'A UI-tested product source changed'}}
}
function Main-Api([string]$Route,[string]$Method='GET',$Body=$null,[int]$Timeout=30){
    $parameters=@{Uri=('http://127.0.0.1:8080'+$Route);Method=$Method;Headers=$headers;TimeoutSec=$Timeout}
    if($null -ne $Body){$parameters.ContentType='application/json';$parameters.Body=$Body|ConvertTo-Json -Depth 15 -Compress}
    try{$response=Invoke-RestMethod @parameters}catch{throw 'Main request unavailable; raw diagnostics omitted'}
    if($response.code -ne 200){throw 'A required main business request was rejected'}
    return $response.data
}
$tables=@('event','event_field','event_payment_config','competition_unit','capacity_pool','capacity_occupation','org_field','entry_field_value','declaration_ack','qualification_review','team','team_member','team_room','team_room_member','registration','registration_member','registration_payment_proof','roster_version','roster_member','fee_policy','fee_obligation','payment','payment_allocation','refund','payment_action','payment_exception','match','match_entry','result_version','result_item','checkin','growth_record','growth_profile','honor','title_equipment','complaint','complaint_message','notification','notification_delivery','file','organization','organization_application','organization_application_version','qualification','staff_grant','governance_grant')
function Business-Facts{
    $sql=($tables|ForEach-Object {"SELECT '$_='||count(*)||':'||md5(COALESCE(string_agg(row_to_json(t)::text,'|' ORDER BY id),'')) FROM asp_$_ t;"})-join "`n"
    $previous=[Environment]::GetEnvironmentVariable('PGPASSWORD','Process');$env:PGPASSWORD=$env:POSTGRES_PASSWORD
    try{
        $result=('BEGIN READ ONLY;'+"`n"+$sql+"`nROLLBACK;")|& 'C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin/psql.exe' -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d aisports -At -v ON_ERROR_STOP=1 2>$null
        if($LASTEXITCODE -ne 0){throw 'Main business fingerprint query failed'}
        return ($result|Where-Object {$_ -notin @('BEGIN','ROLLBACK')})-join "`n"
    }finally{[Environment]::SetEnvironmentVariable('PGPASSWORD',$previous,'Process')}
}
function Catalog-Activation($Catalog){return (@($Catalog.activations|Sort-Object code,channel)|ConvertTo-Json -Depth 40 -Compress)}
function Canonical-Object($Value){
    if($null -eq $Value){return $null}
    if($Value -is [pscustomobject]){
        $object=[ordered]@{}
        foreach($name in @($Value.psobject.Properties.Name|Sort-Object)){$object[$name]=Canonical-Object $Value.$name}
        return $object
    }
    if($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]){
        $items=@(foreach($item in $Value){,(Canonical-Object $item)})
        return ,$items
    }
    return $Value
}
function Catalog-Definitions($Catalog){
    # JSON key order and the three declared Set<String> fields can change across
    # JVMs. Compare full values, hashes and all ordered arrays after canonicalizing
    # only these semantically unordered parts; activation records remain exact.
    $copy=$Catalog.definitions|ConvertTo-Json -Depth 40|ConvertFrom-Json
    foreach($entry in $copy){foreach($field in @('actorTypes','reads','writes')){$entry.definition.$field=@($entry.definition.$field|Sort-Object)}}
    return (Canonical-Object @($copy|Sort-Object {$_.definition.code})|ConvertTo-Json -Depth 40 -Compress)
}
function Assert-SourceSnapshot($Sources){foreach($source in $Sources){if((Hash-File $source.path) -ne $source.sha256){throw 'A source changed during main installation'}}}

$out=Assert-PlainPath ('.local/login-refinement-20261011/main-release-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($out)|Out-Null;Protect-Directory $out
$stage='preflight evidence';$stopped=$false;$started=$false;$packet=$null;$headers=$null
$receipt=@{at=[DateTimeOffset]::Now.ToString('o');passed=$false;scope='Tested main loopback work-login package installation; authentication only; no capability release or tournament business mutations';fingerprintTableCount=$tables.Count;capabilityMutations=0;businessFactsUnchanged=$false;catalogUnchanged=$false;state='PREPARING';checks=@()}
Save-NewJson (Join-Path $out 'started.json') $receipt
try{
    if(-not $IsWindows){throw 'The protected local Windows host is required'}
    Import-LocalEnvironment
    if($env:POSTGRES_DB -ne 'aisports'){throw 'The main database identity changed'}
    $jar=Existing-Path $PackagePath;$jarHash=Hash-File $jar
    $api=Read-PassedReceipt $ApiReceipt 30;$ui=Read-PassedReceipt $UiReceipt 178;$authenticatedUi=Read-PassedReceipt $AuthenticatedUiReceipt 27;$build=Read-PassedReceipt $BuildReceipt;$frontend=Read-PassedReceipt $FrontendReceipt
    if($api.value.backendSha256 -ne $jarHash -or $build.value.jarSha256 -ne $jarHash -or (Hash-File $build.value.package) -ne $jarHash -or $build.value.tests -lt 415 -or $build.value.failures -ne 0 -or $build.value.errors -ne 0 -or $build.value.skipped -ne 0){throw 'The actual tests do not bind this package'}
    if((Hash-File $build.value.log) -ne $build.value.logSha256 -or -not (Select-String -LiteralPath $build.value.log -SimpleMatch 'BUILD SUCCESS')){throw 'The successful package build log changed'}
    if((Hash-File 'scripts/Test-WorkAccountAutoTenant.mjs') -ne $api.value.scriptSha256){throw 'The API acceptance script changed'}
    Verify-ReceiptSources $ui.value;Verify-ReceiptSources $authenticatedUi.value;Verify-ReceiptSources $frontend.value
    if($frontend.value.jarSha256 -ne $jarHash -or @($frontend.value.failures).Count -or $frontend.value.checks -notcontains 'typecheck' -or $frontend.value.checks -notcontains 'build:dev'){throw 'The passing frontend build does not bind this candidate package'}
    foreach($log in $frontend.value.logs){if((Hash-File (Join-Path (Split-Path $frontend.file -Parent) $log.file)) -ne $log.sha256){throw 'A frontend typecheck or build log changed'}}
    $candidate=Get-Content -LiteralPath (Existing-Path '.local/phase1-implementation/verification-runtime.json') -Raw|ConvertFrom-Json
    if($candidate.port -ne 8082 -or $candidate.database -notmatch '^aisports_verify_phase1_[a-f0-9]{32}$' -or $candidate.jarSHA256 -ne $jarHash -or $api.value.backendPid -ne $candidate.pid){throw 'The actual candidate identity changed'}
    $candidateOwner=Assert-OwnedBackend ([int]$candidate.pid) 8082 $jarHash
    $buildStartedPath=Existing-Path (Join-Path (Split-Path $build.file -Parent) 'build-started.json')
    $buildStarted=Get-Content -LiteralPath $buildStartedPath -Raw|ConvertFrom-Json
    $startUtc=([DateTimeOffset]::Parse($buildStarted.at)).UtcDateTime
    $finishUtc=([DateTimeOffset]::Parse($build.value.at)).UtcDateTime
    # The build did not record pre-build hashes. Report this narrower provenance honestly:
    # compiler input membership + sources predating build + packaged class equality, then release hashes.
    $compiled=@(
        @{path='org/dromara/web/controller/AuthController';test=$false},
        @{path='org/dromara/web/service/WorkAccountResolver';test=$false},
        @{path='org/dromara/web/service/WorkLoginGrantPolicy';test=$false},
        @{path='org/dromara/web/service/impl/WorkPasswordAuthStrategy';test=$false},
        @{path='org/dromara/web/domain/vo/WorkLoginMethodsVo';test=$false},
        @{path='org/dromara/web/service/WorkAccountResolverTest';test=$true},
        @{path='org/dromara/web/service/WorkLoginGrantPolicyTest';test=$true},
        @{path='org/dromara/web/service/impl/WorkPasswordCaptchaTest';test=$true}
    )
    $zip=[IO.Compression.ZipFile]::OpenRead($jar)
    try{
        foreach($file in $compiled){
            $kind=if($file.test){'test'}else{'main'};$compileKind=if($file.test){'testCompile/default-testCompile'}else{'compile/default-compile'};$classes=if($file.test){'test-classes'}else{'classes'}
            $source=Existing-Path ('backend/ruoyi-admin/src/'+$kind+'/java/'+$file.path+'.java')
            $input=Existing-Path ('backend/ruoyi-admin/target/maven-status/maven-compiler-plugin/'+$compileKind+'/inputFiles.lst')
            if((Get-Content -LiteralPath $input) -notcontains $source -or (Get-Item -LiteralPath $source).LastWriteTimeUtc -gt $startUtc){throw 'Backend source is absent from compiler input or changed after build began'}
            $class=Existing-Path ('backend/ruoyi-admin/target/'+$classes+'/'+$file.path+'.class')
            if((Get-Item -LiteralPath $class).LastWriteTimeUtc -lt $startUtc -or (Get-Item -LiteralPath $class).LastWriteTimeUtc -gt $finishUtc){throw 'The current compiler output does not belong to the recorded build'}
            if(-not $file.test){
                $entry=$zip.GetEntry('BOOT-INF/classes/'+$file.path+'.class');if(-not $entry){throw 'A compiled authentication class is missing from this package'}
                $stream=$entry.Open();$memory=[IO.MemoryStream]::new()
                try{$stream.CopyTo($memory);$entryHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($memory.ToArray())).ToLowerInvariant()}finally{$stream.Dispose();$memory.Dispose()}
                if($entryHash -ne (Hash-File $class)){throw 'A packaged authentication class differs from the tested compiler output'}
            }
        }
    }finally{$zip.Dispose()}
    $sources=@(Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot 'backend') -File -Recurse|Where-Object {$_.FullName -notmatch '[\\/]target[\\/]' -and $_.Extension -in @('.java','.xml','.yml','.yaml','.properties') -and $_.Name -ne '.flattened-pom.xml'}|ForEach-Object {
        if($_.LastWriteTimeUtc -gt $startUtc){throw 'A backend product source changed after the build began'}
        @{path=(Relative-Path $_.FullName);sha256=(Hash-File $_.FullName)}
    })
    $sources+=@($ui.value.sources)+@($authenticatedUi.value.sources)+@($frontend.value.sources)
    Save-NewJson (Join-Path $out 'source-binding.json') @{at=[DateTimeOffset]::Now.ToString('o');jarSha256=$jarHash;proof='Compiler input membership and recorded build/source timing with packaged class equality; hashes taken at release, not before build';buildStartedPath=(Relative-Path $buildStartedPath);buildStartedSha256=(Hash-File $buildStartedPath);sources=$sources}
    $receipt.jarSha256=$jarHash;$receipt.requiredEvidence=@($api,$ui,$authenticatedUi,$build,$frontend)|ForEach-Object {@{path=(Relative-Path $_.file);sha256=$_.sha256}}
    $receipt.backendSourceProof='No pre-build hash manifest exists; compiler inputs/timing/packaged classes verified and release-time source hashes preserved'
    $stage='main ownership and protected session'
    $priorPid=[int]([IO.File]::ReadAllText((Existing-Path '.local/backend.pid')).Trim());$prior=Assert-OwnedBackend $priorPid 8080
    $receipt.priorPid=$priorPid;$receipt.priorJarSha256=$prior.jarSha256;$receipt.priorJarPath=$prior.jarPath
    $protectedPath=Existing-Path '.local/main-access/administrator.dpapi'
    $protected=ConvertTo-SecureString ([IO.File]::ReadAllText($protectedPath).Trim());$pointer=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($protected)
    try{$packet=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)|ConvertFrom-Json}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer);$protected.Dispose()}
    if($packet.username -ne 'admin' -or $packet.baseUri -ne 'http://127.0.0.1:8080' -or -not $packet.password -or -not $packet.token -or -not $packet.clientId){throw 'Protected main administrator identity changed'}
    $headers=@{clientid=$packet.clientId;Authorization=('Bearer '+$packet.token)}
    $identity=Main-Api '/system/user/getInfo'
    if([string]$identity.user.userId -ne '1' -or $identity.user.tenantId -ne '000000' -or $identity.user.userName -ne 'admin'){throw 'The protected session no longer belongs to the main administrator'}
    $before=Main-Api '/sports/platform/management';$beforeActivation=Catalog-Activation $before;$beforeDefinitions=Catalog-Definitions $before
    Save-NewJson (Join-Path $out 'prior-catalog.json') $before
    $facts=Business-Facts;[IO.File]::WriteAllText((Join-Path $out 'before-facts.txt'),$facts,[Text.UTF8Encoding]::new($false))
    $captcha=Main-Api '/auth/code';if($captcha.captchaEnabled -ne $false){throw 'Actual administrator login requires a human captcha; no code is injected'}
    $stage='main database backup and journal preservation'
    $dump=Join-Path $out 'before.dump';$previous=[Environment]::GetEnvironmentVariable('PGPASSWORD','Process');$env:PGPASSWORD=$env:POSTGRES_PASSWORD
    try{& 'C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin/pg_dump.exe' -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d aisports -Fc -f $dump 2>$null;Assert-NativeExit 'Main pre-install backup'}finally{[Environment]::SetEnvironmentVariable('PGPASSWORD',$previous,'Process')}
    $receipt.backupSha256=Hash-File $dump
    foreach($log in @('backend-default-runtime.log','backend-default-error.log')){Copy-Item -LiteralPath (Existing-Path ('.local/'+$log)) -Destination (Join-Path $out ('prior-'+$log))}
    Assert-SourceSnapshot $sources
    $unchangedOwner=Assert-OwnedBackend $priorPid 8080 $prior.jarSha256
    $stage='owned process replacement'
    Stop-Process -Id $priorPid;$stopped=$true
    for($attempt=0;$attempt -lt 50;$attempt++){$listener=@(Get-NetTCPConnection -State Listen -LocalPort 8080 -ErrorAction SilentlyContinue);if(-not $listener.Count){break};if(@($listener|Where-Object {$_.OwningProcess -ne $priorPid}).Count){throw 'Main port acquired a different owner'};Start-Sleep -Milliseconds 100}
    if(Get-NetTCPConnection -State Listen -LocalPort 8080 -ErrorAction SilentlyContinue){throw 'Main listener did not release'}
    if((Hash-File $jar) -ne $jarHash){throw 'Selected package changed before startup'}
    Copy-Item -LiteralPath $jar -Destination (Assert-PlainPath 'backend/ruoyi-admin/target/ruoyi-admin.jar')
    & "$PSScriptRoot/Start-Backend.ps1" -JavaHome 'D:/dev/jdk17' -Background
    $started=$true
    $stage='actual main authentication and unchanged catalog'
    $ready=$false
    for($attempt=0;$attempt -lt 50;$attempt++){try{$methods=Main-Api '/auth/work-methods' 'GET' $null 3;$ready=$true;break}catch{Start-Sleep -Milliseconds 800}}
    if(-not $ready -or $methods.wechat.available -ne $false){throw 'New main work-login metadata not ready'}
    $mainPid=[int]([IO.File]::ReadAllText((Existing-Path '.local/backend.pid')).Trim());$installed=Assert-OwnedBackend $mainPid 8080 $jarHash
    $login=Main-Api '/auth/login' 'POST' @{username='admin';password=$packet.password;clientId=$packet.clientId;grantType='work-password'}
    if(-not $login.access_token){throw 'Actual work-account login did not return a session'}
    $headers.Authorization='Bearer '+$login.access_token
    $identity=Main-Api '/system/user/getInfo'
    if([string]$identity.user.userId -ne '1' -or $identity.user.tenantId -ne '000000' -or $identity.user.userName -ne 'admin'){throw 'Automatic organization resolution returned another identity'}
    $after=Main-Api '/sports/platform/management'
    if((Catalog-Activation $after) -ne $beforeActivation -or (Catalog-Definitions $after) -ne $beforeDefinitions){throw 'Platform activation records or registered definitions changed'}
    Save-NewJson (Join-Path $out 'after-catalog.json') $after
    $agents=@($after.activations|Where-Object {$_.enabled -and $_.channel -eq 'agent'})
    foreach($activation in $agents){$definition=@($after.definitions|Where-Object {$_.definition.code -eq $activation.code})[0].definition;if($definition.mutation -or @($definition.writes).Count){throw 'An enabled Agent channel is not read-only'}}
    $afterFacts=Business-Facts;[IO.File]::WriteAllText((Join-Path $out 'after-facts.txt'),$afterFacts,[Text.UTF8Encoding]::new($false))
    if($afterFacts -ne $facts){throw 'Main tournament business facts changed'}
    $events=Main-Api '/sports/public/events'
    Assert-SourceSnapshot $sources
    foreach($gate in @($api,$ui,$authenticatedUi,$build,$frontend)){if((Hash-File $gate.file) -ne $gate.sha256){throw 'Acceptance evidence changed during installation'}}
    $receipt.mainPid=$mainPid;$receipt.mainJarPath=$installed.jarPath;$receipt.mainJarSha256=$installed.jarSha256
    $receipt.businessFactsUnchanged=$true;$receipt.catalogUnchanged=$true;$receipt.adminAutomaticTenantVerified=$true;$receipt.wechatAvailable=$false
    $receipt.uiEnabled=@($after.activations|Where-Object {$_.enabled -and $_.channel -eq 'ui'}).Count;$receipt.agentEnabled=$agents.Count;$receipt.agentWrites=0
    $receipt.sourceBindingSha256=Hash-File (Join-Path $out 'source-binding.json');$receipt.state='LOCAL_MAIN_LOGIN_REFINEMENT_INSTALLED';$receipt.passed=$true
    $receipt.checks=@('Actual administrator login and organization','All activation rows and definitions unchanged','46 full business table fingerprints unchanged','Public events and unavailable work-WeChat metadata','Owned immutable loopback package and frozen sources')|ForEach-Object {@{name=$_;passed=$true}}
    Write-Host 'PASS tested work-login package installed; organization resolved and existing channels/business facts preserved'
}catch{
    $receipt.state='FAILED_REQUIRES_RECOVERY';$receipt.failure=@{stage=$stage;kind=$_.Exception.GetType().Name};$receipt.stoppedOwnedProcess=$stopped;$receipt.startedReplacement=$started
    $receipt.recovery='Inspect preserved old immutable package and runtime logs. No database restore, capability mutation or automatic rollback was attempted.'
    throw [InvalidOperationException]::new('Work-login installation failed at '+$stage+'; private response and credentials omitted')
}finally{
    $receipt.finishedAt=[DateTimeOffset]::Now.ToString('o');Save-NewJson (Join-Path $out 'receipt.json') $receipt
    $packet=$null;$headers=$null;$login=$null
    Write-Host ('Evidence '+$out)
}
