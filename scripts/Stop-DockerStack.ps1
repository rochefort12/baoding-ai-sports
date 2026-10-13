#requires -Version 7.0
[CmdletBinding()]
param()
. "$PSScriptRoot/Common.ps1"
$taskDocker=Get-DockerCommand
Set-Location -LiteralPath $WorkspaceRoot
$taskEnv=Join-Path $WorkspaceRoot '.local/docker-stack/runtime.env'
if (!(Test-Path -LiteralPath $taskEnv)) { throw 'Docker trial environment has not been prepared.' }
foreach ($taskName in @('aisports-dev-docker-postgres','aisports-dev-docker-redis','aisports-dev-docker-minio','aisports-dev-docker-backend','aisports-dev-docker-ai-gateway','aisports-dev-docker-frontend')) {
    $taskOwner=& $taskDocker inspect $taskName --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' 2>$null
    if($LASTEXITCODE -eq 0 -and [IO.Path]::GetFullPath($taskOwner.Trim()) -ne [IO.Path]::GetFullPath($WorkspaceRoot)){throw 'A Docker trial container belongs to another workspace.'}
}
& $taskDocker compose --project-name aisports-dev-docker --env-file $taskEnv -f docker-compose.full.yml stop
Assert-NativeExit 'Stop only the full AISports Docker trial'
Write-Host 'Docker trial stopped; containers, volumes, files and original native data retained.'
