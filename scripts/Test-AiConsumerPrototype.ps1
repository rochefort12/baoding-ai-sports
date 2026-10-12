#requires -Version 7.0
param([string]$Url='http://127.0.0.1:5192/consumer.html')
$ErrorActionPreference='Stop'
$runtime='C:/Users/zyt/.cache/codex-runtimes/codex-primary-runtime/dependencies/node'
& "$runtime/bin/node.exe" "$PSScriptRoot/Test-AiConsumerPrototype.mjs" "$runtime/node_modules" $Url
if($LASTEXITCODE -ne 0){throw 'C 端原型检查未通过'}
