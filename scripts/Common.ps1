#requires -Version 7.0
$ErrorActionPreference = 'Stop'
$WorkspaceRoot = Split-Path $PSScriptRoot -Parent
function Get-DockerCommand {
    $dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
    if ($dockerCommand) { return $dockerCommand.Source }
    foreach ($candidate in @("$env:LOCALAPPDATA/Programs/DockerDesktop/resources/bin/docker.exe", "$env:ProgramFiles/Docker/Docker/resources/bin/docker.exe")) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    throw 'Docker CLI is unavailable. Install or start Docker Desktop.'
}
function Import-LocalEnvironment {
    $envPath = Join-Path $WorkspaceRoot '.env'
    if (!(Test-Path -LiteralPath $envPath)) { throw 'Run Initialize-Environment.ps1 first.' }
    foreach ($line in Get-Content -LiteralPath $envPath) {
        if ($line -match '^([A-Z][A-Z0-9_]*)=(.*)$') {
            [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
        }
    }
    $secretPath=Join-Path $WorkspaceRoot '.local/secrets/deepseek.dpapi'
    if(Test-Path -LiteralPath $secretPath){
        $protectedKey=ConvertTo-SecureString ([IO.File]::ReadAllText($secretPath))
        $keyPointer=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($protectedKey)
        try{$env:DEEPSEEK_API_KEY=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPointer)}
        finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPointer);$protectedKey.Dispose()}
    }
}
function Assert-NativeExit([string]$Action) {
    if ($LASTEXITCODE -ne 0) { throw "$Action failed, exit code $LASTEXITCODE" }
}
