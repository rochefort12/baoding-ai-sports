# ADR-049 Spring Boot 集成 Flyway

日期：2026-10-13。依据：用户确认采用 Spring Boot 集成，并说明此前不知道业务进程为何不使用数据库所有者账号。本决定取代 ADR-048 中「Flyway 只在应用进程之外执行」的要求。账本、禁止 `clean`、旧库不能当作空库重放，仍然有效。

## 决定

业务进程继续使用 `aisports_app`。这个账号不能建表、删表或创建角色，避免普通请求里的错误 SQL 改动结构。Flyway 在后端启动早期单独使用数据库所有者连接，配置项是 `spring.flyway.url`、`user` 和 `password`，不替换 `master` 数据源。

只在 `local` 和 `docker` 打开。基础配置里 `spring.flyway.enabled` 为 false，避免上游 MySQL 的 `dev`/`prod` 被误迁移。依赖是 `flyway-core` 和 `flyway-database-postgresql`，版本由 Spring Boot 3.5.15 管理。

`database/migrations/V*.sql` 在打包时进入 `classpath:db/migration`。全栈镜像的构建上下文改为仓库根目录，以便 Dockerfile 同时复制后端和迁移脚本。Docker 试用后端的环境文件增加所有者账号，只给 Flyway 使用；网关仍然不接收数据库密码。

## 验证

本轮没有启动数据库、后端、前端或网关，也没有对正在使用的库执行迁移。打包资源复制另行记录。旧数据卷上一旦用新配置启动后端，Flyway 会因表已存在而失败并回滚。

## 全 Docker 接续实际验证（2026-10-13）

本地全Docker任务随后实际构建并启动了集成版。框架表使schema非空，直接migrate最初被Flyway拒绝；全Docker入口仅在新建框架库、无asp业务表及账本时记录显式版本0框架标记，再启动Spring Boot完整执行V001—V003。baselineOnMigrate仍关闭，不用于兼容旧库。业务账号无schema CREATE和账本读取权限，Flyway专用所有者连接实际迁移成功。

新库启动前为0业务表、账本[0]，启动后118表、[0,001,002,003]全成功。最终镜像581项Java测试通过，六服务与36项技术就绪检查实际复核。原生/原基础设施单独入口未据此视为验证通过。详细证据和未完成边界见本地全Docker运行说明及交接记录。
