#requires -Version 7.0
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
$taskRoot=Join-Path $WorkspaceRoot 'docs/04-verification/notice-fixtures-20261012'
$taskEntries=@(
 @{from='.local/notice-trial-20261012/qa/01-测试收费双打通知-1.png';name='08-测试通知图片.png';derivedFrom='01-测试收费双打通知.pdf';kind='rendered-image'},
 @{from='.local/notice-trial-20261012/six-scanned-annexes.pdf';name='09-测试六页扫描附件.pdf';derivedFrom='01 through 06';kind='six-image-only-pages'}
)
foreach($taskEntry in $taskEntries){
 $taskSource=Join-Path $WorkspaceRoot $taskEntry.from
 $taskTarget=Join-Path $taskRoot $taskEntry.name
 if(Test-Path -LiteralPath $taskTarget){if((Get-FileHash -LiteralPath $taskTarget).Hash -ne (Get-FileHash -LiteralPath $taskSource).Hash){throw 'Existing derivative differs'}}else{Copy-Item -LiteralPath $taskSource -Destination $taskTarget}
 $taskEntry.sha256=(Get-FileHash -LiteralPath $taskTarget -Algorithm SHA256).Hash.ToLowerInvariant()
}
$taskExtra=Join-Path $taskRoot 'extra-manifest.json'
if(!(Test-Path -LiteralPath $taskExtra)){@{at=[DateTimeOffset]::Now.ToString('o');files=$taskEntries;visualQa='Seven original pages and all six scan pages rendered and inspected; PNG is the inspected first original page';officialAttachmentsDownloaded=$false} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $taskExtra -Encoding utf8}
$taskArchive=Join-Path $WorkspaceRoot 'docs/04-verification/办赛通知测试资料-20261012.zip'
if(Test-Path -LiteralPath $taskArchive){throw 'Immutable notice archive already exists'}
Compress-Archive -LiteralPath (Get-ChildItem -LiteralPath $taskRoot -File | Select-Object -ExpandProperty FullName) -DestinationPath $taskArchive
Write-Output ('Notice package SHA256: '+(Get-FileHash -LiteralPath $taskArchive).Hash.ToLowerInvariant())
