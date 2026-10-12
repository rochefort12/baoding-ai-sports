# 生成器与 MCP 基础改动

## 生成范围

一期最新需求见 [ADR-011](ADR-011-一期业务收口与交付边界.md)。组织字段目录等基础维护可按模型/权限明确后生成 ZIP 审查；字段被选用/正式使用后的语义保护、本人确认/报名快照、付款通过条件、冲正退款和注销核验必须手写业务事务，不能以生成 CRUD 覆盖。通知/资金/私人档案不因已有接口自动开放 MCP。

沿用上游 Controller / Bo / Vo / Service / Mapper、校验、权限、日志、重复提交和 PostgreSQL 菜单 SQL。默认包 `org.dromara.sports`，移除 `asp_` 表前缀。数据库适配切换为 PostgreSQL JDBC 与 Anyline PostgreSQL；numeric/decimal/money 生成 BigDecimal，避免上游统一 Long 造成金额精度损失。完整表注释保留来源与事务责任，但默认功能名只取业务说明并限制为50字符，避免 gen_table 字段超长。

仅使用 ZIP 下载方式，保留上游关闭任意路径落盘的修复。对复杂资金、名额、身份关系、规则编排等，先实现模型对应业务事务，不能直接向普通用户开放任意增删改查。

CRUD 与树模板使用 `.generated-crud` 公共样式；日期查询宽度从内联样式提取。ZIP 输出 `vue/assets/styles/generated-crud.scss`，批量表生成只输出一次，全局 `plus-ui/src/assets/styles/index.scss` 引入一次。新公共样式添加到共享模板与实际共享文件并检查一致性；不得给每个页面复制 `<style>`。重复业务路径报错，ZIP I/O 错误不得静默返回残缺结果。

每表额外生成 `docs/generated/<module>/<business>.md`，包含表、字段、REST、权限、MCP 选项、合入说明及待补业务验证内容。文档不能自动推断跨行事务与行业规则，开发者需补齐验收、隐私和授权设计。

## MCP 生成与服务

前端生成信息表增加“只读 MCP 工具”开关，保存于 gen_table.options，不改动框架表结构；默认 false，重新编辑会读回。启用后 Controller 增加 `@Tool` 包装方法：

- `<module>_<business>_get`：详情，明确检查查询权限和主键。
- `<module>_<business>_list`：仅 CRUD，有界页码与 1—100 条页面，显式检查列表权限。树表不生成全量列表工具。

不生成新增、修改、删除、导出工具。包装方法不暴露新的 MVC 写路由；采用显式 `McpAccess.requirePermission`，不能因工具反射调用或自调用绕过权限。查询记录使用上游 @Log，关闭请求与响应内容保存；全局耗时拦截器对 MCP 端点仅记录路径与耗时。VO 字段和服务行级权限仍必须审查，默认生成的 VO 不适合直接发布敏感身份材料。

独立 `aisports-mcp` 基于 [Spring AI 1.1 Stateless WebMVC MCP](https://docs.spring.io/spring-ai/reference/1.1/api/mcp/mcp-stateless-server-boot-starter-docs.html)，版本 1.1.8，SYNC / STATELESS / `/mcp`，无 LLM 模型服务。所有 profile 默认关闭，local 读取 `.env` 的 MCP_ENABLED。仅收集 `org.dromara.sports.*` Controller 中显式工具，禁用自动注解扫描，重复名称启动失败；没有业务 Controller 时不会凭空产生工具。

Spring AI 函数式路由不在上游 AllUrlHandler 集合内，因此单独 servlet filter 覆盖 MCP 路径。请求携带 `Authorization: Bearer <已有登录令牌>` 与 `clientid: <登录客户端>`；filter 核验登录、令牌 clientid 与 `sports:mcp:invoke` 权限，校验 Host 与可选 Origin。无凭据 / 不匹配返回401，不允许的源或权限返回403；不把令牌或异常细节回传。默认允许 localhost / 127.0.0.1 与5173前端来源，非本机部署需明确配置域名，不能直接改成通配。

方法还会核验具体权限和认证租户；同请求同步执行复用租户上下文。共享事实表不受自动 tenant 条件保护，因此具体应用服务必须实现本人档案、队伍成员及赛事工作人员的用途授权。进程内 API 仍是 `aisports-api` 契约；MCP 是可选访问适配，不是微服务通信总线。

开发调试可将私有 `.env` 中 MCP_ENABLED 改为 true 后重新启动。生成器选择 true 并不自动启用服务，启用服务也不自动发布未生成的工具。V002增加系统工具下的“MCP只读调用”权限节点，固定预留菜单ID为2106000000000000001。管理员通过既有角色权限管理明确授权，需同时授予具体查询权限；不向任何普通角色自动赋权。所有profile固定SYNC/STATELESS，开启自动扫描或其他传输模式会启动失败，避免异步切换丢失认证上下文。

## 当前验证责任

模板回归检查 opt-in、权限、分页界限、树场景、无内联样式与批量 ZIP 公共文件去重。MCP filter 测试验证缺凭据、客户端不匹配、源限制及权限调用。真实 HTTP、工具调用、租户和服务行级权限的验证状态详见交接记录；未实现业务工具的领域不得标注验收通过。
