# ADR-046：本地全 Docker 试运行与新基线

日期：2026-10-13。用户授权补齐前后端 Dockerfile，把全部服务在本地 Docker 中启动供本人测试。最终数据决定为新基线空库、重新注册；后续明确新库可以重建，不做旧库兼容或旧库到新库迁移。本文最终决定覆盖早期恢复旧试用副本的方案；原导出及文件仍保留。

## 决定

新增 `docker-compose.full.yml` 和 `scripts/` 下 PowerShell7 入口。独立项目、容器、网络和持久卷使用 `aisports-dev-docker-*`，不操作其他工作目录或项目的资源。Java 后端、Node 网关、Nginx 静态前端、PostgreSQL17、Redis7、MinIO 共六个常驻容器。

前后端多阶段构建在 Docker 中完成，Java测试明确启用，前端类型／测试／生产构建和网关测试随构建执行。上游 `ruoyi-admin/Dockerfile` 保留，新增 `backend/Dockerfile` 构建完整模块装配。PowerShell7只用于Windows宿主编排；Linux阶段使用Maven／Node／pnpm／apt原生工具，不安装PowerShell。运行与失败修复的事实见操作记录。

网关通过 `network_mode: service:backend` 共享Java私有网络命名空间，不用宿主网络；保留现有仅回环的Agent回调限制。两者不映射宿主端口，重建时和前端一起重建。Docker profile使用容器DNS访问PG／Redis；只映射宿主回环的页面、数据库和存储管理端口。

前端同源代理及SSE不缓冲；Nginx日志只记录路径，避免记录查询中的令牌。应用非root、只读根目录、移除capabilities、禁止提升权限，提供有限临时目录、日志轮转和内存上限。凭据存入忽略目录，构建不含私有配置。按最终ADR-049，Java接收仅供Flyway专用连接使用的PG owner配置，业务连接池不使用它；网关不接收DB／Redis／JWT／短信／MinIO凭据。

当前应用连接新的 `aisports_docker_fresh`，先事务安装框架／工作流和应用角色，随后按照最终ADR-049由Spring Boot启动早期的Flyway所有者连接执行业务三份基线；业务账号保持无DDL权限。遵循ADR-047，不接管旧业务账本。框架表使schema非空，因此仅在新建框架库、无asp表及无Flyway账本时，用独立Flyway11.7.2容器显式记录版本0框架标记，再由后端执行完整V001—V003；不使用baselineOnMigrate，不把旧结构当已迁移。镜像从仓库根上下文构建并原样打包迁移SQL。

新MinIO私有桶 `aisports-docker-fresh` 不导入历史文件。服务端内网地址和浏览器签名地址分别配置；无签名拒绝访问。框架平台账号使用随机BCrypt密码留在私有文件。业务数据从空库开始，普通用户重新注册。

本地已验证UI清单仅在当前定义hash完全一致、Docker就绪通过时，用新平台账号经能力发布API重新配置UI渠道。变化或未验证定义保留关闭，不开放Agent渠道、不复制旧业务记录、不伪造本轮普通角色验收。发布配置保留新审计回执。

## 验证与边界

Java581测试、前端83测试及构建、网关测试层、新基线Flyway、数据库约束和36项就绪检查实际通过；浏览器登录页正常。就绪检查临时对象通过API上传／读取／私有拒绝／删除，业务表仍空，不发送短信、调用模型、创建赛事或办理资金。

用户普通角色业务测试、真实外部服务、压力测试及阿里云／GitHub发布另行验证。停止入口只停止六服务并保留持久数据。早期旧库导出／副本恢复历史与失败日志保留，当前启动链无旧库导入或兼容逻辑。详见[操作说明](../01-development/本地全Docker运行-20261013.md)。
