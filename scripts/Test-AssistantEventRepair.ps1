#requires -Version 7.0
[CmdletBinding()]param([switch]$Build,[switch]$Live,[switch]$Continuity,[switch]$ReadOnly,[string]$ResumeReceipt)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Common.ps1"
$taskOut=Join-Path $WorkspaceRoot ('.local/assistant-event-repair-20261012/'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskOut -Force|Out-Null
$taskReceipt=@{at=[DateTimeOffset]::Now.ToString('o');scope='Current assistant/event repair; isolated synthetic business only';passed=$false;checks=@()}
function Read-BackendSnapshot {
    @(Get-ChildItem -LiteralPath "$WorkspaceRoot/backend","$WorkspaceRoot/ai-gateway" -File -Recurse |
        Where-Object { $_.FullName -notmatch '[\\/](target|node_modules|\.local)[\\/]' -and ($_.Extension -in '.java','.mjs','.xml','.yml','.yaml' -or $_.Name -eq 'package.json') } |
        Sort-Object FullName | ForEach-Object { @{path=[IO.Path]::GetRelativePath($WorkspaceRoot,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()} })
}
try {
    if($Build){
        $taskBefore=Read-BackendSnapshot
        $taskReceipt.sources=$taskBefore
        $taskFiles=@(Get-ChildItem -LiteralPath "$WorkspaceRoot/ai-gateway" -Filter '*.test.mjs'|ForEach-Object{$_.FullName})
        & node --test @taskFiles *> (Join-Path $taskOut 'gateway-tests.log');Assert-NativeExit 'Gateway tests'
        $taskReceipt.checks+='gateway tests'
        $env:JAVA_HOME='D:/dev/jdk17';$env:PATH=$env:JAVA_HOME+'/bin;'+$env:PATH
        $taskPackageName='ruoyi-admin-assistant-repair-'+[guid]::NewGuid().ToString('N')
        Push-Location "$WorkspaceRoot/backend"
        try{& mvn '-Plocal' '-pl' 'ruoyi-admin' '-am' '-DskipTests=false' ('-Daisports.package.name='+$taskPackageName) 'package' *> (Join-Path $taskOut 'maven-package.log');Assert-NativeExit 'Java tests and package'}finally{Pop-Location}
        $taskReceipt.checks+='Java tests and package'
        $taskAfter=Read-BackendSnapshot
        if(($taskBefore|ConvertTo-Json -Depth 4 -Compress) -ne ($taskAfter|ConvertTo-Json -Depth 4 -Compress)){throw 'Backend or gateway source changed during checks; evidence cannot bind final source.'}
        $taskReceipt.checks+='source unchanged during checks'
        $taskReceipt.package=@{path=(Join-Path $WorkspaceRoot ('backend/ruoyi-admin/target/'+$taskPackageName+'.jar'))}
        $taskReceipt.package.sha256=(Get-FileHash -LiteralPath $taskReceipt.package.path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    if($Live){
        Import-LocalEnvironment
        $env:AISPORTS_REGRESSION_CONTEXT=Join-Path $WorkspaceRoot '.local/business-regression-20261011/a006561dd66540c2b383415b02480f2c/context.private.json'
        $env:AISPORTS_ASSISTANT_REPAIR_OUT=$taskOut
        $env:AISPORTS_ASSISTANT_REPAIR_RESUME=$ResumeReceipt
        Push-Location $WorkspaceRoot
        try{if($ReadOnly){& node "$PSScriptRoot/Test-AssistantChatState.mjs" *> (Join-Path $taskOut 'live-tests.log')}elseif($Continuity){& node "$PSScriptRoot/Test-AssistantChatPublish.mjs" *> (Join-Path $taskOut 'live-tests.log')}else{& node "$PSScriptRoot/Test-AssistantEventRepair.mjs" *> (Join-Path $taskOut 'live-tests.log')};Assert-NativeExit 'Ordinary role document, inline form and actual business checks'}finally{Pop-Location}
        $taskReceipt.checks+='ordinary role HTTP and browser'
    }
    $taskReceipt.passed=$true
}finally{$taskReceipt.finishedAt=[DateTimeOffset]::Now.ToString('o');$taskReceipt.logs=@('gateway-tests.log','maven-package.log','live-tests.log')|Where-Object{Test-Path -LiteralPath (Join-Path $taskOut $_)}|ForEach-Object{@{file=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $taskOut $_) -Algorithm SHA256).Hash.ToLowerInvariant()}};$taskReceipt|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $taskOut 'receipt.json');Write-Output ('Assistant repair evidence: '+$taskOut)}
