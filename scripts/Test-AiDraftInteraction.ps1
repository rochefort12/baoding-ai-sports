#requires -Version 7.0
param([string]$ResumeReceiptPath)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$env:AISPORTS_REGRESSION_CONTEXT=Join-Path $WorkspaceRoot '.local/business-regression-20261011/a006561dd66540c2b383415b02480f2c/context.private.json'
if($ResumeReceiptPath){$env:AISPORTS_DRAFT_RESUME=$ResumeReceiptPath}else{Remove-Item Env:AISPORTS_DRAFT_RESUME -ErrorAction SilentlyContinue}
& node "$WorkspaceRoot/scripts/Test-AiDraftInteraction.mjs"
Assert-NativeExit 'Ordinary organizer candidate form, source image and draft confirmation'
