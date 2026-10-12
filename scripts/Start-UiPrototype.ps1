#requires -Version 7.0
<# .SYNOPSIS 启动 AI运动独立 UI 原型，只监听本机，不接业务后端。 #>
param([ValidateRange(1024,65535)][int]$Port=5188)
$ErrorActionPreference='Stop'
$prototypeRoot=Join-Path (Split-Path $PSScriptRoot -Parent) 'docs/05-ui/prototype'
$prototypeNode=Get-Command node -ErrorAction Stop
& $prototypeNode.Source (Join-Path $prototypeRoot 'serve.mjs') $Port
