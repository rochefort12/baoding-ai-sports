# ADR-050：GitHub Actions、GHCR 与 ECS 手动发布

日期：2026-10-13。用户要求编写GitHub Actions配置：构建推GHCR，最终部署有Docker Engine的阿里云ECS；明确选择保留手动发布。

## 决定

PR只有读权限，运行源码契约检查、发布清单边界检查及三个Dockerfile中的测试／构建，不取得GHCR写权限或服务器密钥。main推送或在main手动构建才使用GITHUB_TOKEN packages:write发布三个linux/amd64镜像。Actions固定官方仓库完整commit SHA，checkout不持久化Git凭据；BuildKit缓存按服务隔离，PR不回写共享发布缓存。发布SBOM和最小provenance，不把凭据放入构建参数。

只有三镜像全部成功才产出ecs-release清单，包含仓库、提交、构建run ID和不可变digest，以及本提交的应用Compose／服务器部署脚本。只推sha提交标签，不用latest决定部署；清单artifact保留14天。

第二条workflow仅手动触发，要求main及操作人确认备份／Flyway迁移。通过GitHub API核对来源workflow、同仓库main、非PR事件、完成且success，再下载对应run的清单；拒绝错误仓库、混合提交、缺镜像、浮动标签。ECS通过SSH严格核对预先确认的known_hosts，短效任务token仅用于本次拉取，部署完成／失败移除凭据文件。

ECS使用Linux原生Bash/coreutils/flock、Docker Engine及Compose插件；CI端使用Bash/Python3，应用资源固定aisports-dev-ecs-*，与长期数据服务分离。先拉取所有digest，核对目标归属，再一起重建Java／共享回环命名空间的Node／前端，检查健康与Nginx API代理。无down、prune、删卷、数据库重建或自动数据恢复。Flyway沿ADR-049在后端启动早期用专用所有者连接，业务连接池继续受限。

新增ecs profile显式配置PG、Redis、稳定phone-pepper和公开HTTPS地址；关闭短信验证码回显与Swagger，保留框架登录验证码。前端API加密关闭与后端local基础策略配对，必须由独立HTTPS入口保护；Aliyun验证码验签沿现有配置，不据此宣称新增验签。

发布脚本保存前版清单，失败不会冒充成功，也不在迁移之后自动回滚应用／数据库。备份确认是操作人声明，流水线没有自动生成或演练备份。本轮不建设备份平台、审批平台或财务能力。

## 验证与未完成

本轮做本地workflow检查、Linux Bash语法/shellcheck、清单与来源边界单元检查及非敏感占位Compose渲染；结果接续交接记录。没有推送GitHub、GHCR或连接／部署ECS；远端凭据、Docker网络、数据服务初始化、对象存储配置、HTTPS、真实运行与压力容量需要服务器阶段核实。技术配置不关闭业务21/17/7清单。


用户后续明确本机Windows终端限制不能扩大到CI、ECS或容器，当前发布入口已改为原生Bash/Python，上一轮发布入口已替换；约束范围及接续验证见ADR-051。

用户后续确认使用SSH密码认证及root账号，当前默认目标为47.92.212.93:22；密码Secret、匿名管道传递及可信主机公钥决定见[ADR-052](ADR-052-ECS密码认证与凭据传递.md)。
