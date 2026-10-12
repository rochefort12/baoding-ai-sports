# 助手运行与办理指引

本表工程负责持久化助手的目标、对话、可见步骤、运行状态，以及本人确认后的统一动作接续。业务办理通过公共 ActionDispatcher，不能引用其他表工程 Mapper 或实体。材料读取通过纯契约 AgentMaterialApi。

V036 为 asp_agent_version 追加可信工具、技能和业务地图 JSONB 目录及 SHA256，新增 revision 2，历史版本不覆盖。新运行锁定版本；sports_playbook 按当前服务器身份、实时权限与能力渠道返回可见地图。完整目录登记 11 个 MCP 工具，其中 6 个受控运行工具可被模型选择，5 个旧会话工具明确排除且由 MCP 服务端拒绝运行令牌。

启动、补充、上传资料、停止和本人确认使用 /sports/agents/runs 既有接口。运行详情新增 playbookVersion/sourceHash；guidance、question、checklist、navigation 块帮助页面呈现目标、缺项及下一步。导航只接受当前角色已开放能力对应的可信地图地址，模型不能编造路径、成功回执或完成状态。详细契约见 docs/02-modeling/智能体技能与业务地图接口.md。

每次工具调用重核账户、组织、岗位权限、当前 Agent grant 与预算。回复落库前再次检查当前身份与导航；资金、审批、正式结果及荣誉不能由助手代确认。现有事务、幂等、版本绑定确认与回执继续有效。目录迁移不会开放 Agent 渠道。

Gateway 在模型前读取真实 sports_capabilities，要求参数齐全的本人或已有对象问题先查事实再引导。原生工具阶段与可选 JSON 排版阶段分开，排版阶段不提供工具，不能重放业务；一般问候及纯流程咨询不强制查私人信息。定向 Gateway 六项测试含“先调用授权只读工具、无工具排版不重放”模拟边界，实际模型能否选择事实读取仍由真实候选验收判断。

验证分开记录：AgentPlaybookRulesTest 四项仅证明纯规则边界；AgentGuidanceAuthorizationTest 三项仅证明模拟实时角色授权；LegacyMcpRunIsolationTest 两项仅证明模拟旧会话隔离。真实 PostgreSQL、MCP、普通角色与 DeepSeek 场景由 scripts/Test-AgentPlaybook.mjs 追加到 .local/agent-playbook-20261011，不用模拟测试代替业务验收。

2026-10-11 实际证据：普通角色直接读取与隔离 9 项、真实模型流程引导及原任务恢复 12 项通过；候选负责人仅在 8082 开放五项只读渠道后，Test-AgentReadFacts 最终本次 17 项通过。原任务 2109111474038390784 首次未读事实的失败保留，一次接续后实际 MCP 读取个人积分、报名与房间且数值准确；比赛类型和本组织赛事读取亦准确。最终汇总 read-facts-model-final-5942e09d-06e5-4080-9709-8a703eb3b82c.json / SHA256 39f8225f3f4846467c4205592789a30b746afb3fc7a042bfdf6652ba1b743a9c 位于上述证据目录。没有重放业务事实或改变开放渠道，未代表主环境发布及写动作/正式赛事完成。
