#requires -Version 7.0
$ErrorActionPreference='Stop'
$workspace=Split-Path $PSScriptRoot -Parent
$secret=ConvertTo-SecureString ([IO.File]::ReadAllText((Join-Path $workspace '.local/main-access/administrator.dpapi')).Trim());$pointer=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
try{$packet=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)|ConvertFrom-Json}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer);$secret.Dispose()}
if($packet.username-ne 'admin' -or $packet.baseUri-ne 'http://127.0.0.1:8080'){throw 'Protected main identity changed'}
$previousToken=[Environment]::GetEnvironmentVariable('AISPORTS_MAIN_ADMIN_TOKEN','Process')
try{$env:AISPORTS_MAIN_ADMIN_TOKEN=$packet.token;& 'D:/dev/nodejs/node.exe' "$PSScriptRoot/Test-HonorReviewUi.mjs";if($LASTEXITCODE-ne 0){throw 'Honor review browser inspection failed; immutable evidence retained'}}finally{[Environment]::SetEnvironmentVariable('AISPORTS_MAIN_ADMIN_TOKEN',$previousToken,'Process');$packet=$null}
