# GitHub Actions 与 ECS 发布配置

已经编写两条workflow，按用户决定保留手动部署，架构见[ADR-050](../03-architecture/ADR-050-GitHub-Actions与GHCR及ECS手动发布.md)。当前发布仓库按用户要求切换为 `rochefort12/baoding-ai-sports`，分支仍为main，见[ADR-053](../03-architecture/ADR-053-发布仓库与Git认证切换.md)。2026-10-14实际构建提交 `9e50d09f55d9ec8cef03092d1e6a097ba81b5328` 的[CI运行38428654974](https://github.com/rochefort12/baoding-ai-sports/actions/runs/38428654974)已全部成功，三镜像已推GHCR，ecs-release已封存并下载核对。手动部署可选择此构建ID，但仍须先完成新仓库Secrets和服务器准备。旧账号触发失败及本次首次两项干净检出修复见交接记录，不冒充ECS部署已验证。

## 流程

1. PR运行源码契约、发布清单与密码传递19个边界／封装案例、后端Java测试／打包、前端类型／测试／生产构建、Node测试。PR没有服务器登录凭据或镜像写权限。
2. main推送触发 `CI and GHCR images`；也能在main手动运行。三镜像测试随Docker多阶段构建执行，只有成功的最终镜像推GHCR。三项全部成功后上传 `ecs-release`。
3. 运行摘要给出构建run ID。选择 `Deploy to Alibaba ECS` → Run workflow → main，填写该ID，核对数据库／文件备份及本次迁移后勾选确认项。
4. 发布流程验证来源成功、同仓库main及指定workflow，消费该run的digest清单，先拉全镜像，再重建三个应用、等待健康、检查同源API并保存当前清单。

镜像自动使用仓库名小写，例如 `ghcr.io/<owner>/<repository>-backend:sha-<commit>`，另两项为 `-frontend`、`-ai-gateway`；部署实际引用 `@sha256:...`。发布无需额外GHCR PAT，使用本仓库GITHUB_TOKEN；私有包须关联仓库并允许该仓库Actions读取。官方依据：[发布镜像](https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images)、[GHCR与GITHUB_TOKEN](https://docs.github.com/en/packages/managing-github-packages-using-github-actions-workflows/publishing-and-installing-a-package-with-github-actions)。

artifact保留14天，过期构建需重新生成可审核清单；GHCR镜像不会被本配置自动清理。只发布amd64，ARM ECS需要另配平台构建。SBOM是成分清单，不等于漏洞扫描通过；扫描门禁仍待实施。缓存有助重复构建，但Maven RUN缓存挂载不保证跨托管runner完整复用，不承诺固定构建分钟数。

## GitHub 一次配置

[新仓库配置页](https://github.com/rochefort12/baoding-ai-sports/settings/secrets/actions) → Secrets and variables → Actions，添加以下两个Repository Secrets。旧仓库中已经添加的Secrets不会随Git推送迁移；新仓库是否已添加需单独核对。CI构建与GHCR推送不依赖这两项ECS凭据，手动ECS部署需要。按用户决定，SSH使用账号密码登录，见[ADR-052](../03-architecture/ADR-052-ECS密码认证与凭据传递.md)：

| 名称 | 内容 |
| --- | --- |
| ECS_SSH_PASSWORD | ECS SSH登录密码；只填入Secret，不写入仓库、命令或文档 |
| ECS_KNOWN_HOSTS | 从可信渠道核对的服务器SSH主机公钥记录；非22端口使用对应 `[host]:port` 记录 |

当前默认连接为 `root@47.92.212.93:22`。用户通过阿里云控制台提供的主机公钥对应以下完整记录，将这一行作为 `ECS_KNOWN_HOSTS` 的值。它用于确认服务器身份，不是登录私钥或登录密码：

```text
47.92.212.93 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICqc0R3UEh2con+RDMM6dc/V/VA0h+5a/s2HFLoduBXZ
```

Variables可选：`ECS_HOST` 默认 `47.92.212.93`、`ECS_USER` 默认 `root`、`ECS_SSH_PORT` 默认22、`ECS_DEPLOY_ROOT` 默认 `/opt/aisports`。更换服务器／端口时也要更新可信的主机公钥记录。不需要把数据库／模型／短信密码放GitHub；这些只存ECS私有文件。发布会把当前只读任务token通过加密SSH临时传给服务器拉包，随后移除Docker认证文件，不依赖服务器长期PAT。

仅GitHub Linux runner安装 `sshpass`。Python通过匿名管道文件描述符传递SSH密码，避免进入命令参数或临时密码文件，并保留标准输入传送远端Bash脚本；SSH/SCP子进程环境移除登录密码及任务Token。ECS仅需原有SSH密码认证可用，不要求安装sshpass，也不修改服务器SSH配置。所有连接仍开启严格主机公钥校验。

仓库允许Actions使用GITHUB_TOKEN写Packages；只给可信维护者workflow修改／手动发布权限，并保护main。这里用workflow_dispatch作为人工发布边界，不依赖GitHub Free私有仓库的Environment审批功能；Environment／保护规则能否使用须按账户套餐核对。[GitHub部署控制说明](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/control-deployments)。

不要用发布时临时ssh-keyscan结果替代可信主机密钥。SSH安全组需允许实际runner来源或通过已有可信运维通道；本配置不为发布打开任意来源SSH。首次还需验证ECS访问ghcr.io的连通性和私有包拉取权限。

## ECS 一次准备

2026-10-14按用户授权已完成目标ECS三依赖、框架/版本0、受限角色及私有存储准备并实际验证，见[ECS依赖运行说明](ECS依赖环境运行-20261014.md)及ADR-054。新仓库两项Secrets名称已核对；server.env/gateway.env就绪，backend.env.pending仍需网站域名/供应商参数，文件HTTPS入口也待配置。下面的环境要求有相应已完成项，不表示三个应用已部署。

现有Docker Engine之外需要Docker CLI的Compose插件、SSH服务，以及Linux常规Bash/coreutils/flock工具。发布入口为 `scripts/deploy-ecs.sh`，不要求安装额外脚本运行时。Python3只在GitHub托管runner上处理清单和SSH传输；服务器和应用镜像不需要CI端Python。

由运维准备以下目录，发布账号可写releases及根目录的清单／锁文件，私有配置仅授权必要账号；logs和legacy-files须让容器UID10001可写：

```text
/opt/aisports/
  config/
    server.env     ← deploy/server.env.example
    backend.env    ← deploy/backend.env.example
    gateway.env    ← deploy/gateway.env.example
  releases/
  logs/
  legacy-files/
```

示例文件只有占位值，必须替换并存服务器，不能原样部署或提交真实副本。`backend.env`设置PG JDBC URL、应用账号、Flyway所有者、Redis、稳定phone-pepper、JWT、公开HTTPS域名和供应商参数；`gateway.env`只有AI参数，两端AI_INTERNAL_TOKEN一致。当前示例短信关闭，正式注册需要配置已有腾讯短信参数。框架登录图片验证码在ecs开启；原Aliyun验签策略未扩展。

数据服务独立长期维护：在 `ECS_NETWORK` 指定的专用Docker网络上预先准备PG／Redis／MinIO，或配置VPC可达的RDS／Redis／OSS。默认内网网络名 `aisports-dev-ecs-dependencies`；PG及Redis容器默认别名postgres／redis。发布Compose没有数据库服务、初始化脚本或数据卷删除步骤。应用默认总内存上限约2.4GiB，JVM堆1GiB；数据服务、OS、构建不包含在此上限，2C4G只能先做有限试用并实测容量，不能据此保证500—800用户并发。

第一次目标PG新库须单独安装框架／工作流、受限应用角色及默认授权，并显式准备框架版本0 Flyway标记，随后后端启动执行三份业务基线；参见[本地实际初始化边界](本地全Docker运行-20261013.md)。本地固定容器名的初始化脚本不能直接在ECS照搬。目标库、管理员随机密码、MinIO／OSS私有配置和已验证渠道需要服务器一次准备，发布流程不导入本地试用数据、账号或本地能力回执。已有正式Flyway库后续按新的版本迁移，不能改已应用脚本。

前端默认只映射宿主 `127.0.0.1:8088`，需已有HTTPS反向代理将域名转发至此，并验证SSE、上传限制和文件浏览器签名域名。数据库／Redis／网关／MinIO管理端口不由发布Compose映射公网。首次部署前配置私有存储的内外endpoint、专用应用桶权限并实测上传／签名／删除，不能复用local的127.0.0.1文件域名或默认凭据。

## 发布失败与验证边界

发布有GitHub串行控制和服务器文件锁。镜像拉取或配置校验失败时不更新应用；更新阶段失败可能已有部分容器替换，服务器日志由授权运维检查，不上传含凭据的解析配置或完整日志。之前的当前清单会复制到本次 `previous-release.json`，成功才替换根目录current-release.json。

后端启动自动执行Flyway，不需要操作人另行执行迁移SQL。发布确认文案为“已有数据库/文件已备份，或确认本次是无业务数据的首次部署”，字段名为兼容既有dispatch保留backup_and_migrations_confirmed；勾选是操作人声明，流水线没有生成、验证或演练备份。应用旧digest回退也须确认新数据库结构兼容，不能把换镜像当数据回退；没有自动恢复数据库、删卷、prune或恢复旧业务库。

当前本地检查包含workflow/actionlint、Linux Bash语法及shellcheck、19个发布来源／digest／LF封装与密码传递案例和非敏感占位Compose渲染；密码传递使用合成夹具和模拟进程。用户提供的主机公钥已生成known_hosts记录，截图曾确认旧仓库两项Repository Secrets名称已添加，Secret值没有读取或回显。没有实际SSH登录；新仓库托管执行、GHCR发布／ECS拉取／HTTPS／数据服务及普通角色真实验收接续本次推送记录。本地已有581 Java／83前端等历史通过是Docker化证据，不冒充本轮GitHub或ECS执行结果。
