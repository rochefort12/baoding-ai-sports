#requires -Version 7.0
<# .SYNOPSIS 隔离验证邀请通知，不连接数据库或短信渠道。 #>
$ErrorActionPreference='Stop'
Push-Location (Join-Path (Split-Path -Parent $PSScriptRoot) 'backend')
try {
    & mvn '-Plocal' '-pl' 'aisports-api' '-DskipTests' 'install'
    if($LASTEXITCODE -ne 0){throw 'Invitation API build failed.'}
    & mvn '-Plocal' '-pl' 'aisports-domains/d04/aisports-table-event' '-DskipTests=false' '-Dtest=InvitationNoticeTest' 'test'
    if($LASTEXITCODE -ne 0){throw 'Invitation notification verification failed.'}
    & mvn '-Plocal' '-pl' 'aisports-domains/d03/aisports-table-team' '-DskipTests=false' '-Dtest=InvitationAccessTest' 'test'
    if($LASTEXITCODE -ne 0){throw 'Invitation access verification failed.'}
} finally {Pop-Location}
