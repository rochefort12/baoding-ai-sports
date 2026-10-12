#requires -Version 7.0
# Freeze the actual final frontend check; earlier reports are not overwritten.
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskNode = 'D:/dev/nodejs'
$taskPnpm = 'C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/pnpm.cmd'
if (!(Test-Path -LiteralPath "$taskNode/node.exe") -or !(Test-Path -LiteralPath $taskPnpm)) { throw 'Expected local frontend runtime is missing.' }
$taskOut = Join-Path $taskRoot ('.local/product-release-20261011/frontend-refinement-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskOut | Out-Null
function Read-SourceSnapshot {
    @(Get-ChildItem -LiteralPath (Join-Path $taskRoot 'plus-ui/src') -File -Recurse |
        Where-Object { $_.Extension -in '.vue','.ts','.scss','.css','.svg','.png','.webp','.json' -and $_.Name -notin 'auto-imports.d.ts','components.d.ts' } |
        Sort-Object FullName | ForEach-Object {
            @{path=[IO.Path]::GetRelativePath($taskRoot,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
        }) + @('plus-ui/index.html','plus-ui/package.json','plus-ui/pnpm-lock.yaml') | ForEach-Object {
            if ($_ -is [string]) { @{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $taskRoot $_) -Algorithm SHA256).Hash.ToLowerInvariant()} } else { $_ }
        }
}
function Read-AssetSnapshot {
    @(Get-ChildItem -LiteralPath (Join-Path $taskRoot 'plus-ui/public/images/sports') -File -Recurse |
        Sort-Object FullName | ForEach-Object {
            @{path=[IO.Path]::GetRelativePath($taskRoot,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
        })
}
$taskBefore = Read-SourceSnapshot
$taskAssetsBefore = Read-AssetSnapshot
$taskResult = @{passed=$false;at=[DateTimeOffset]::Now.ToString('o');scope='Final current frontend typecheck, tests, build and static assets; not real tournament or performance acceptance';sources=$taskBefore;assets=$taskAssetsBefore;checks=@();failures=@()}
$taskOldPath = $env:PATH
try {
    $env:PATH = "$taskNode;$taskOldPath"
    Push-Location (Join-Path $taskRoot 'plus-ui')
    try {
        & $taskPnpm run typecheck *> (Join-Path $taskOut 'typecheck.log')
        if ($LASTEXITCODE -ne 0) { throw 'Frontend typecheck failed; log preserved.' }
        $taskResult.checks += 'typecheck'
        & $taskPnpm exec vitest run *> (Join-Path $taskOut 'tests.log')
        if ($LASTEXITCODE -ne 0) { throw 'Frontend business utility tests failed; log preserved.' }
        $taskResult.checks += 'frontend utility tests'
        & $taskPnpm run build:dev *> (Join-Path $taskOut 'build.log')
        if ($LASTEXITCODE -ne 0) { throw 'Frontend build failed; log preserved.' }
        $taskResult.checks += 'build:dev'
    } finally { Pop-Location }
    $taskAfter = Read-SourceSnapshot
    if (($taskBefore | ConvertTo-Json -Depth 4 -Compress) -ne ($taskAfter | ConvertTo-Json -Depth 4 -Compress)) { throw 'Source changed during frontend verification; results cannot bind the final source.' }
    $taskAssetsAfter = Read-AssetSnapshot
    if (($taskAssetsBefore | ConvertTo-Json -Depth 4 -Compress) -ne ($taskAssetsAfter | ConvertTo-Json -Depth 4 -Compress)) { throw 'Static assets changed during frontend verification.' }
    $taskResult.checks += 'source unchanged during checks'
    $taskRuntimePath = Join-Path $taskRoot '.local/phase1-implementation/verification-runtime.json'
    $taskRuntime = Get-Content -LiteralPath $taskRuntimePath -Raw | ConvertFrom-Json
    if ($taskRuntime.port -ne 8082 -or $taskRuntime.database -notmatch '^aisports_verify_phase1_[a-f0-9]{32}$') { throw 'Frontend evidence must bind the isolated candidate runtime.' }
    $taskResult.jarSha256 = (Get-FileHash -LiteralPath $taskRuntime.jarPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($taskResult.jarSha256 -ne $taskRuntime.jarSHA256) { throw 'Candidate runtime package bytes differ from its recorded SHA256.' }
    $taskResult.runtimeSha256 = (Get-FileHash -LiteralPath $taskRuntimePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $taskResult.jarBinding = 'Actual immutable candidate package bytes and its runtime record; live health is verified separately.'
    $taskResult.largeChunkWarning = [bool](Select-String -LiteralPath (Join-Path $taskOut 'build.log') -Pattern 'chunks are larger than' -Quiet)
    $taskResult.passed = $true
} catch {
    $taskResult.failures += $_.Exception.Message
    throw
} finally {
    $env:PATH = $taskOldPath
    $taskResult.finishedAt = [DateTimeOffset]::Now.ToString('o')
    $taskResult.logs = @('typecheck.log','tests.log','build.log') | Where-Object { Test-Path -LiteralPath (Join-Path $taskOut $_) } | ForEach-Object { @{file=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $taskOut $_) -Algorithm SHA256).Hash.ToLowerInvariant()} }
    [IO.File]::WriteAllText((Join-Path $taskOut 'receipt.json'),($taskResult | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    Write-Output ('Frontend evidence: ' + [IO.Path]::GetRelativePath($taskRoot,$taskOut))
}
