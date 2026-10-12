# AISports 体育综合服务平台

基于 RuoYi-Vue-Plus **5.6.2** 与配套 plus-ui **5.6.2-v2.6.2** 的模块化单体。PostgreSQL 为主库，Redis 为辅助基础设施。M1.1—M1.7 已有主链代码，最新业务补齐及普通角色验收仍待完成；一期目标为指定组织受控试运行，不表示母版全域交付。

## 开始开发

1. 阅读 [文档入口](docs/README.md)、[交接记录](docs/01-development/交接记录.md) 与 [AGENTS.md](AGENTS.md)。
   最新业务先看 [ADR-011](docs/03-architecture/ADR-011-一期业务收口与交付边界.md)；开发及真实交付条件按 [一期未完成事项](docs/01-development/一期未完成事项.md) 推进，原始母版保留不修改。
2. 准备 PowerShell 7、Java 17、Maven 3.9+、Node >=20.19、pnpm 11.19.0、运行中的 Docker Desktop。
3. 在仓库根目录用 PowerShell 7 执行：

```powershell
./scripts/Initialize-Environment.ps1 -Start
python ./scripts/generate-model.py --check
./scripts/Test-Infrastructure.ps1
./scripts/Start-Backend.ps1
# 另一个 PowerShell 7 终端
./scripts/Start-Frontend.ps1
```

非 PATH 工具可以通过脚本参数 `-JavaHome`、`-MavenCommand`、`-NodeHome`、`-PnpmCommand` 指定。完整说明见 [环境运行](docs/01-development/环境运行.md)。

## 目录

| 路径 | 内容 |
| --- | --- |
| `backend/` | 上游后端、独立 `aisports-api` 契约与 `aisports-mcp` 适配模块 |
| `plus-ui/` | Vue3 前端、统一 CRUD 样式、生成器 MCP 选项与依赖锁文件 |
| `database/model/` | 可执行领域模型与生成目录 |
| `database/migrations/` | PostgreSQL 版本化建表语句；V001 为开发库初版 |
| `database/schema/` | 随当前模型生成的完整DDL；不覆盖历史迁移 |
| `database/verification/` | 回滚式结构验证，不能替代业务验收 |
| `scripts/` | 环境启动、模型生成与验证入口 |
| `docs/` | 业务来源、建模、ADR、运行、验收与交接 |
| `docker-compose.yml` | 独立命名的本地数据库服务，镜像版本与 digest 固定 |

上游来源固定在 [source-lock.json](source-lock.json)，原始资料和上游许可证保留。私有凭据只在忽略的 `.env` / `.local/`，禁止提交。容器健康不代表初始化已完成，脚本必须验证迁移记录与校验和。已有数据卷不自动删除。

MCP 默认关闭，启用前审查工具权限、字段与业务场景。代码生成器支持基础维护场景；资金、报名、名额、排赛与结果变更必须实现明确业务事务。
