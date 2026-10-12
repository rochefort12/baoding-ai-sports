#requires -Version 7.0
param([string]$Url='http://127.0.0.1:5192/ai-workbench.html')
$runtime='C:/Users/zyt/.cache/codex-runtimes/codex-primary-runtime/dependencies/node'
& "$runtime/bin/node.exe" "$PSScriptRoot/Test-AiUiPrototype.mjs" "$runtime/node_modules" $Url
if($LASTEXITCODE -ne 0){throw '原型交互检查未通过'}
