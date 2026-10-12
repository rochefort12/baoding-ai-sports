#requires -Version 7.0
<# .SYNOPSIS 实际HTTP公开入口及匿名权限拒绝，不带会话、不执行已授权写入。 #>
param([string]$BaseUrl='http://127.0.0.1:5173')
$ErrorActionPreference='Stop'
$checks=[System.Collections.Generic.List[string]]::new()
$cases=@(
 @{name='public-portal';method='GET';path='/portal/home';public=$true},
 @{name='public-api-proxy';method='GET';path='/dev-api/sports/public/events';public=$true},
 @{name='anonymous-money-read';method='GET';path='/dev-api/sports/b/fees/obligations/1/records'},
 @{name='anonymous-money-write';method='POST';path='/dev-api/sports/b/fees/obligations/1/confirm'},
 @{name='anonymous-team-invitation';method='GET';path='/dev-api/sports/c/teams/invitations/1'},
 @{name='anonymous-registration-invitation';method='GET';path='/dev-api/sports/c/registrations/invites/isolated-does-not-exist'}
)
foreach($case in $cases){
 $options=@{Uri=$BaseUrl+$case.path;Method=$case.method;TimeoutSec=10;SkipHttpErrorCheck=$true}
 if($case.method -eq 'POST'){$options.ContentType='application/json';$options.Body='{}'}
 $response=Invoke-WebRequest @options
 if($case.public){
  if($response.StatusCode -ne 200){throw "Public endpoint unavailable: $($case.name)"}
  if($case.path.StartsWith('/dev-api')){if(($response.Content|ConvertFrom-Json).code -ne 200){throw 'Public proxy returned a business error'}}
 }else{
  $body=$response.Content|ConvertFrom-Json
  if($response.StatusCode -notin @(401,403) -and $body.code -notin @(401,403)){throw "Anonymous endpoint not rejected by authentication: $($case.name)"}
  if($null -ne $body.data){throw "Anonymous response contains private business data: $($case.name)"}
 }
 $checks.Add($case.name);Write-Host "PASS $($case.name)"
}
$outDir=Join-Path (Split-Path $PSScriptRoot -Parent) '.local/critical-tests';New-Item -ItemType Directory -Force -Path $outDir|Out-Null
@{scope='Real HTTP public access and anonymous denial only';checks=$checks.ToArray()}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $outDir 'http-results.json') -Encoding utf8
