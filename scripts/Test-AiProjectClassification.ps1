#requires -Version 7.0
param(
    [Parameter(Mandatory)][string]$TableImage,
    [string]$Output = '.local/project-classification-live.json',
    [string]$Cases = ''
)
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
& node "$PSScriptRoot/Test-AiProjectClassification.mjs" $TableImage $Output $Cases
Assert-NativeExit 'Live project classification evaluation'
