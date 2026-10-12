#requires -Version 7.0
<# The value is typed into a masked local prompt, never a command argument or repository file. #>
[CmdletBinding()] param()
$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
$secretDir=Join-Path $taskRoot '.local/secrets'
New-Item -ItemType Directory -Force -Path $secretDir | Out-Null
$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls $secretDir /inheritance:r /grant:r "*${sid}:(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' | Out-Null
if($LASTEXITCODE-ne 0){throw 'Unable to protect local credential directory'}
$secure=Read-Host 'DeepSeek API Key（输入隐藏，仅本机账户可解密）' -AsSecureString
if($secure.Length-lt 16){throw 'Key is missing or too short'}
$cipher=ConvertFrom-SecureString -SecureString $secure
[IO.File]::WriteAllText((Join-Path $secretDir 'deepseek.dpapi'),$cipher,[Text.UTF8Encoding]::new($false))
$secure.Dispose()
Write-Host 'DeepSeek credential saved to the protected local store. Restart the AI gateway and backend to activate.'
