#requires -Version 7.0
[CmdletBinding()]
param([switch]$IncludeBackend)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
Push-Location $taskRoot
try {
    & node --test 'ai-gateway/dialogue-price.test.mjs' 'ai-gateway/source-form.test.mjs'
    if ($LASTEXITCODE -ne 0) { throw 'AI draft quotation and source form tests failed.' }
    if ($IncludeBackend) {
        Push-Location (Join-Path $taskRoot 'backend')
        try {
            & mvn '-Plocal' '-pl' 'aisports-domains/d04/aisports-table-event' '-DskipTests=false' '-Dtest=DraftAnswerContinuityTest,DraftChoicesTest,AiPricedConfirmationTest' 'test'
            if ($LASTEXITCODE -ne 0) { throw 'AI draft completion backend tests failed.' }
        } finally { Pop-Location }
    }
} finally { Pop-Location }
