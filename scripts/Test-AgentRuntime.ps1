#requires -Version 7.0
[CmdletBinding()]param([switch]$GatewayOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
$taskId=[guid]::NewGuid().ToString('N')
$taskOut=Join-Path $WorkspaceRoot ('.local/agent-runtime-20261012/build-'+$taskId)
New-Item -ItemType Directory -Path $taskOut | Out-Null
$taskReceipt=@{at=[DateTimeOffset]::Now.ToString('o');passed=$false;scope='Offline gateway tests and full local Java compile/tests; no model, runtime or database acceptance';checks=@();failures=@()}
function Read-AgentSourceManifest {
 $taskInputs=@(& rg --files "$WorkspaceRoot/ai-gateway");if(!$GatewayOnly){$taskInputs+=@(& rg --files "$WorkspaceRoot/backend" | Where-Object {$_ -match '\\src\\(main|test)\\|\\pom\.xml$' -and $_ -notmatch '\\target\\'})}
 return @($taskInputs|Sort-Object|ForEach-Object{@{path=$_.Substring($WorkspaceRoot.Length+1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant()}})
}
$taskSources=Read-AgentSourceManifest
try {
 & node --test --test-reporter=spec "$WorkspaceRoot/ai-gateway/agent.test.mjs" "$WorkspaceRoot/ai-gateway/agent-material.test.mjs" "$WorkspaceRoot/ai-gateway/kernel.test.mjs" "$WorkspaceRoot/ai-gateway/source-price.test.mjs" "$WorkspaceRoot/ai-gateway/source-evidence.test.mjs" "$WorkspaceRoot/ai-gateway/source-form.test.mjs" "$WorkspaceRoot/ai-gateway/material-reader.test.mjs" "$WorkspaceRoot/ai-gateway/materials.test.mjs" "$WorkspaceRoot/ai-gateway/visual.test.mjs" "$WorkspaceRoot/ai-gateway/runtime.test.mjs" "$WorkspaceRoot/ai-gateway/presentation.test.mjs" *> (Join-Path $taskOut 'gateway-tests.log')
 Assert-NativeExit 'Agent gateway tests'
 $taskReceipt.checks+='gateway tests'
 if(!$GatewayOnly){
  $env:JAVA_HOME='D:/dev/jdk17';$env:PATH=$env:JAVA_HOME+'/bin;'+$env:PATH
  Push-Location "$WorkspaceRoot/backend"
  try { & mvn '-Plocal' '-pl' 'ruoyi-admin' '-am' '-DskipTests=false' ('-Daisports.package.name=ruoyi-admin-agent-runtime-'+$taskId) 'package' *> (Join-Path $taskOut 'maven-package.log');Assert-NativeExit 'Agent full Java tests/build' } finally { Pop-Location }
  $taskJar=Join-Path $WorkspaceRoot ('backend/ruoyi-admin/target/ruoyi-admin-agent-runtime-'+$taskId+'.jar')
  if(!(Test-Path -LiteralPath $taskJar)){throw 'Named package missing'}
  $taskReceipt.jarPath=$taskJar;$taskReceipt.jarSha256=(Get-FileHash -LiteralPath $taskJar -Algorithm SHA256).Hash.ToLowerInvariant();$taskReceipt.checks+='full local Java tests/build'
 }
 if((ConvertTo-Json $taskSources -Depth 4 -Compress) -ne (ConvertTo-Json (Read-AgentSourceManifest) -Depth 4 -Compress)){throw 'Agent sources changed during checks; preserve evidence and build again.'}
 $taskReceipt.sources=$taskSources;$taskReceipt.checks+='source unchanged during checks';$taskReceipt.passed=$true
}catch{$taskReceipt.failures+=$_.Exception.Message;throw}finally{$taskReceipt|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $taskOut 'receipt.json') -Encoding utf8;Write-Host ('Evidence: '+$taskOut)}
