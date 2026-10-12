#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^1[3-9]\d{9}$')][string]$Phone,
    [Parameter(Mandatory)][switch]$SendRealSms,
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$MavenCommand = 'mvn'
)
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
if (!$SendRealSms) { throw 'This external test requires explicit real SMS authorization.' }
if ($JavaHome) { $env:JAVA_HOME = $JavaHome; $env:PATH = "$JavaHome/bin;$env:PATH" }
# 调用实际服务适配器一次，默认测试不执行；不打印号码、验证码或凭据，不创建账号。
New-Item -ItemType Directory -Path "$WorkspaceRoot/.local" -Force | Out-Null
try {
    $env:TENCENT_SMS_TEST_PHONE = $Phone
    $env:TENCENT_SMS_SEND_LIVE_TEST = 'true'
    & $MavenCommand '-f' "$WorkspaceRoot/backend/pom.xml" '-Plocal' '-pl' 'ruoyi-admin' '-am' '-DskipTests=false' '-Dtest.groups=external' '-Dtest=TencentRegistrationSmsLiveTest' '-Dsurefire.failIfNoSpecifiedTests=false' 'test' *> "$WorkspaceRoot/.local/tencent-registration-live.log"
    Assert-NativeExit 'Tencent registration SMS acceptance test'
    Write-Host 'One registration SMS accepted by Tencent. Handset delivery needs recipient confirmation.'
} finally {
    Remove-Item Env:TENCENT_SMS_TEST_PHONE -ErrorAction SilentlyContinue
    Remove-Item Env:TENCENT_SMS_SEND_LIVE_TEST -ErrorAction SilentlyContinue
}
