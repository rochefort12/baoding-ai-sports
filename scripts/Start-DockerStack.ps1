#requires -Version 7.0
[CmdletBinding()]
param([switch]$Build,[switch]$DependenciesOnly)
& "$PSScriptRoot/Initialize-DockerFresh.ps1"
. "$PSScriptRoot/DockerStack.Common.ps1"
if($DependenciesOnly){return}
$taskMissingImage=$false
foreach($taskImage in @('aisports-dev-backend:local','aisports-dev-frontend:local','aisports-dev-ai-gateway:local')){
    & $taskDocker image inspect $taskImage --format '{{.Id}}' *> $null
    if($LASTEXITCODE-ne0){$taskMissingImage=$true}
}
if($Build -or $taskMissingImage){& "$PSScriptRoot/Build-DockerImages.ps1"}
# Node shares the backend's private namespace: recreate the three applications together.
& $taskDocker @taskCompose up -d --force-recreate --wait --wait-timeout 600 backend ai-gateway frontend
Assert-NativeExit 'Full Docker application readiness'
& "$PSScriptRoot/Apply-DockerMigrations.ps1" -Command validate
Invoke-DockerSql ([IO.File]::ReadAllText("$WorkspaceRoot/database/verification/preparation.sql"))|Set-Content -LiteralPath "$taskRoot/baseline-verification.log"
& "$PSScriptRoot/Test-DockerStack.ps1"
Write-Host 'All six services run in Docker. Test entry: http://localhost:5193/portal/login'
