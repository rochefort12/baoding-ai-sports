#requires -Version 7.0
[CmdletBinding()]
param()
. "$PSScriptRoot/Common.ps1"
$taskDocker = Get-DockerCommand
$taskRoot = Join-Path $WorkspaceRoot '.local/docker-stack'
$taskChecks = [Collections.Generic.List[object]]::new()
function Add-DockerCheck([string]$Name,[bool]$Passed) {
    $taskChecks.Add(@{name=$Name;passed=$Passed})
    if (!$Passed) { throw ('Docker smoke check failed: '+$Name) }
}
$taskContainerNames=@('aisports-dev-docker-postgres','aisports-dev-docker-redis','aisports-dev-docker-minio','aisports-dev-docker-backend','aisports-dev-docker-ai-gateway','aisports-dev-docker-frontend')
$taskContainerState=@()
foreach($taskName in $taskContainerNames){
    $taskJson=& $taskDocker inspect $taskName
    Assert-NativeExit 'Inspect Docker trial service'
    $taskContainer=($taskJson -join "`n"|ConvertFrom-Json)[0]
    Add-DockerCheck ($taskName+' belongs to this workspace') ([IO.Path]::GetFullPath($taskContainer.Config.Labels.'com.docker.compose.project.working_dir') -eq [IO.Path]::GetFullPath($WorkspaceRoot))
    Add-DockerCheck ($taskName+' running') ($taskContainer.State.Running -eq $true)
    if($taskContainer.State.Health){Add-DockerCheck ($taskName+' healthy') ($taskContainer.State.Health.Status -eq 'healthy')}
    $taskContainerState+=@{name=$taskName;imageId=$taskContainer.Image;running=$taskContainer.State.Running;health=$taskContainer.State.Health.Status}
    if($taskName -match 'backend|ai-gateway'){Add-DockerCheck ($taskName+' has no published port') (@($taskContainer.HostConfig.PortBindings.PSObject.Properties).Count -eq 0)}
}
foreach($taskPath in @('/','/portal/login','/login','/healthz')){
    $taskResponse=Invoke-WebRequest -Uri ('http://localhost:5193'+$taskPath) -TimeoutSec 15
    Add-DockerCheck ('Frontend '+$taskPath) ($taskResponse.StatusCode -eq 200)
}
$taskCaptcha=Invoke-RestMethod -Uri 'http://localhost:5193/prod-api/auth/code' -TimeoutSec 15
Add-DockerCheck 'Nginx API proxy and local captcha policy' ($taskCaptcha.code -eq 200 -and $taskCaptcha.data.captchaEnabled -eq $false)
$taskEvents=Invoke-RestMethod -Uri 'http://localhost:5193/prod-api/sports/public/events' -TimeoutSec 15
Add-DockerCheck 'Anonymous public events query reaches PostgreSQL' ($taskEvents.code -eq 200)
$taskPrivate=Invoke-RestMethod -Uri 'http://localhost:5193/prod-api/sports/c/identity' -TimeoutSec 15 -SkipHttpErrorCheck
Add-DockerCheck 'Anonymous caller cannot read private identity' ($taskPrivate.code -eq 401)
$taskAgentCode=& $taskDocker exec aisports-dev-docker-ai-gateway node --input-type=module -e "const r=await fetch('http://127.0.0.1:8091/internal/agent',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'});console.log(r.status)"
Assert-NativeExit 'Check private gateway authentication'
Add-DockerCheck 'Gateway rejects unauthenticated internal Agent call' ($taskAgentCode.Trim() -eq '401')
$taskStorage=Invoke-WebRequest -Uri 'http://localhost:29000/minio/health/live' -TimeoutSec 10
Add-DockerCheck 'MinIO liveness on the independent local port' ($taskStorage.StatusCode -eq 200)
# The new baseline has no trial participant accounts. Only bootstrap admin login/read
# is checked; this never substitutes for ordinary-role business acceptance.
$taskSession=Get-Content -LiteralPath "$taskRoot/platform-admin.json" -Raw|ConvertFrom-Json
$taskLoginBody=@{username=$taskSession.username;password=$taskSession.password;tenantId=$taskSession.tenantId;grantType='password';clientId=$taskSession.clientId}|ConvertTo-Json -Compress
$taskLogin=Invoke-RestMethod -Uri 'http://localhost:5193/prod-api/auth/login' -Method Post -ContentType 'application/json' -Body $taskLoginBody -TimeoutSec 20
Add-DockerCheck 'New bootstrap platform account logs in' ($taskLogin.code -eq 200 -and [bool]$taskLogin.data.access_token)
$taskHeaders=@{Authorization='Bearer '+$taskLogin.data.access_token;clientid='e5cd7e4891bf95d1d19206ce24a7b32e'}
$taskIdentity=Invoke-RestMethod -Uri 'http://localhost:5193/prod-api/system/user/getInfo' -Headers $taskHeaders -TimeoutSec 20
Add-DockerCheck 'New platform admin can read their framework profile' ($taskIdentity.code -eq 200)
$taskProbePath=Join-Path $taskRoot 'storage-probe.txt'
[IO.File]::WriteAllText($taskProbePath,'AISPORTS_DOCKER_READINESS')
$taskOssId=$null
try {
    $taskUpload=Invoke-RestMethod -Uri 'http://localhost:5193/prod-api/resource/oss/upload' -Headers $taskHeaders -Method Post -Form @{file=Get-Item -LiteralPath $taskProbePath} -TimeoutSec 60
    Add-DockerCheck 'Authenticated upload reaches MinIO and records PostgreSQL metadata' ($taskUpload.code -eq 200 -and [bool]$taskUpload.data.ossId)
    $taskOssId=$taskUpload.data.ossId
    $taskUrl=[uri]$taskUpload.data.url
    Add-DockerCheck 'Private object URL uses the local browser endpoint with an expiring signature' ($taskUrl.Host -eq '127.0.0.1' -and $taskUrl.Port -eq 29000 -and $taskUrl.Query.Contains('X-Amz-Signature='))
    $taskObject=Invoke-WebRequest -Uri $taskUrl.AbsoluteUri -TimeoutSec 15
    $taskObjectText=if($taskObject.Content -is [byte[]]){[Text.Encoding]::UTF8.GetString($taskObject.Content)}else{[string]$taskObject.Content}
    Add-DockerCheck 'Signed browser object download matches uploaded bytes' ($taskObjectText -eq 'AISPORTS_DOCKER_READINESS')
    $taskAnonymous=Invoke-WebRequest -Uri ($taskUrl.GetLeftPart([UriPartial]::Path)) -SkipHttpErrorCheck -TimeoutSec 15
    Add-DockerCheck 'Object without signature is private' ($taskAnonymous.StatusCode -eq 403)
} finally {
    if($taskOssId){
        $taskDeleted=Invoke-RestMethod -Uri ('http://localhost:5193/prod-api/resource/oss/'+$taskOssId) -Headers $taskHeaders -Method Delete -TimeoutSec 20
        Add-DockerCheck 'Readiness object and its metadata are removed through the API' ($taskDeleted.code -eq 200)
    }
}
$taskLogout=Invoke-RestMethod -Uri 'http://localhost:5193/prod-api/auth/logout' -Headers $taskHeaders -Method Post -TimeoutSec 15
Add-DockerCheck 'Probe session closed' ($taskLogout.code -eq 200)
$taskLoginBody=$null;$taskLogin=$null;$taskHeaders.Clear();$taskSession=$null;$taskIdentity=$null
$taskReport=@{at=[DateTimeOffset]::Now.ToString('o');scope='Docker readiness, anonymous/bootstrap-admin probes, temporary file upload/read/privacy/delete; no model/SMS/funds/participant-registration writes';passed=$true;checks=@($taskChecks);containers=$taskContainerState;businessAcceptance='Ordinary-role user testing pending';loadTest='Not executed'}
$taskReport|ConvertTo-Json -Depth 8|Set-Content -LiteralPath "$taskRoot/smoke.json" -Encoding utf8
Write-Host ("Docker smoke checks passed: "+$taskChecks.Count+". Entry: http://localhost:5193/portal/login. No credentials printed.")
