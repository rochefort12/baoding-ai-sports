#requires -Version 7.0
param([Parameter(Mandatory)][string]$UiReceipt,[Parameter(Mandatory)][string]$FrontendReceipt)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
function Get-ArtifactRef([string]$file) {
    $target = if ([IO.Path]::IsPathRooted($file)) { $file } else { Join-Path $taskRoot $file }
    $absolute = (Resolve-Path -LiteralPath $target).Path
    $relative = [IO.Path]::GetRelativePath($taskRoot,$absolute).Replace('\','/')
    if ($relative.StartsWith('../') -or [IO.Path]::IsPathRooted($relative)) { throw 'Evidence must remain inside this workspace.' }
    @{path=$relative;sha256=(Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash.ToLowerInvariant()}
}
function Assert-Hash([string]$file,[string]$expected) {
    $ref = Get-ArtifactRef $file
    if ($ref.sha256 -ne $expected) { throw ('Artifact bytes changed: ' + $ref.path) }
    $ref
}
$taskUiRef = Get-ArtifactRef $UiReceipt
$taskFrontRef = Get-ArtifactRef $FrontendReceipt
$taskUi = Get-Content -LiteralPath (Join-Path $taskRoot $taskUiRef.path) -Raw | ConvertFrom-Json
$taskFront = Get-Content -LiteralPath (Join-Path $taskRoot $taskFrontRef.path) -Raw | ConvertFrom-Json
if (!$taskUi.passed -or !$taskFront.passed -or $taskUi.blockedWrites.Count -ne 0 -or $taskUi.errors.Count -ne 0) { throw 'Final UI and frontend checks must pass with zero business write attempts or script errors.' }
if (@($taskUi.checks | Where-Object {!$_.passed}).Count -ne 0) { throw 'Failed UI checks cannot be accepted.' }
if (($taskUi.storedBefore | ConvertTo-Json -Compress) -ne ($taskUi.storedAfter | ConvertTo-Json -Compress)) { throw 'Original candidate or materials changed.' }
$taskSource = @($taskFront.sources | ForEach-Object { Assert-Hash $_.path $_.sha256 })
$taskAssets = @($taskFront.assets | ForEach-Object { Assert-Hash $_.path $_.sha256 })
foreach ($property in $taskUi.sourceBefore.PSObject.Properties) {
    Assert-Hash $property.Name $property.Value | Out-Null
    if ($taskUi.sourceAfter.($property.Name) -ne $property.Value) { throw 'UI source changed during observation.' }
}
$taskUiDir = Split-Path $taskUiRef.path -Parent
$taskShots = @($taskUi.screenshots | ForEach-Object { Assert-Hash (Join-Path $taskUiDir $_.file) $_.sha256 })
$taskVisualRef = Get-ArtifactRef (Join-Path $taskUiDir 'visual-review.json')
$taskVisual = Get-Content -LiteralPath (Join-Path $taskRoot $taskVisualRef.path) -Raw | ConvertFrom-Json
if (!$taskVisual.visualAccepted -or !$taskVisual.automatedPassed) { throw 'Final screenshots need an explicit visual acceptance.' }
$taskRuntimeRef = Get-ArtifactRef '.local/phase1-implementation/verification-runtime.json'
$taskRuntime = Get-Content -LiteralPath (Join-Path $taskRoot $taskRuntimeRef.path) -Raw | ConvertFrom-Json
if ($taskRuntime.port -ne 8082 -or $taskRuntime.database -ne 'aisports_verify_phase1_242ded43673246699be6bb0f596aa59b') { throw 'Unexpected runtime scope.' }
$taskJar = Get-ArtifactRef $taskRuntime.jarPath
if ($taskJar.sha256 -ne $taskRuntime.jarSHA256 -or $taskJar.sha256 -ne $taskUi.jarSha256 -or $taskJar.sha256 -ne $taskFront.jarSha256) { throw 'Runtime package binding differs.' }
$taskListeners = @(Get-NetTCPConnection -State Listen | Where-Object LocalPort -in 8080,5190,8082,8091,5192)
if (@($taskListeners | Where-Object LocalPort -in 8080,5190).Count -gt 0) { throw 'Main runtime unexpectedly listens.' }
if (@($taskListeners | Where-Object LocalAddress -ne '127.0.0.1').Count -gt 0) { throw 'Application is exposed outside loopback.' }
foreach ($port in 8082,8091,5192) { if (@($taskListeners | Where-Object LocalPort -eq $port).Count -ne 1) { throw 'Expected local runtime listener missing.' } }
$taskJavaPid = ($taskListeners | Where-Object LocalPort -eq 8082).OwningProcess
$taskJava = Get-CimInstance Win32_Process -Filter "ProcessId=$taskJavaPid"
if (!$taskJava.CommandLine.Replace('\','/').Contains($taskRuntime.jarPath.Replace('\','/'),[StringComparison]::OrdinalIgnoreCase)) { throw 'Live Java process does not use the recorded candidate package.' }
$taskPrevious = @(
    Assert-Hash 'docs/04-verification/队伍邀请场次与体验修复验证-20261012.json' '6b7ec11f4db3c27d9a609bc9fd9fa973953c6d1ad4394029aa1897f4fafbf06d'
    Assert-Hash 'docs/04-verification/奖项材料与队伍报名修复验证-20261012.json' 'f16dfda1da798b604e0f053acd50f33239645a2d5ec0236d2821770e7e93f3da'
)
$taskHistory = @(
    '.local/assistant-action-rail-20261012/6dc14c4e-d617-4351-b060-d8178a0e21db/receipt.json',
    '.local/assistant-action-rail-20261012/f6f2f2de-925b-4c62-8c12-ae87ee33f282/receipt.json',
    '.local/assistant-action-rail-20261012/f6f2f2de-925b-4c62-8c12-ae87ee33f282/visual-review.json',
    '.local/product-release-20261011/frontend-refinement-2a36dbfd61314b58b40e3f5f0f2af742/receipt.json'
) | ForEach-Object { Get-ArtifactRef $_ }
$taskIndex = @{at=[DateTimeOffset]::Now.ToString('o');passed=$true;scope='Assistant button layout and gestures only; existing ordinary-role candidate, no business/model writes';ui=$taskUiRef;frontend=$taskFrontRef;visual=$taskVisualRef;sources=$taskSource;assets=$taskAssets;screenshots=$taskShots;runtime=$taskRuntimeRef;package=$taskJar;livePorts=@($taskListeners | Select-Object LocalAddress,LocalPort,OwningProcess);mainOff=$true;originalCandidate=$taskUi.storedAfter;checks=$taskUi.checks.Count;boundaries=$taskUi.boundaries;previousIndexes=$taskPrevious;retainedHistory=$taskHistory;report=(Get-ArtifactRef 'docs/04-verification/助手按钮横向交互验证-20261012.md');scripts=@((Get-ArtifactRef 'scripts/Test-AssistantActionRailUi.mjs'),(Get-ArtifactRef 'scripts/Freeze-AssistantActionRailEvidence.ps1'))}
$taskTarget = Join-Path $taskRoot 'docs/04-verification/助手按钮横向交互验证-20261012.json'
if (Test-Path -LiteralPath $taskTarget) { throw 'Existing acceptance index must not be overwritten.' }
$taskTemporary = $taskTarget + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
$taskBytes = [Text.UTF8Encoding]::new($false).GetBytes(($taskIndex | ConvertTo-Json -Depth 9))
$taskStream = [IO.File]::Open($taskTemporary,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try { $taskStream.Write($taskBytes); $taskStream.Flush($true) } finally { $taskStream.Dispose() }
[IO.File]::Move($taskTemporary,$taskTarget)
Write-Output ([pscustomobject]@{passed=$true;checks=$taskUi.checks.Count;screenshots=$taskShots.Count;index=[IO.Path]::GetRelativePath($taskRoot,$taskTarget);sha256=(Get-FileHash -LiteralPath $taskTarget -Algorithm SHA256).Hash.ToLowerInvariant()} | ConvertTo-Json -Compress)
