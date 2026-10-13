#requires -Version 7.0
[CmdletBinding()]
param([ValidateSet('frontend','ai-gateway','backend')][string[]]$Services=@('frontend','ai-gateway','backend'))
. "$PSScriptRoot/Common.ps1"
Set-Location -LiteralPath $WorkspaceRoot
$taskDocker=Get-DockerCommand
$taskRoot=Join-Path $WorkspaceRoot '.local/docker-stack'
$taskCompose=@('compose','--project-name','aisports-dev-docker','--env-file',(Join-Path $taskRoot 'runtime.env'),'-f',(Join-Path $WorkspaceRoot 'docker-compose.full.yml'))
foreach($taskService in $Services){
    $taskLog=Join-Path $taskRoot ('build-'+$taskService+'.log')
    if(Test-Path -LiteralPath $taskLog){Copy-Item -LiteralPath $taskLog -Destination ($taskLog+'.previous-'+[guid]::NewGuid().ToString('N'))}
    Write-Host ('Building '+$taskService+' with native Linux tools.')
    & $taskDocker @taskCompose --progress plain build $taskService *> $taskLog
    if($LASTEXITCODE -ne 0){throw ('Docker image build failed: '+$taskService+'; inspect its private log.')}
    Write-Host ($taskService+' image built and checks passed.')
}
