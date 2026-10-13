# ADR-053：发布仓库与Git认证切换

日期：2026-10-13。用户指定新GitHub账号及仓库rochefort12/baoding-ai-sports.git，要求继续向main上传，若需要账号登录则告知。

## 决定

本地origin改为https://github.com/rochefort12/baoding-ai-sports.git，旧地址留为previous-origin供历史追溯。本项目本地credential username选择rochefort12，不删除旧账号凭据或修改其他项目的全局认证设置。认证通过Git Credential Manager官方浏览器／设备流程完成，不索取GitHub密码或Token，不把认证结果写入仓库、文档或日志。

保留已审查的提交历史及main分支。上传前读取新仓库main；空仓库直接创建main，有已有历史则先核对，不未经授权强推。无关工作区修改保持未提交。

Actions通过github.repository自动生成GHCR包名、镜像来源标签和发布清单身份，无需硬编码旧账号；新镜像路径为ghcr.io/rochefort12/baoding-ai-sports-{backend,frontend,ai-gateway}。仓库切换不复用旧仓库的release artifact或digest清单。发布仍为main构建／GHCR推送、ECS手动部署，不因上传授权触发ECS。

Repository Secrets不会随Git历史迁移。新仓库需重新设置ECS_SSH_PASSWORD及ECS_KNOWN_HOSTS；服务器地址、公钥、密码传递方式和数据生命周期边界保持ADR-050/052。旧账号Actions被禁用的结果保留为历史，不把它当新账号状态。

## 验证及边界

初次访问新仓库返回Repository not found，本机Git Credential Manager仅列出旧账号；已启动新账号认证。实际上传及新仓库CI结果接续交接记录。此轮不改应用业务、数据库、ECS配置、已运行容器或正式验收状态。

2026-10-14接续：新账号浏览器认证成功，新空仓库main已上传fc578d7；Actions真实运行38426912734已触发，旧账号限制未在此次触发中出现。首次发布测试通过，源码检查因私有.local账号文档链接缺失失败；修复CI检查的私有文件边界，不上传账号文件。最终运行结果见交接记录。

最终接续：9e50d09的Actions38428654974全部成功，校验、三服务测试／构建／GHCR推送和发布包封存完成。实际下载ecs-release核对精确四文件、仓库／提交／run ID、三个新仓库digest和Linux脚本LF通过。新仓库真实CI/GHCR能力已验证，ECS尚未部署，新仓库Secrets及服务器一次准备另行完成。
