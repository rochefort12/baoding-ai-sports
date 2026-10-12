#requires -Version 7.0
[CmdletBinding()]param()
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$jar=Join-Path $WorkspaceRoot 'backend/ruoyi-admin/target/ruoyi-admin.jar'
$taskPid=[int]([IO.File]::ReadAllText((Join-Path $WorkspaceRoot '.local/backend.pid')).Trim());$process=Get-CimInstance Win32_Process -Filter "ProcessId=$taskPid"
if(!$process -or !([string]$process.CommandLine).Replace('/','\').Contains($jar.Replace('/','\'),[StringComparison]::OrdinalIgnoreCase)){throw 'Main process ownership changed'}
$listeners=@(Get-NetTCPConnection -State Listen -LocalPort 8080);if(!$listeners.Count -or @($listeners|Where-Object {$_.OwningProcess-ne $taskPid -or $_.LocalAddress-ne '127.0.0.1'}).Count){throw 'Main listener boundary changed'}
$secret=ConvertTo-SecureString ([IO.File]::ReadAllText((Join-Path $WorkspaceRoot '.local/main-access/administrator.dpapi')).Trim());$pointer=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
try{$packet=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)|ConvertFrom-Json}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer);$secret.Dispose()}
if($packet.username-ne 'admin' -or $packet.baseUri-ne 'http://127.0.0.1:8080'){throw 'Protected credential identity changed'}
$previous=[Environment]::GetEnvironmentVariable('AISPORTS_MAIN_ADMIN_TOKEN','Process')
try{$env:AISPORTS_MAIN_ADMIN_TOKEN=$packet.token;& 'D:/dev/nodejs/node.exe' "$PSScriptRoot/Release-GlobalProductMain.mjs";Assert-NativeExit 'Current main product activation'}finally{[Environment]::SetEnvironmentVariable('AISPORTS_MAIN_ADMIN_TOKEN',$previous,'Process');$packet=$null}
