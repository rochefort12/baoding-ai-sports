#requires -Version 7.0
<# Recover only the human-provided credential from this task's approved implementation prompt.
   The value never enters command arguments, stdout, a source file or a browser. #>
[CmdletBinding()]param()
$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
$taskConversation='C:/Users/ADMIN/.codex/sessions/2026/10/10/rollout-2026-10-10T11-02-49-01a123c3-633c-7320-af32-abb0269c270c.jsonl'
$taskId='01a123c3-633c-7320-af32-abb0269c270c'
$taskSecretDir=Join-Path $taskRoot '.local/secrets'
$taskSecretFile=Join-Path $taskSecretDir 'deepseek.dpapi'
if(Test-Path -LiteralPath $taskSecretFile){Write-Host 'Protected credential already exists; it was not replaced.';return}
if(!(Test-Path -LiteralPath $taskConversation)){throw 'The approved conversation source is unavailable.'}
$taskHeader=(Get-Content -LiteralPath $taskConversation -TotalCount 1)|ConvertFrom-Json
if($taskHeader.type-ne 'session_meta' -or $taskHeader.payload.id-ne $taskId){throw 'Conversation identity does not match this task.'}
$taskCandidates=[Collections.Generic.HashSet[string]]::new()
$taskStream=[IO.FileStream]::new($taskConversation,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
$taskReader=[IO.StreamReader]::new($taskStream)
try{while(($taskLine=$taskReader.ReadLine())-ne $null){
    try{$taskItem=$taskLine|ConvertFrom-Json -Depth 80}catch{continue}
    $taskPrompt=$null
    if($taskItem.type-eq 'event_msg' -and $taskItem.payload.type-eq 'user_message'){$taskPrompt=$taskItem.payload.message}
    if($taskItem.type-eq 'response_item' -and $taskItem.payload.type-eq 'message' -and $taskItem.payload.role-eq 'user'){
        $taskPrompt=($taskItem.payload.content|Where-Object type -in @('input_text','text')|ForEach-Object text)-join "`n"
    }
    if($taskPrompt -is [string] -and $taskPrompt.Contains('我都确认了') -and $taskPrompt.Contains('大模型是')){
        $taskMatch=[regex]::Match($taskPrompt,'(?i)key\s+(sk-[a-z0-9]{24,})')
        if($taskMatch.Success){[void]$taskCandidates.Add($taskMatch.Groups[1].Value)}
    }
}}finally{$taskReader.Dispose();$taskStream.Dispose()}
if($taskCandidates.Count-ne 1){throw 'A single explicit human-provided model credential was not found; nothing was saved.'}
New-Item -ItemType Directory -Force -Path $taskSecretDir|Out-Null
$taskSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls $taskSecretDir /inheritance:r /grant:r "*${taskSid}:(OI)(CI)F" '*S-1-5-18:(OI)(CI)F'|Out-Null
if($LASTEXITCODE-ne 0){throw 'Unable to protect credential directory.'}
$taskSecure=ConvertTo-SecureString ([string]($taskCandidates|Select-Object -First 1)) -AsPlainText -Force
try{[IO.File]::WriteAllText($taskSecretFile,(ConvertFrom-SecureString $taskSecure),[Text.UTF8Encoding]::new($false))}
finally{$taskSecure.Dispose();$taskCandidates.Clear();$taskPrompt=$null;$taskMatch=$null}
Write-Host 'Previously authorized model credential recovered into the protected local store.'
