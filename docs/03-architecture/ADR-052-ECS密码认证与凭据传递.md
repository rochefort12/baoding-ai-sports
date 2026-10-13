# ADR-052：ECS密码认证与凭据传递

日期：2026-10-13。用户明确ECS使用SSH密码而非登录私钥，账号root、公网IP 47.92.212.93，并通过阿里云控制台提供服务器Ed25519主机公钥。端口按未另行指定的22配置，保持ADR-050手动发布。

## 决定

deploy-ecs.yml默认目标root@47.92.212.93:22，允许Repository Variables覆盖HOST/USER/SSH_PORT/DEPLOY_ROOT。SSH登录密码从Repository Secret ECS_SSH_PASSWORD读取，移除ECS_SSH_KEY要求。实际密码不写文件、命令参数、文档、测试证据或提交，也不在本轮传输到GitHub或服务器。

ECS_KNOWN_HOSTS仍为必需Secret，依据用户从控制台提供的主机公钥生成记录；公开主机公钥可以出现在配置说明中，不把终端提示符或注释当作key内容。不以即时扫描替代信任确认，SSH/SCP继续StrictHostKeyChecking=yes。主机身份校验与用户登录密码认证各自独立。

只有GitHub Linux runner安装sshpass，scripts/ci_release.py通过匿名管道及-d文件描述符传递密码，保留stdin传输远端Bash脚本；异常也关闭管道，子进程环境移除SSH密码和GHCR/GitHub Token。密码不会拼进SSH/SCP命令或临时密码文件。方法依据[Ubuntu官方sshpass手册](https://manpages.ubuntu.com/manpages/jammy/man1/sshpass.1.html)。ECS和应用容器不增加sshpass、Python或PowerShell依赖；不自行修改sshd、安全组或服务器密码。

GHCR仍用短效只读任务Token经SSH临时传递并清理，来源验证、digest、文件锁、健康检查、Flyway及数据生命周期边界保持ADR-050/051。

## 验证及未完成

新增5个合成密码传递案例，与原14个发布清单／来源／LF封装案例合计19个；覆盖密码只在管道、不进命令及子进程环境、SCP与Bash stdin、缺密码／非法格式拒绝和失败时关闭描述符。合成测试不使用用户密码，也不模拟声称真实认证成功。

主机公钥已准备，GitHub Secrets实际设置、GitHub CI/GHCR/ECS首次发布、服务器数据服务／私有参数／备份／HTTPS仍待操作及验证。此决定不表示已登录服务器或已上线，不关闭原业务21/17/7清单。
