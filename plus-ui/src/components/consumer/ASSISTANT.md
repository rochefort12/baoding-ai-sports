# 体育助手交互组件

匿名公开咨询和已登录任务共用 `AssistantWindow`，由 `ConsumerShell` 装配一个 `AssistantBubble`。身份、工具授权、可用能力及执行结果由服务器决定，界面主题卡不是授权，也不声明任何业务已办好。

- `AssistantBubble`：64×76px点击区域，54px静态图片；pointer拖动和方向键移动，拖动不触发打开，禁用图片原生拖拽。localStorage仅保存位置坐标，不保存消息或个人材料。
- `AssistantWindow`：Teleport浮窗，窗口拖动、方向键移动、pointer/键盘调整尺寸、放大还原和Escape关闭；限制在当前视口。打开440ms、关闭280ms，尺寸用540ms FLIP视觉变换，减少动态效果时跳过。尺寸和动画不重建任务内容。
- `useAssistantModalBoundary`：真正显示的若依业务dialog、drawer或message-box出现时隐藏助手与浮泡，关闭后恢复，避免阻挡手机操作。
- `ConsumerAssistant`：公开赛事咨询。三个静态功能卡只选择可取消的主题，输入默认留空，不替换本人草稿。明确发送才结合主题和本人文字请求回答；失败保留草稿，重试原请求时不误删新草稿。
- `AgentPanel`：六项主题及已保存任务记录。规程、初次办赛等指引保留，点击不生成长指令；当前服务端问题的具体答案由用户明确选择。材料上传、上下文、确认卡、真实回执和后续入口继续使用已有服务契约。

功能插图位于 `public/images/sports/assistant/`，原图、提示词和摘要在 `docs/05-ui/assets-20261011-v4/assets.json`。图是装饰资源，文字、按钮语义、焦点和业务状态仍由实际组件负责。控件焦点共用 `sport-controls.scss`，动画及表面样式共用 `sports-assistant.scss`；不要重复粘贴页面专用的浮窗样式。

真实界面验证脚本为 `Test-FloatingSportsAssistant.mjs`、`Test-AssistantMotionUI.mjs` 和 `Test-AssistantModalBoundary.mjs`。检查使用主站/隔离站真实GET与既有任务，不能用这些结果替代真实模型写动作、跨职能委派、多格式资料或实际赛事验收。世界荣誉人工确认不开放给Agent。
