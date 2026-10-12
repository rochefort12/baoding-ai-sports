#requires -Version 7.0
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$env:AISPORTS_REGRESSION_CONTEXT=Join-Path $WorkspaceRoot '.local/business-regression-20261011/a006561dd66540c2b383415b02480f2c/context.private.json'
& node "$PSScriptRoot/Test-DocumentDraftPrices.mjs"
Assert-NativeExit 'Actual Word document price interpretation'
