#requires -Version 7.0
<# Reuse the documented local administrator credential; never resets an account or business fact. #>
[CmdletBinding()]param()
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$taskPid=[int]([IO.File]::ReadAllText((Join-Path $WorkspaceRoot '.local/backend.pid')).Trim())
$taskProcess=Get-CimInstance Win32_Process -Filter "ProcessId=$taskPid"
# Startup now holds an immutable package rather than Maven's writable output.
# Validate the actual JVM argument and content-addressed directory, not a stale target path.
if(!$taskProcess -or $taskProcess.Name -notmatch '^java(w)?\.exe$'){throw 'Main backend ownership changed'}
$jarMatch=[regex]::Match([string]$taskProcess.CommandLine,'-jar\s+(?:"(?<quoted>[^"]+)"|(?<bare>\S+))')
if(!$jarMatch.Success){throw 'Main package argument is absent'}
$jar=(Resolve-Path -LiteralPath $(if($jarMatch.Groups['quoted'].Success){$jarMatch.Groups['quoted'].Value}else{$jarMatch.Groups['bare'].Value})).Path
$targetJar=[IO.Path]::GetFullPath((Join-Path $WorkspaceRoot 'backend/ruoyi-admin/target/ruoyi-admin.jar'))
$packageRoot=[IO.Path]::GetFullPath((Join-Path $WorkspaceRoot '.local/runtime-packages'))+[IO.Path]::DirectorySeparatorChar
if($jar -ne $targetJar){
 if(!$jar.StartsWith($packageRoot,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($jar) -ne 'ruoyi-admin.jar'){throw 'Main immutable package escaped its workspace'}
 $expectedHash=Split-Path (Split-Path $jar -Parent) -Leaf
 if($expectedHash -notmatch '^[a-f0-9]{64}$' -or (Get-FileHash -LiteralPath $jar).Hash.ToLowerInvariant() -ne $expectedHash){throw 'Main immutable package hash differs'}
}
$listeners=@(Get-NetTCPConnection -State Listen -LocalPort 8080)
if(!$listeners.Count -or @($listeners|Where-Object {$_.OwningProcess-ne $taskPid -or $_.LocalAddress-ne '127.0.0.1'}).Count){throw 'Main listener boundary changed'}
if($env:POSTGRES_DB-ne 'aisports'){throw 'Main database identity changed'}
$source=Join-Path $WorkspaceRoot 'docs/04-verification/内部试用说明.md'
$pattern='(?m)^\|\s*平台管理员\s*\|\s*`(?<account>[^`]+)`\s*\|\s*`(?<password>[^`]+)`\s*\|'
$stored=Join-Path $WorkspaceRoot '.local/main-access/administrator.dpapi'
if(Test-Path -LiteralPath $stored){
 $secret=ConvertTo-SecureString ([IO.File]::ReadAllText($stored).Trim());$pointer=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
 try{$prior=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)|ConvertFrom-Json}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer);$secret.Dispose()}
 if($prior.username-ne 'admin' -or $prior.baseUri-ne 'http://127.0.0.1:8080'){throw 'Protected credential identity changed'}
 $taskPassword=$prior.password;$prior=$null
}else{
 $match=[regex]::Match([IO.File]::ReadAllText($source),$pattern)
 if(!$match.Success -or $match.Groups['account'].Value-ne 'admin'){throw 'Explicit prior administrator credential source is absent'}
 $taskPassword=$match.Groups['password'].Value
}
$taskPreviousPg=[Environment]::GetEnvironmentVariable('PGPASSWORD','Process')
$env:PGPASSWORD=$env:POSTGRES_PASSWORD
try{
 $literal="'"+$taskPassword.Replace("'","''")+"'"
 $sql="SELECT CASE WHEN password=crypt($literal,password) AND status='0' AND del_flag='0' THEN 'matched' ELSE 'unmatched' END FROM sys_user WHERE user_id=1 AND user_name='admin' AND tenant_id='000000';"
 $result=$sql|& 'C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin/psql.exe' -X -h 127.0.0.1 -p $env:POSTGRES_PORT -U $env:POSTGRES_USER -d aisports -At -v ON_ERROR_STOP=1 2>$null
 if($LASTEXITCODE-ne 0 -or ($result-join '').Trim()-ne 'matched'){throw 'Documented credential did not match current main administrator; no login/reset attempted'}
}finally{[Environment]::SetEnvironmentVariable('PGPASSWORD',$taskPreviousPg,'Process')}
$client='e5cd7e4891bf95d1d19206ce24a7b32e'
try{$login=Invoke-RestMethod -Uri 'http://127.0.0.1:8080/auth/login' -Method Post -Headers @{clientid=$client} -ContentType 'application/json' -Body (@{username='admin';password=$taskPassword;tenantId='000000';grantType='password';clientId=$client}|ConvertTo-Json) -TimeoutSec 20}catch{throw 'Main login did not complete; no raw credential diagnostics printed'}
if($login.code-ne 200 -or !$login.data.access_token){throw 'Main login rejected; no reset attempted'}
try{$catalog=Invoke-RestMethod -Uri 'http://127.0.0.1:8080/sports/platform/management' -Headers @{clientid=$client;Authorization='Bearer '+$login.data.access_token} -TimeoutSec 20}catch{throw 'Authenticated main management check failed'}
if($catalog.code-ne 200){throw 'Main management rejected current identity'}
$out=Join-Path $WorkspaceRoot '.local/main-access';New-Item -ItemType Directory -Path $out -Force|Out-Null
$directory=[IO.DirectoryInfo]::new($out);$acl=[IO.FileSystemAclExtensions]::GetAccessControl($directory,[Security.AccessControl.AccessControlSections]::Access);$acl.SetAccessRuleProtection($true,$false)
foreach($rule in @($acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]))){$acl.RemoveAccessRuleSpecific($rule)}
foreach($sid in @([Security.Principal.WindowsIdentity]::GetCurrent().User,[Security.Principal.SecurityIdentifier]::new('S-1-5-18'))){$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))}
[IO.FileSystemAclExtensions]::SetAccessControl($directory,$acl)
$value=@{username='admin';password=$taskPassword;token=$login.data.access_token;clientId=$client;tenantId='000000';baseUri='http://127.0.0.1:8080';observedAt=[DateTimeOffset]::Now.ToString('o')}|ConvertTo-Json -Compress
ConvertTo-SecureString $value -AsPlainText -Force|ConvertFrom-SecureString|Set-Content -LiteralPath (Join-Path $out 'administrator.dpapi')
[IO.File]::WriteAllText((Join-Path $out '主站管理员.txt'),("主站工作账号：http://127.0.0.1:5190/login`n账号：admin`n密码："+$taskPassword+"`n仅本机受控环境。与5192演练账号不同。`n"),[Text.UTF8Encoding]::new($false))
@{timestamp=[DateTimeOffset]::Now.ToString('o');passed=$true;credentialMatchedCurrentMainHash=$true;actualLogin=$true;actualManagement=$true;accountReset=$false;businessMutations=0;uiChannels=@($catalog.data.activations|Where-Object {$_.channel-eq 'ui' -and $_.enabled}).Count;agentChannels=@($catalog.data.activations|Where-Object {$_.channel-eq 'agent' -and $_.enabled}).Count}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out ('recovery-'+[guid]::NewGuid().ToString('N')+'.json'))
$taskPassword=$null;$value=$null;$login=$null
Write-Host 'PASS existing main administrator credential verified and real login recovered; no password reset or business changes'
