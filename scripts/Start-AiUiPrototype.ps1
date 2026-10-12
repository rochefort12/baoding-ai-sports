#requires -Version 7.0
<# .SYNOPSIS 启动独立 AI UI 原型，仅监听本机，不接业务后端。 #>
param(
 [ValidateRange(1024,65535)][int]$Port=5192,
 [string]$NodeExecutable=(Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe')
)
$ErrorActionPreference='Stop'
if (!(Test-Path -LiteralPath $NodeExecutable)) { $NodeExecutable=(Get-Command node -ErrorAction Stop).Source }
$prototypeRoot=Join-Path (Split-Path $PSScriptRoot -Parent) 'docs/05-ui/ai-native/prototype'
& $NodeExecutable (Join-Path $prototypeRoot 'serve.mjs') $Port
if ($LASTEXITCODE -ne 0) { throw 'AI UI prototype server failed.' }
