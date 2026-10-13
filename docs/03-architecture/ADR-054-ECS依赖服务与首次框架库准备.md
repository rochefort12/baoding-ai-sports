# ADR-054：ECS依赖服务与首次框架库准备

日期：2026-10-14。用户明确授权通过密码连接47.92.212.93的root账号，部署Docker Compose依赖环境，包括PostgreSQL、Redis和MinIO。保留此前手动应用发布决定。

## 决定

先用已确认Ed25519主机公钥严格核验SSH身份，密码仅输入交互认证，不写命令参数、仓库、配置、文档或输出。实际只读检查确认Alibaba Cloud Linux 4.0.6、Docker29.5.1、Compose2.26.1、约3.5GiB内存/40GB系统盘，无既有容器、数据卷或/opt/aisports应用文件；因此在该独立路径进行首次准备，不接管其他项目资源。

依赖项目独立于应用发布：deploy/compose.dependencies.ecs.yml，容器/网络/数据卷均aisports-dev-ecs-*，依赖网络aisports-dev-ecs-dependencies供既有应用Compose接入。PG/Redis/S3/Console只监听宿主127.0.0.1的5432/6379/9000/9001；数据卷独立长期保留。内存上限PG512MiB、Redis192MiB、存储384MiB，合计1088MiB；这是试运行约束，不是500—800用户的容量接受。

PG17.11和Redis7.4.11沿已有锁定的官方镜像。存储采用项目既有PGSTY维护的MinIO兼容发行路线，本次选已发布pgsty/silo:RELEASE.2026-09-16T00-00-00Z；不是MinIO Inc官方发行。来源见[维护者仓库](https://github.com/pgsty/silo)及[发行者镜像标签](https://hub.docker.com/r/pgsty/silo/tags)。存储非root/只读根目录/移除capabilities，全部服务禁止权限提升、日志轮转、持久卷和健康检查。

ECS直连Docker Hub实际超时，GHCR可达。用本机从原始注册表取得的linux/amd64镜像，经docker save、gzip、完整SHA256校验和已核验SSH传到ECS导入；不配置未知公共镜像代理。依赖pull_policy=never，初始化记录导入的四镜像ID，后续prepare拒绝未经审查变化。原始digest为PG639ab7ceb90e13123085b741fb31ef493fba25463002f6da665352e7b534b652、Redisc6eabf748fc7a61dbb5a705c78bcf3d6377b1127a97d0ce965c11c44ba46896f、存储635197cb9f36d01bee221d34d1c7d7960f6a95c48b0b6c01d99cd13bdae51a46；Flyway11.7.2仅为一次标记工具。

Linux原生Python/Bash初始化入口在ECS生成独立随机凭据。私有文件root0600，Redis配置root:999／0640并置于root0700目录。配置不得回传GitHub、进入镜像或公共日志。数据库初始化管理账号aisports_bootstrap为官方容器超级用户，迁移所有者aisports_owner及业务aisports_app均非超级用户、无创建库/角色权限；业务账号无public schema CREATE或Flyway账本权限。Redis启用密码、AOF及noeviction，避免因缓存逐出锁/会话；满额行为及扩容继续监测。

首次PG空库按原文安装框架/工作流，再准备角色/授权和随机平台密码。仅无asp表且无账本的新框架库记录Flyway版本0；不执行V001—V003业务迁移，不启用baselineOnMigrate。后端启动仍按ADR-049自动执行三份业务脚本一次。MinIO兼容存储建立私有aisports-ecs桶和仅该桶可读写的应用账号，不给业务端存储root凭据。

server.env/gateway.env已准备，backend.env.pending留待明确PUBLIC_BASE_URL及供应商参数后完成；存储浏览器外域和HTTPS代理也待准备。没有启动三个应用、配置外网网站入口或触发手动ECS发布。发布复选框文案改为确认已有数据已备份或本次为无业务数据首次部署，不再暗示需要人工执行Flyway。

## 实际验证

三依赖实际healthy；生成密码未输出。框架及角色完成，asp表0、Flyway版本[0]；业务账号真实密码连接通过且DDL/账本权限拒绝，Redis认证PONG与无认证NOAUTH、受限S3账号上传/读取/删除与匿名403通过。重启三服务后以上检查再次通过，数据卷/框架/桶及IAM配置保留。服务宿主端口仅回环，私有文件权限核对通过，空载内存约PG18MiB/Redis8MiB/存储185MiB，不能代替容量压测。

记录在服务器bootstrap/dependencies-ready-*.json及忽略的本机交接目录；没有公开真实密码、Token、账号材料或重放业务。平台管理员随机密码仅保存在服务器config/platform-admin.json。本期业务21/17/7、真实短信/模型/微信/资金/赛场、HTTPS与备份恢复/扫描/容量接受继续按既有清单管理。
