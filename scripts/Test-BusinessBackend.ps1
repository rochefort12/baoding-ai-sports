#requires -Version 7.0
<# .SYNOPSIS 运行资金明细边界与既有收费规则单测；使用模拟依赖，不接数据库。 #>
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
Push-Location (Join-Path $taskRoot 'backend')
try {
    # 单独模块运行：父项目有分组配置而纯契约模块没有 JUnit 引擎；先刷新契约缓存。
    & mvn '-Plocal' '-pl' 'aisports-api' '-DskipTests' 'install'
    if($LASTEXITCODE -ne 0){throw 'API cache build failed.'}
    & mvn '-Plocal' '-pl' 'aisports-domains/d06/aisports-table-fee-obligation' '-DskipTests=false' '-Dtest=FundRecordsTest,FeeRulesTest,ManualFundsTest' 'test'
    if($LASTEXITCODE -ne 0){throw 'Business backend tests failed.'}
    & mvn '-Plocal' '-pl' 'aisports-domains/d09/aisports-table-match' '-DskipTests=false' '-Dtest=CompetitionRulesTest' 'test'
    if($LASTEXITCODE -ne 0){throw 'Competition rules tests failed.'}
} finally {Pop-Location}
