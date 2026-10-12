#requires -Version 7.0
$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
$taskOut=Join-Path $taskRoot ('.local/team-invite-experience-20261012/return-to-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskOut|Out-Null
$taskNode='D:/dev/nodejs'
$taskPnpm='C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/pnpm.cmd'
$taskOldPath=$env:PATH
$taskReceipt=@{at=[DateTimeOffset]::Now.ToString('o');passed=$false;scope='Focused safe return target unit tests, not actual login, SMS or team membership acceptance';sources=@()}
try{
 $env:PATH="$taskNode;$taskOldPath"
 foreach($taskFile in @('plus-ui/src/utils/returnTo.ts','plus-ui/src/utils/returnTo.spec.ts')){$taskReceipt.sources+=@{path=$taskFile;sha256=(Get-FileHash -LiteralPath (Join-Path $taskRoot $taskFile)).Hash.ToLowerInvariant()}}
 Push-Location (Join-Path $taskRoot 'plus-ui')
 try{& $taskPnpm exec vitest run src/utils/returnTo.spec.ts *> (Join-Path $taskOut 'tests.log');if($LASTEXITCODE -ne 0){throw 'Return-to unit tests failed; preserve log'}}finally{Pop-Location}
 $taskReceipt.passed=$true
}catch{$taskReceipt.failure=$_.Exception.Message;throw}finally{
 $env:PATH=$taskOldPath
 $taskReceipt|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $taskOut 'receipt.json') -Encoding utf8
 Write-Host ('Evidence: '+$taskOut)
}
