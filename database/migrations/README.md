# 迁移管理

`local` 和 `docker` 配置下，后端启动时由 Spring Boot 集成的 Flyway 11.7.2 执行这些脚本。迁移连接使用数据库所有者。业务连接池仍是 `aisports_app`，没有建表权限。`dev` 和 `prod` 不打开 Flyway。

脚本按版本顺序：

1. `V001__schema_baseline.sql`：原先 V001 到 V041 在空库上的最终业务表结构。
2. `V002__platform_seed.sql`：相对框架初始数据新增或改写的租户、角色、菜单和套餐。
3. `V003__catalog_seed.sql`：运动项目、比赛类型、成长规则和智能体定义。收回应用账号对 `flyway_schema_history` 的权限。

打包时把 `V*.sql` 复制到 `classpath:db/migration`。占位符替换关闭，`clean` 关闭。

空库先由容器初始化框架表、工作流表和应用角色，再启动后端。已有业务表但没有 Flyway 账本时，启动会失败并回滚，不能当成新库重放。删除本项目数据卷后重建。

`scripts/Apply-Migrations.ps1` 仍可用独立 Flyway 容器在不启动后端时执行同一目录。两边共用 `flyway_schema_history`。

模型源仍是 `database/model/catalog.py`。以后的变化另写 `V004` 起的新文件，不写 `BEGIN`/`COMMIT`，也不修改这三份已登记脚本。
