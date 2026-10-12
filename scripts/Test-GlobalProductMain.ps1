#requires -Version 7.0
param([switch]$LoginOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$secret=ConvertTo-SecureString ([IO.File]::ReadAllText((Join-Path $WorkspaceRoot '.local/main-access/administrator.dpapi')).Trim());$pointer=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
try{$packet=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)|ConvertFrom-Json}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer);$secret.Dispose()}
if($packet.username-ne 'admin' -or $packet.baseUri-ne 'http://127.0.0.1:8080'){throw 'Protected main identity changed'}
$previousToken=[Environment]::GetEnvironmentVariable('AISPORTS_MAIN_ADMIN_TOKEN','Process');$previousPassword=[Environment]::GetEnvironmentVariable('AISPORTS_MAIN_ADMIN_PASSWORD','Process')
try{$env:AISPORTS_MAIN_ADMIN_TOKEN=$packet.token;$env:AISPORTS_MAIN_ADMIN_PASSWORD=$packet.password;$testArgs=@();if($LoginOnly){$testArgs+='--login-only'};& 'D:/dev/nodejs/node.exe' "$PSScriptRoot/Test-GlobalProductMain.mjs" @testArgs;Assert-NativeExit 'Main post-release verification'}finally{[Environment]::SetEnvironmentVariable('AISPORTS_MAIN_ADMIN_TOKEN',$previousToken,'Process');[Environment]::SetEnvironmentVariable('AISPORTS_MAIN_ADMIN_PASSWORD',$previousPassword,'Process');$packet=$null}
