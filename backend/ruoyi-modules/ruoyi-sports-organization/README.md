# ruoyi-sports-organization

2026-10-07 B端正式接入补充。

工作台上下文 API：GET /sports/b/desk/context。拒绝平台身份，依据 OrganizationSessionApi 当前组织管理主体与有效准入，核对会话租户，再查询 payment grant；返回组织编号/名称及动作状态，不接受客户端组织编号。不改变现有组织批准开户、入场兑换及私人申请版本权限。

界面与验证边界见[B端正式界面开发记录](../../../docs/05-ui/B端正式界面开发记录.md)。无模型、迁移或跨模块 Mapper 依赖变更。
