#requires -Version 7.0
. "$PSScriptRoot/Common.ps1"
$taskDocker = Get-DockerCommand
$taskRoot = Join-Path $WorkspaceRoot '.local/docker-stack'
$taskEnv = Join-Path $taskRoot 'runtime.env'
function Import-DockerEnvironment {
    if (!(Test-Path -LiteralPath $taskEnv)) { throw 'Prepare private Docker runtime.env first; no trial database is imported.' }
    foreach ($taskLine in Get-Content -LiteralPath $taskEnv) {
        if ($taskLine -match '^([A-Z][A-Z0-9_]*)=(.*)$') {
            $taskValue = $Matches[2]
            if ($taskValue.StartsWith("'") -and $taskValue.EndsWith("'")) { $taskValue = $taskValue.Substring(1,$taskValue.Length-2).Replace("\'", "'") }
            [Environment]::SetEnvironmentVariable($Matches[1],$taskValue,'Process')
        }
    }
}
function Assert-DockerOwnership {
    foreach ($taskContainer in @('postgres','redis','minio','backend','ai-gateway','frontend')) {
        $taskOwner = & $taskDocker inspect "aisports-dev-docker-$taskContainer" --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' 2>$null
        if ($LASTEXITCODE -eq 0 -and [IO.Path]::GetFullPath($taskOwner.Trim()) -ne [IO.Path]::GetFullPath($WorkspaceRoot)) { throw 'A target container belongs to another workspace.' }
    }
}
function Invoke-DockerSql([string]$Sql, [string]$Database = $env:POSTGRES_DB) {
    if ($Database -notmatch '^aisports_docker_[a-z0-9_]+$' -and $Database -ne 'postgres') { throw 'Only an isolated Docker database is allowed.' }
    $taskResult = $Sql | & $taskDocker exec -i aisports-dev-docker-postgres psql -X -U $env:POSTGRES_USER -d $Database -At -v ON_ERROR_STOP=1 2> "$taskRoot/query-error.log"
    Assert-NativeExit 'Isolated Docker database operation (private query-error.log)'
    return $taskResult
}
function Write-DockerApplicationEnvironment {
    # ADR-049: owner credentials serve only Flyway's dedicated startup connection;
    # the business datasource remains APP_DB_USER. Node never receives either role.
    $taskBackendLines = @(Get-Content -LiteralPath $taskEnv | Where-Object { $_ -match '^(POSTGRES_DB|POSTGRES_USER|POSTGRES_PASSWORD|APP_DB_USER|APP_DB_PASSWORD|REDIS_PASSWORD|JWT_SECRET|MONITOR_PASSWORD|MCP_ENABLED|DEEPSEEK_API_KEY|DASHSCOPE_API_KEY|AI_[A-Z0-9_]+|TENCENT_SMS_[A-Z0-9_]+|PARTICIPANT_SMS_ECHO_CODE|ALIYUN_CAPTCHA_[A-Z0-9_]+)=' })
    $taskGatewayLines = @(Get-Content -LiteralPath $taskEnv | Where-Object { $_ -match '^(DEEPSEEK_API_KEY|DASHSCOPE_API_KEY|AI_[A-Z0-9_]+)=' })
    [IO.File]::WriteAllText("$taskRoot/backend.env", ($taskBackendLines -join "`n") + "`n")
    [IO.File]::WriteAllText("$taskRoot/gateway.env", ($taskGatewayLines -join "`n") + "`n")
}
Import-DockerEnvironment
Assert-DockerOwnership
$taskCompose = @('compose','--project-name','aisports-dev-docker','--env-file',$taskEnv,'-f',(Join-Path $WorkspaceRoot 'docker-compose.full.yml'))
