# ADR-051：本地终端约束范围与Linux原生发布

日期：2026-10-13。用户明确PowerShell7只是本地开发环境约束，要求修正AGENTS/rules，并移除生产或Docker内部的相关依赖。用户当前决定优先于以前扩大适用范围的解释。

## 决定

本机Windows开发终端继续使用PowerShell7；这是本机执行工具的限制。AGENTS.md和Cursor规则明确它不适用于Linux CI、生产服务器、Docker构建或容器运行。Windows本地开发脚本保留。

GitHub Actions使用Bash，Python3在CI端处理镜像记录、来源校验、发布清单和SSH传输。ECS只使用原生Bash/coreutils/flock、SSH、Docker Engine和Compose插件，不安装CI端Python或本机开发终端。Docker应用构建／运行继续使用原生Maven/Java/Node/pnpm/Nginx。

删除六个上一轮新增的生产CI/发布.ps1入口；使用scripts/ci_release.py、scripts/test_ci_release.py及scripts/deploy-ecs.sh。发布bundle仍是四个白名单文件：release.json、images.env、compose.ecs.yml、deploy-ecs.sh。脚本与封装强制LF，避免Windows检出导致Linux入口失败。

保持ADR-050的手动发布、官方Action SHA、PR权限、同仓库main来源检查、digest完整性、SSH主机密钥、临时认证清理、串行及文件锁、健康检查、数据服务独立和禁止迁移后自动数据恢复。这里只改变执行环境和实现工具，不修改业务／数据库／已运行容器。

## 验证

原生Bash语法及shellcheck、两workflow actionlint、14个清单/来源/封装单元案例通过，其中覆盖浮动标签、外部仓库、混合提交、缺/多镜像、PR/失败构建和CRLF转LF。服务器部署通过隔离模拟Docker验证接续交接记录，不冒充实际ECS发布。

GitHub/GHCR/ECS远端运行、SSH连通、服务器一次配置和真实普通角色验收仍待完成。历史交接中的旧工具实施记录保留为历史，由本决定替代其生产约束，不继续作为安装要求。
