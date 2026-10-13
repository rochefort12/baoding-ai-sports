# ADR-048 Flyway 迁移入口

日期：2026-10-13。依据：用户要求引入 Flyway 管理数据库迁移，完成后不启动服务，因为另一边正在使用。

## 决定

迁移执行器改为 Flyway 11.7.2，与当前 Spring Boot 3.5.15 的依赖版本一致。它由 `scripts/Invoke-Flyway.ps1` 在独立容器里运行，使用数据库所有者连接 `database/migrations/`。应用进程不加入 Flyway，启动时不迁移。应用账号继续没有 DDL 权限。

`V001__schema_baseline.sql` 去掉自带的 `BEGIN`/`COMMIT` 和清空 `search_path` 的语句，改由 Flyway 把每一版包进一个事务。脚本仍使用 `public.` 限定业务对象。`V003__catalog_seed.sql` 在目录写入后收回 `aisports_app` 对 `flyway_schema_history` 的权限。占位符替换关闭，禁止 `clean`。

空库初始化只保留框架表、工作流表和应用角色。业务三份脚本不再挂进容器首次启动。数据库未监听时脚本直接停止，不负责把数据库拉起来。

已经有业务表、但没有 `flyway_schema_history` 的库拒绝执行。不写 Flyway 基线，也不从结构基线重放。这类库删除本项目数据卷后重建。

## 验证

本轮只做脚本和文档，没有启动数据库、应用、网关或前端，也没有对正在使用的库执行迁移。PowerShell 解析通过。`scripts/check-source.py` 核对了三份脚本的 SHA-256 和文档链接。Flyway 对空库的实际 `migrate` 尚未运行。
