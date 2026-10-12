# 体育产品界面组件

Vue 3 + TypeScript 原生组件，样式集中在 `src/assets/styles/design-system.scss`。图标沿用 ConsumerIcon，自绘品牌标记和 CourtScene SVG 不依赖图片服务。

| 组件 | 约定 |
| --- | --- |
| SportButton | 原生 button；primary/secondary/ghost/danger，三种大小；busy 同时禁用并设置 aria-busy，默认 type=button |
| SportField | 原生 input；显式 label、稳定 ID、错误说明关联；密码显隐；属性传给输入框，业务校验由页面负责 |
| SportSelect | 自有浅色浮层；v-model保留string/number，options为`{value,label,disabled?}`；change值不转类型；required/name保留原生约束，id/aria-label/testid透传combobox。方向键、Home/End、Enter、Escape、外部点击及禁用；不调用业务或模型 |
| SportCard | 卡片标题、操作、正文和页脚插槽；flat/dark；不承担业务加载 |
| SportPill | 文本状态；green/neutral/gold/red；颜色不能代替状态文字 |
| SportTabs | 条件筛选按钮组；支持左右键、Home、End，选择和焦点同步；并非内容页签 ARIA 模式 |
| SportMetric | 真实数值和统计含义；可链接到待办；未知数值显示破折号，禁止填充展示数据 |
| SportHeader | 页面标题、说明和操作区；不加入宣传口号 |
| SportEmpty | 空态、加载、失败和后续操作；动画遵循减少动态效果偏好 |
| CourtScene | 原生 SVG 球场；每实例独立渐变 ID，不替代真实赛事海报 |

`useAuthFields.ts` 处理参赛登录、注册和密码恢复校验；保持手机号、密码创建和验证码边界。只在失焦/提交时校验，加载验证码不能给尚未填写的输入框报错。验证码加载失败阻止登录，并提供重试。

体育端通过 ConsumerPageHeader/ConsumerState 接入共享标题和状态。首页筛选、赛事状态、房间操作、成长主要按钮、主办方统计和政府卡片使用自有组件。工作账号登录的账号、密码和图形码使用 SportField，沿用若依校验与租户/第三方授权处理。

复杂表格、日期选择、材料上传、弹窗、审核和资金表单复用已有控件；通过同一视觉样式收口，不重复实现权限与业务动作。样式仅在全局入口按旧样式→设计系统的顺序装配，页面不重复导入全局外观。

下拉与中性焦点集中于`src/assets/styles/sport-controls.scss`；键盘焦点保留低对比灰绿轮廓，错误仍显示红边。SportSelect的选项浮层挂到body并计算上下位置，不使用系统灰底菜单。自动验证按真实combobox和option点击/键盘操作，不使用`selectOption`操作辅助原生约束控件。

验证入口：`Test-NativeProductUI.mjs` 为隔离真实服务上的交互，`Test-NativePublicUI.mjs` 为主环境匿名界面，`Test-ProductScreens.mjs` 检查各端页面。凭据从私有本机验证状态读取，禁止输出请求正文。
