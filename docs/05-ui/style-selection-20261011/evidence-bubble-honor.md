# 浮泡交互与传奇荣誉认证验证

2026-10-11，接续[第一轮正式产品](evidence-product.md)及[第二轮历史版本](evidence-global.md)。本轮正式代码已完成紧凑赛事筛选、五个运动艺术入口、独立浮泡、集中资料上传入口、九档成长及外部世界荣誉认证，并在本机真实服务验证。**合成认证不证明世界荣誉事实；本机选择性开放不表示真实赛事闭环或公网正式上线。**

## 产品行为与实现

- 首页和赛事目录以实际赛事为主，筛选压为一行；五个有文字和焦点的运动插画入口进入对应业务。图像禁止原生拖拽，拖动不会意外拖出大图；主要按钮、手机布局和任务卡对齐按响应宽度检查。用户最新要求的下拉改用浅色紧凑浮层，支持方向键、Home/End、Enter、Escape、Tab及外部点击，选项保留实际字符串/数字类型、required和disabled。输入选中只改变同一条边界，不同时叠内层outline、外层outline和halo；键盘边界略深、错误保持单条红边。日期容器与真实inner wrapper区分，浮层内输入及日历强调使用同一灰绿。
- 一枚浮泡打开公开咨询或本人办理助手，可拖动、键盘移动、调整窗口大小、放大和关闭。规程、第一次办赛等卡片继续提供，点击只选择可取消的主题芯片，默认输入留空并保留用户自己的草稿；发送前不启动模型。窗口尺寸切换采用FLIP视觉变换，进入440ms、退出280ms、放大/还原540ms；减少动态效果时跳过，不承诺任何设备固定帧率。浮泡位置只保存坐标；窗口关闭重开保留草稿与原任务。真实业务弹窗打开时，浮泡和聊天临时隐藏、退出指针路径，保留助手 DOM 和输入；关闭后恢复。
- 头像上传和裁剪集中于 `/portal/profile`，旧 `/portal/identity` 兼容，房间保留原任务返回。工作账号访问公开页不误读参赛者私有资料；真实头像授权与私证授权独立。
- 默认成长九档为新星0、青铜40、白银120、黄金400、铂金1000、钻石2400、星耀4800、王者9600、传奇19200。以当前运动的有效版本为准；新星为基础状态，其余八档各有徽章和透明框，预览不增加积分。V037 前向增补传奇，不改历史积分或重放奖励。
- 世界冠军、世界亚军和世界季军属于独立外部认证。本人申请并提供私有材料，平台负责人手工核实本人归属、世界级赛事、年份、项目、名次、公布主体及正式结果，绑定申请和本人档案版本。通过后默认不佩戴、不公开；本人佩戴和荣誉公开由本人选择，匿名还受名片公开开关约束。补正、拒绝及撤销保留历史，撤销同步停止佩戴和公开，认证不增加成长分。

依据：[ADR-033](../03-architecture/ADR-033-悬浮助手与传奇及世界荣誉认证.md)、[个人外部荣誉认证接口](../02-modeling/个人外部荣誉认证接口.md)。主要实现为 [浮泡](../../plus-ui/src/components/consumer/AssistantBubble.vue)、[聊天容器](../../plus-ui/src/components/consumer/AssistantWindow.vue)、[业务弹窗边界](../../plus-ui/src/hooks/useAssistantModalBoundary.ts)、[本人认证](../../plus-ui/src/components/consumer/HonorCertification.vue)、[平台核实](../../plus-ui/src/components/business/HonorCertificationReview.vue)、[服务端认证事务](../../backend/aisports-domains/d10/aisports-table-honor/src/main/java/org/dromara/sports/tables/d10/honor/HonorCertificationService.java)和[私证控制器](../../backend/aisports-domains/d10/aisports-table-honor/src/main/java/org/dromara/sports/tables/d10/honor/HonorCertificationController.java)。

最新下拉为自有 [SportSelect](../../plus-ui/src/components/sport-ui/SportSelect.vue)与[共享控件样式](../../plus-ui/src/assets/styles/sport-controls.scss)，[赛事筛选](../../plus-ui/src/components/sport-ui/SportEventFilters.vue)及本人认证/平台核实/宣传表单接入。全src实际原生select只保留该组件不可见的浏览器约束辅助节点，不向用户显示系统灰底菜单；既有复杂el-select沿用功能并统一浅色菜单/中性焦点。

## 已观察证据及其边界

| 验证 | 实际结果与不可变回执 | 证明范围 |
| --- | --- | --- |
| 首页入口与紧凑筛选 | 新下拉接入后258项；`.local/product-release-20261011/entry-ui-1791691539827/receipt.json` | 5190/5192四个宽度，实际combobox/option点击、链接、筛选、空结果、焦点、防拖拽、卡片对齐和助手开关；无业务写。旧258项回执保留，不重复累加 |
| 下拉与单边界输入焦点 | 最新118项；`sport-select-1791693448552/receipt.json` | 主站/演练390及1440首页/目录，实际指针及方向键/Home/End/Enter/Escape/Tab/外点关闭、浮层上下定位和屏幕限制；空登录单边界focus与红错，无登录/模型/业务写 |
| 工作账号单边界 | 38项；`work-login-focus-1791693448564/receipt.json` | 5190/5192×390/1440，实际pointer/keyboard、空字段blur校验及带错focus；wrapper一条边界、内层无框，无登录提交或凭据 |
| 日期及teleport单边界 | 44项；`sport-date-focus-1791693422132/receipt.json` | 普通本人生日和主办方未保存datetime表单390/1440；实际每个input→inner wrapper→date container祖先恰好一条stroke，移焦到浮层后原输入仍灰绿，selected/today标识灰绿，Esc/关闭不保存，无写请求；range仅源规则覆盖 |
| 浮动助手历史切片 | 95项；`floating-assistant-1791689284566/receipt.json` | 当时匿名及普通参赛者、实际拖动/键盘/缩放、已有任务恢复和草稿预填；主题卡后续改为选择主题、输入留空，本条不覆盖该新行为 |
| 当前浮窗及焦点 | 246项；`floating-assistant-1791693679164/receipt.json` | 两站真实GET/HEAD，普通A恢复既有任务/未发送草稿、主题芯片与空输入、拖动/键盘/尺寸；含原209范围、24输入焦点、12容器及按钮焦点、1源稳定；输入内border0、wrapper单条solid1px、窗口无outline，关闭按钮仍有单条2px键盘焦点。无新模型、响应stub或业务写 |
| 当前聊天动效 | 98项；`assistant-motion-1791693549248/receipt.json` | 8场景实际440ms进入、540ms FLIP、280ms退出的中间几何及减少动态效果，含同流程成长只读4项和源稳定；不声称FPS或全部设备性能 |
| 消费端当前补验 | 78项成长＋16项身份＋30项资料，共124项；`consumer-refinement-1791690740560/manifest.json` | 普通身份、九档实际规则、私有证明、裁剪取消、认证未保存表单及资料回跳；不是重新真实上传头像 |
| 助手与业务弹窗 | 40项；`assistant-modal-1791690845953/receipt.json` | 390/1440真实段位 dialog及认证未保存 messagebox正常 click；助手原 DOM/草稿恢复；pointer缩放、拖泡/20px键盘、刷新记忆、320×480限制；无写请求/脚本错误 |
| 世界荣誉组件显示 | 28项；`world-honor-components-1791691725319/vitest.json` | 独立Vue SSR合成投影，不连接业务后台；只证明显示规则，不能证明已有荣誉或人工核验 |
| 世界荣誉当前界面 | 37项；`world-honor-ui-1791691931574/receipt.json` | 22项真实普通会话GET、数字名次下拉和dirty放弃；13项独立SSR setContent合成外观；2项零写/脚本错。无业务响应stub，不把合成外观当真实认证 |
| 平台认证只读复查 | 12项；`.local/honor-certification-20261011/review-ui-7a7dedfc-db5a-4d2f-8b07-bbf45b1c1dae/receipt.json` | 既有批准/撤销记录及只读核验快照，不新建或审批认证；现有撤销样本不呈现可编辑下拉，不能由此称平台可编辑表单全部实际验收 |
| 认证服务单元边界 | 定向24项 mock 测试通过；`.local/honor-certification-20261011/unit-97bff6cd-f9aa-45a8-ac83-af0d9b2ae277.json` | 位于本轮66项Java选测内，不重复计数；模拟依赖只证明规则边界 |
| 认证真实 HTTP 与对象存储 | 33项；`actual-39fd23b5-4a5b-410c-aa23-eed5e3778c9a.json` | 真实隔离服务/存储，合成申请、私证往返、跨人/政府/通用媒体拒绝、缺证据拒绝、补正重提、过期版本、派生称号、本人佩戴、双公开及撤销；不是世界事实核验 |
| V037/V038 | 实际主库/原隔离库备份、恢复、前向和重放通过；`.local/product-release-20261011/global-migration-2b16e4ad2c234a4da183f25ec5e5a1c3/receipt.json` | 旧事实保留；已应用迁移不重写 |
| 运行包刷新 | `.local/product-release-20261011/runtime-refresh-80aef47a68364630a1fa4d6dc2426749/receipt.json` passed=true | JAR `ffe94e14798cbee4627193e6456d17c766aba852ef1ddac46118c8644e0ee464`，现有数据库和会话事实保留 |
| 主站真实表单 | 7项；`.local/main-access/post-release-018d0896-936d-4426-a391-c9ba8ddbefb7/receipt.json` | 原管理员密码实际登录、授权响应、事实不变；无重置、模型或认证写 |
| 最终前端 | `.local/product-release-20261011/frontend-refinement-1ec202128d3f42bb8483a643b5060df1/receipt.json` passed=true | 类型检查、开发构建通过；检查期间源码未变，包含最后日期容器/焦点和助手容器；旧大分块提示保留，不证明每项业务已验收 |
| 当前运行观察 | 20项；`runtime-observation-866f1492-65fd-4fab-8f8f-09fbca07a033/receipt.json` | 现场loopback端口归属、列明GET、四旧JSON及当前JAR摘要核对，不将health/HTTP200当完整业务通过 |

表中缩写回执 `floating-assistant`、`consumer-refinement`、`assistant-modal`、`sport-select`、`work-login-focus`、`sport-date-focus`、`world-honor-components`、`world-honor-ui` 均位于 `.local/product-release-20261011`；`unit`、`actual` 位于 `.local/honor-certification-20261011`。只提供本机证据位置，不网页公开会话或私有材料。消费端 manifest SHA-256 为 `825bacb411f9f3a8d221b233de821f6c3ae5ee53b3cacba91bc2a8dd331128b4`；弹窗40项回执为 `b4fecd026246004d315e8405f26cf2230e3e4487f4d99ce03eda9ed3c8700ae5`；认证HTTP回执为 `f17c281ad1817611db4cec6f466a6a4a625bf828683a10e12dd50bdadd9368a9`；新入口258项为 `04921aee4d7cb2c0c415423f25580d00012918d4784492418a02d63303356e7a`。SSR28为 `7988eae55d41b34d70048502b96f79779a37a14056e8203374aebad7f0b55a17`，混合UI37为 `f833de3cefe270c782098908cffd21f5b91ec0dbe989bedbcfc25aa3460abd4a`，对应[世界荣誉外观册](../world-honor-display-20261011/README.md)逐图标明实际或合成。

最终下拉118回执摘要 `51e9c095fa31f350acc15a7b16f4900bf9a3ebf8833279426ba7c309ce044965`、工作38摘要 `2560c49f7227c92dc0e2498bf882ce797a3739b5087e7132ac146881719fd275`、日期44摘要 `cd761264ac5b948825318182f452963913a617b93ddae2f14547d7043195e27a`，三者绑定同一共享控件样式 `3d6a0f6e36c53000b5aca8870e884574da6231c6084696021bf8d2b2d6f41c41`。最终前端回执摘要 `839911dd896b5afe6eddc182b3b880be9dca5b2f56a5f1c22585cac3b720f99e`，运行观察摘要 `dc22bb4aec8f1f54cb38a9c9f4433c266417def8cbbe407998405bb5805735f0`。

最新246回执摘要 `d891820325a1ccd90b1c8eac78e19f8c0292d2599a38e456331a10491de5adeb`，98回执摘要 `e4b54459349a7680c0c9d54199e9e513260c7d53877a20e0ff4c52a1198a3d0d`。旧209/97及更早95不重复累加，保留各自当时的范围和源版本。

认证样本全部合成，透明PNG没有真实姓名或奖项，来源为测试地址。流程结束已通过真实动作撤销该认证、停戴/停公开并恢复名片原偏好；成长积分、成长事实和成长奖励前后不变。历史申请/证明留存复查，不把删除历史当成测试收尾。

## 精确人工开放与事实保留

候选8082及主站8080分别完成六项人工 UI 选择性开放：`honor.certification.save`、`submit`、`review`、`wear`、`visibility`、`proof.upload`。本人成员保存/佩戴/公开仍核验本人；审核额外要求平台负责人，普通政府、主办方、其他申请者或Agent不得批准。

两份发布回执均10项通过，实际生成 PostgreSQL 备份，核验当前 JAR、源摘要及定义摘要；九类既有业务表加 `asp_honor` 共十张表完整行指纹保持不变，无关渠道保持不变，认证 Agent 开放数为0：

- 候选：`.local/honor-certification-release-20261011/candidate-32e8962e-6a38-4f3a-88a9-39abcd632290/receipt.json`，SHA-256 `1160ff6843274cab58312072c2e9304066e1b039ea3b5919e257cadeb70622dd`。
- 主站：`.local/honor-certification-release-20261011/main-cdeb0ba1-f6a4-4782-bb8f-29f262b94aa4/receipt.json`，SHA-256 `c5b36b2899b54defd07e48f9349a041ab262c1c11374935cbd1f17f02c8d066e`。

主站当前人工 UI 56、只读 Agent 5、Agent写动作0。本轮没有开放AI认证、政府审批、资金确认或正式结果动作。发布只改能力渠道与审计，不在主站创建合成荣誉或重演报名、账款、赛果及成长。主站管理员资料保留在本机 DPAPI 和受保护说明中，沿用原密码，网页不提供密码文件链接。

## 失败历史、当前封存与运行入口

旧运行/模型/权限/界面失败和本轮测试失败保留。弹窗脚本前两次在已隐藏的聊天控件上使用可访问角色定位及等待标题时超时；实际弹窗已出现、助手已隐藏。改为读取同一隐藏 DOM 后完整40项复测通过，旧两份回执不改写。下拉脚本最初过早判断退场DOM删除及让空字段失焦触发既有校验，分别造成测试断言失败；改为等待浮层隐藏、初始焦点先验证后另测红错，完整118项通过，旧回执保留。合成认证路径的真实通过不把先前 mock、预检或未执行的场景标成通过。

日期窄验首次遇失效主办方会话401，未冒充业务故障；随后仅恢复既有会话，未初始化、重放或改业务。日期测试过早读取stroke过渡起始色、桌面两个创建入口未精确定位，分别保留失败回执。初次日期36项只核对目标层和input，没证明所有祖先无叠框；补查确实发现date容器与inner wrapper均带stroke。精准清除日期容器、保留真正range owner后，44项遍历全部实际焦点祖先并复查浮层移焦后的原输入通过；旧36/42项不改写成当前完整证明。工作账号38项与下拉118项再次绑定最终共享样式。

**当前代码与本轮界面验证已封存：**最后全仓类型、构建及检查期间源不变通过，最新聊天主题、焦点246和动效98通过，源保持冻结。当前JAR、最终前端、对应源码和原四份JSON由[本轮独立JSON](evidence-bubble-honor.json)严格核对匹配，SHA-256 `63e6eb81e82bc610056bffd4cbd0e04890b17e1aa454c5acda2d57263c155d44`。前面编译和测试保留为各自历史源版本，不改写失败、不把258/118/124/40、SSR28/UI37、日期44、聊天246/98及HTTP33累计成完整业务通过。

[第三轮正式界面截图册](../global-product-20261011-v3/README.md)收录43张列明场景的实际截图，清单摘要 `c27831706c5c66440038ef504b887fb12532457d423fcc25730e9c2b4efa4b85`；世界荣誉的独立合成外观仍在单独显示册并保留合成标记。新静态原图和派生摘要见[第四版素材说明](../05-ui/assets-20261011-v4/README.md)。图片及外观不替代本人获奖、成长和真实业务事实。

实际入口统一使用 PowerShell7。维护人员运行 `scripts/Resume-Phase1.ps1`、`scripts/Restart-Phase1Verification.ps1`、`scripts/Start-DemoFrontend.ps1` 恢复已有运行环境；不重新初始化或重放业务。验证入口为 `scripts/Test-AssistantModalBoundary.mjs`、`scripts/Test-FloatingSportsAssistant.mjs`、`scripts/Test-ProductEntryUI.mjs`、`scripts/Test-SportSelectUi.mjs`、`scripts/Test-WorkLoginFocusUi.mjs`、`scripts/Test-SportDateFocusUi.mjs`、`scripts/Test-ProductProfileEntry.mjs` 和 `scripts/Test-HonorCertification.mjs`；最后一项会在指定隔离库创建并撤销合成认证，不得在主库直接执行。发布入口 `scripts/Release-HonorCertificationUi.ps1` 仅在匹配冻结证据/JAR和既有权限时串行办理，不因手册存在而重跑已成功发布。

原四份冻结JSON已只读核对未变：一期本机报告 `6d18927802b75867876af4753f6cdc2b7151689b92af35eca8dc744ba687a0ee`，产品组件报告 `855006d8e09bb1d2839c0bda1152dffa17a28be59a3d3fb6449cf659a7972bf5`，正式产品第一轮 `b9ae393cfd2e3bec596d5bfb0783489f91039d0b5d43cdadc4e7126a390991d5`，全局视觉第二轮 `04b80a823809cf6a5df3e222c2022999749a602b9bab5a8eb96df2f7513e1e71`。它们不用于覆盖本次后续源码。

仍需真实世界荣誉的外部依据与首次实际核实；实时图片供应商、真实业务短信/首次注册恢复、真实资金、现场比赛和正式证明、投诉收尾、普通岗位及全面赛事闭环仍沿[一期未完成事项](../01-development/一期未完成事项.md)继续。真机软键盘、冷启动/容量及广泛无障碍未全验。用户的最终视觉满意度以实际反馈为准，测试数量不换算总进度百分比。
