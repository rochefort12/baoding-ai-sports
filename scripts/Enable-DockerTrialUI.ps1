#requires -Version 7.0
# Reapply previously verified UI configuration only when current provider definitions
# match exactly. No old business records, actors, passwords or Agent grants are imported.
[CmdletBinding()]
param([string]$Manifest)
. "$PSScriptRoot/DockerStack.Common.ps1"
if($env:POSTGRES_DB-ne'aisports_docker_fresh'){throw 'Only the local fresh database is allowed.'}
if(!$Manifest){
    $Manifest=Join-Path $taskRoot 'verified-ui-current.json'
    if(!(Test-Path -LiteralPath $Manifest)){$Manifest=Join-Path $WorkspaceRoot '.local/phase1-implementation/verified-ui-capabilities.json'}
}
if(!(Test-Path -LiteralPath $Manifest)){Write-Host 'No prior verified UI manifest. Release capabilities in platform management after validation.';return}
$taskSmoke=Get-Content -LiteralPath "$taskRoot/smoke.json" -Raw|ConvertFrom-Json
if(!$taskSmoke.passed){throw 'Current Docker readiness must pass before provisional UI configuration.'}
$taskVerified=Get-Content -LiteralPath $Manifest -Raw|ConvertFrom-Json
$taskAdmin=Get-Content -LiteralPath "$taskRoot/platform-admin.json" -Raw|ConvertFrom-Json
$taskLoginBody=@{username=$taskAdmin.username;password=$taskAdmin.password;tenantId=$taskAdmin.tenantId;clientId=$taskAdmin.clientId;grantType='password'}|ConvertTo-Json -Compress
$taskLogin=Invoke-RestMethod -Uri 'http://localhost:5193/prod-api/auth/login' -Method Post -ContentType 'application/json' -Body $taskLoginBody -TimeoutSec 20
if($taskLogin.code-ne200 -or !$taskLogin.data.access_token){throw 'Platform bootstrap login failed.'}
$taskHeaders=@{Authorization='Bearer '+$taskLogin.data.access_token;clientid=$taskAdmin.clientId}
$taskReleased=[Collections.Generic.List[string]]::new();$taskSkipped=[Collections.Generic.List[string]]::new()
try {
    $taskCatalog=Invoke-RestMethod -Uri 'http://localhost:5193/prod-api/sports/platform/management' -Headers $taskHeaders -TimeoutSec 30
    if($taskCatalog.code-ne200){throw 'Current provider catalog unavailable.'}
    $taskBeforeAgents=@($taskCatalog.data.activations|Where-Object channel -eq 'agent')|ConvertTo-Json -Depth 20 -Compress
    $taskEvidence=@{scope='Local provisional UI configuration; ordinary-role Docker acceptance pending';manifestSha256=(Get-FileHash -LiteralPath $Manifest -Algorithm SHA256).Hash.ToLowerInvariant();readinessSha256=(Get-FileHash -LiteralPath "$taskRoot/smoke.json" -Algorithm SHA256).Hash.ToLowerInvariant();backendBuildSha256=(Get-FileHash -LiteralPath "$taskRoot/build-backend.log" -Algorithm SHA256).Hash.ToLowerInvariant()}
    $taskEvidence|ConvertTo-Json|Set-Content -LiteralPath "$taskRoot/ui-release-evidence.json" -Encoding utf8
    $taskEvidenceHash=(Get-FileHash -LiteralPath "$taskRoot/ui-release-evidence.json" -Algorithm SHA256).Hash.ToLowerInvariant()
    foreach($taskPrior in $taskVerified.definitions){
        $taskCurrent=@($taskCatalog.data.definitions|Where-Object {$_.definition.code-eq$taskPrior.code})
        if($taskCurrent.Count-ne1 -or $taskCurrent[0].definitionHash-ne$taskPrior.definitionHash){$taskSkipped.Add($taskPrior.code);continue}
        $taskOpen=@($taskCatalog.data.activations|Where-Object {$_.code-eq$taskPrior.code -and $_.channel-eq'ui' -and $_.enabled -and $_.source_hash-eq$taskPrior.definitionHash})
        if($taskOpen.Count-eq0){
            $taskBody=@{code=$taskPrior.code;channel='ui';enabled=$true;definitionHash=$taskPrior.definitionHash;evidenceHash=$taskEvidenceHash}|ConvertTo-Json -Compress
            $taskResult=Invoke-RestMethod -Uri 'http://localhost:5193/prod-api/sports/platform/management/release' -Headers $taskHeaders -Method Post -ContentType 'application/json' -Body $taskBody -TimeoutSec 20
            if($taskResult.code-ne200){throw ('UI release failed: '+$taskPrior.code)}
        }
        $taskReleased.Add($taskPrior.code)
    }
    $taskAfter=Invoke-RestMethod -Uri 'http://localhost:5193/prod-api/sports/platform/management' -Headers $taskHeaders -TimeoutSec 30
    $taskAfterAgents=@($taskAfter.data.activations|Where-Object channel -eq 'agent')|ConvertTo-Json -Depth 20 -Compress
    if($taskBeforeAgents-ne$taskAfterAgents){throw 'Unexpected Agent activation change.'}
    $taskClosed=@($taskAfter.data.definitions|Where-Object {$taskDef=$_;!@($taskAfter.data.activations|Where-Object {$_.code-eq$taskDef.definition.code -and $_.channel-eq'ui' -and $_.enabled -and $_.source_hash-eq$taskDef.definitionHash}).Count}|ForEach-Object {$_.definition.code})
    @{at=[DateTimeOffset]::Now.ToString('o');scope=$taskEvidence.scope;released=@($taskReleased);definitionMismatch=@($taskSkipped);closedUiCodes=$taskClosed;agentActivationsUnchanged=$true;passed=$true}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath "$taskRoot/ui-release.json" -Encoding utf8
} finally {
    Invoke-RestMethod -Uri 'http://localhost:5193/prod-api/auth/logout' -Headers $taskHeaders -Method Post -TimeoutSec 15|Out-Null
    $taskHeaders.Clear();$taskLoginBody=$null;$taskLogin=$null;$taskAdmin=$null
}
Write-Host ("Verified UI definitions enabled for local user testing: "+$taskReleased.Count+"; changed/unverified definitions retained closed: "+$taskSkipped.Count+". Agent channels unchanged.")
