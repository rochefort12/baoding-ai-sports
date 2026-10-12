# 助手下一步行动卡片

2026-10-10，正式 BusinessAssistant Vue 展示调整，依据 ADR-020 的本日接续。浅琥珀卡片表达草稿待补充，浅绿卡片表达可保存；标题、图标和文字状态同时区分普通聊天，提示仍由服务端 readiness 提供。没有修改后端规则、调用真实模型或保存业务草稿。

以下均为正式组件配合严格隔离接口的合成样例截图，非真实办赛结果：

- [桌面待补充](desktop-blocked.png)
- [手机待补充](mobile-blocked.png)
- [桌面可保存](desktop-ready.png)

PowerShell 7 运行 Test-AiBusinessUi：97 项通过（原91项加6项行动卡片/窄屏/状态切换）；vue-tsc 通过。首次失败为旧聊天文本等待器遇到两条同名回复，改为等待本轮就绪状态更新后重跑通过，未改变产品对话来迎合测试。日志 `.local/assistant-next-step-ui.log`、`assistant-next-step-ui-second.log`、`assistant-next-step-typecheck.log`，差异空白检查通过。实际图片已检查，不新增数据库迁移或业务验收关闭。
