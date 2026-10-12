#requires -Version 7.0
[CmdletBinding()]param([string]$ResumeReceipt)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$env:AISPORTS_REGRESSION_CONTEXT=Join-Path $WorkspaceRoot '.local/business-regression-20261011/a006561dd66540c2b383415b02480f2c/context.private.json'
$env:AISPORTS_CHAT_RESUME=$ResumeReceipt
& node "$PSScriptRoot/Test-ChatDraftContinuity.mjs"
Assert-NativeExit 'New synthetic Word candidate and ordinary organizer UI flow'
if(!$ResumeReceipt){
    & node "$PSScriptRoot/Test-CombinedDraftReply.mjs"
    Assert-NativeExit 'Actual model combined answers and following question'
}
