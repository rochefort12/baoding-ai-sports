#requires -Version 7.0
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Common.ps1"
$demoRoot = Join-Path $WorkspaceRoot '.local/demo-20261011'
New-Item -ItemType Directory -Path $demoRoot -Force | Out-Null
# Credentials are exported only into this local ACL-protected directory, never logs or public documentation.
$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$acl = Get-Acl -LiteralPath $demoRoot
$acl.SetAccessRuleProtection($true,$false)
foreach ($identity in @($currentIdentity,'SYSTEM')) {
    $rule = [Security.AccessControl.FileSystemAccessRule]::new($identity,'FullControl','ContainerInherit,ObjectInherit','None','Allow')
    $acl.AddAccessRule($rule)
}
Set-Acl -LiteralPath $demoRoot -AclObject $acl
$session = Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.local/phase1-implementation/verification-session.json') -Raw | ConvertFrom-Json
$text = @"
羽毛球一期独立演示账号（仅本机模拟数据）
参赛入口：http://127.0.0.1:5192/portal/login
工作入口：http://127.0.0.1:5192/login
所有下列演示账号的密码：$($session.password)

主办方／长期队长／球友：16693001000（参赛登录后进入主办方工作台）
双打队友／本场房主及报名管理人：16693001001
另一组队长：16693001002
另一组队友：16693001003
补员／匹配测试球友：16693001004、16693001005
普通政府岗位：phase1-government（工作账号入口）
平台管理员：admin（工作账号入口）

不要在主站5190使用这些演示账号。多人并行操作使用不同浏览器配置或独立隐私窗口。
此文件包含仅用于隔离库的演示凭据，勿截图、转发或提交仓库。
此文件未包含令牌、数据库密码或真实服务密钥。
"@
$accountPath = Join-Path $demoRoot '演示账号.txt'
[IO.File]::WriteAllText($accountPath,$text,[Text.UTF8Encoding]::new($false))
Set-Acl -LiteralPath $accountPath -AclObject (Get-Acl -LiteralPath $accountPath)
Write-Output 'Demo account sheet prepared in the protected local demo directory; credentials omitted from output.'
