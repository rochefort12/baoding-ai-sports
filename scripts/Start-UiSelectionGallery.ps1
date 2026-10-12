#requires -Version 7.0
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
$demoRoot=Join-Path $WorkspaceRoot '.local/demo-20261011'
$scriptPath=Join-Path $PSScriptRoot 'Serve-UiSelectionGallery.mjs'
$receiptPath=Join-Path $demoRoot 'gallery-runtime.json'
$listener=Get-NetTCPConnection -State Listen -LocalPort 5193 -ErrorAction SilentlyContinue
if($listener){
    if(Test-Path -LiteralPath $receiptPath){$saved=Get-Content -LiteralPath $receiptPath -Raw|ConvertFrom-Json;$processInfo=Get-CimInstance Win32_Process -Filter "ProcessId=$($saved.pid)";if($listener.OwningProcess -eq $saved.pid -and $processInfo.CommandLine.Contains($scriptPath)){Write-Output 'UI selection gallery already running.';return}}
    throw 'Gallery port belongs to an unverified process.'
}
$process=Start-Process -FilePath 'D:/dev/nodejs/node.exe' -ArgumentList @('"'+$scriptPath+'"') -WorkingDirectory $WorkspaceRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $demoRoot 'gallery.out.log') -RedirectStandardError (Join-Path $demoRoot 'gallery.err.log')
[pscustomobject]@{pid=$process.Id;port=5193;script=$scriptPath;createdAt=[DateTimeOffset]::Now.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath $receiptPath -Encoding utf8
Write-Output 'UI selection gallery starting at http://127.0.0.1:5193.'
