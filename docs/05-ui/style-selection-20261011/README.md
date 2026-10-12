# UI 风格候选清单（待用户确认）

2026-10-11。仅检索、截图和资料整理；未安装 skills、未改产品 UI。

## 组件库

| 编号 | 名称 | 适用场景（本项目判断） | 源码 | 实际实例 |
| --- | --- | --- | --- | --- |
| A01 | shadcn-vue | 参赛端与主办方通用底座 | [源码](https://github.com/unovue/shadcn-vue) | [实例](https://shadcn-vue.com/view/dashboard-01) |
| A02 | Nuxt UI | 主办方工作台、个人中心 | [源码](https://github.com/nuxt/ui) | [实例](https://dashboard-vue-template.nuxt.dev/) |
| A03 | PrimeVue / Sakai | 主办方、政府和平台 | [源码](https://github.com/primefaces/primevue) | [实例](https://sakai.primevue.org/) |
| A04 | Naive UI | 表单、报名详情、后台 | [源码](https://github.com/tusen-ai/naive-ui) | [实例](https://www.naiveui.com/zh-CN/os-theme/components/card) |
| A05 | Arco Design Vue | 政府审核与赛事管理 | [源码](https://github.com/arco-design/arco-design-vue) | [实例](https://vue-pro.arco.design/dashboard/workplace) |
| A06 | TDesign Vue Next | 政府和平台 | [源码](https://github.com/Tencent/tdesign-vue-next) | [实例](https://tdesign.tencent.com/starter/vue-next/dashboard/base) |
| A07 | Vuetify | 移动应用感、个人卡片 | [源码](https://github.com/vuetifyjs/vuetify) | [实例](https://vuetifyjs.com/en/components/cards/#horizontal-cards) |
| A08 | Quasar | 移动服务和连续流程 | [源码](https://github.com/quasarframework/quasar) | [实例](https://quasar.dev/vue-components/card/) |
| A09 | Vant | 手机报名、表单和弹层 | [源码](https://github.com/youzan/vant) | [实例](https://vant-ui.github.io/vant/mobile.html#/zh-CN/form) |
| A10 | Inspira UI | 荣誉、头像、匹配成功和成长反馈 | [源码](https://github.com/unovue/inspira-ui) | [实例](https://inspira-ui.com/) |

## 设计与前端 skills

skills 不是固定视觉主题；作者实例、作者网站、技能说明分别标识。未执行任何远端安装或改造指令。

| 编号 | 名称 | 用途 | 截图性质 | 源文件 |
| --- | --- | --- | --- | --- |
| S01 | frontend-design | 给参赛端建立独立视觉语言 | 技能说明，无固定外观 | [技能源文件](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md) |
| S02 | UI UX Pro Max | 先比较方案，再冻结设计规范 | 作者展示站，非效果保证 | [技能源文件](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/blob/main/.claude/skills/ui-ux-pro-max/SKILL.md) |
| S03 | Impeccable | 清理演示式表达，统一页面细节 | 作者展示站，非固定皮肤 | [技能源文件](https://github.com/pbakaus/impeccable/blob/main/skill/SKILL.src.md) |
| S04 | interface-design | 主办方、政府、平台的信息层级 | 作者界面实例 | [技能源文件](https://github.com/Dammyjay93/interface-design/blob/main/.claude/skills/interface-design/SKILL.md) |
| S05 | web-design-guidelines | 让报名流程容易操作、易于恢复 | 官方交互规范页面 | [技能源文件](https://github.com/vercel-labs/agent-skills/blob/main/skills/web-design-guidelines/SKILL.md) |
| S06 | emil-design-eng | 头像、席位、加入和准备反馈 | 作者组件实例，非技能生成结果 | [技能源文件](https://github.com/emilkowalski/skills/blob/main/skills/emil-design-eng/SKILL.md) |
| S07 | improve-animations | 避免跳动、等待无反馈和过度庆祝 | 技能说明，无固定外观 | [技能源文件](https://github.com/emilkowalski/skills/blob/main/skills/improve-animations/SKILL.md) |
| S08 | vue-best-practices | 实现自己的可复用产品组件 | 技能说明，无固定外观 | [技能源文件](https://github.com/vuejs-ai/skills/blob/main/skills/vue-best-practices/SKILL.md) |
| S09 | vue-testing-best-practices | 普通角色和手机流程验收 | 技能说明，无固定外观 | [技能源文件](https://github.com/vuejs-ai/skills/blob/main/skills/vue-testing-best-practices/SKILL.md) |
| S10 | vue-router-best-practices | 登录后回原任务、退出与切换角色 | 技能说明，无固定外观 | [技能源文件](https://github.com/vuejs-ai/skills/blob/main/skills/vue-router-best-practices/SKILL.md) |

## 选择建议（仅为本项目判断）

先从 A01/A02 比较整体清晰度与轻盈感，A09 参考手机表单，A10 参考荣誉和集结动效。管理端可对比 A02/A03/A05/A06 的信息密度。技能重点对比 S03 的精简与细节评审、S04 的产品界面层级、S05 的交互规范和 S06/S07 的动画方法；S08—S10 用于组件、导航和验收。

不能直接套用十套样式。选定参赛端与管理端方向后冻结字体、色彩、间距、组件状态、动效和手机操作规则，再实施同一品牌下的多端页面。

## 采集边界

20 张实际 Edge 截图，目录 screenshots；原始采集回执和失败轮次单独保存。A02 首个错误地址 Cloudflare403，替换为模板README中的正确地址后成功；A06 首次未等渲染完成，延长实际加载后成功；GitHub部分技能页初次503，重试后真实页面可见；A04直达文档HTTP404但客户端实际渲染组件，未假称HTTP成功；A06演示监测脚本错误不视为本项目功能通过。

截图与作者资料只用于风格选择，不代表平台已经采用、业务可用性验收或所有第三方许可已审核。S05未发现明确的顶层许可证，采用前继续复核；其余许可记录见catalog.json。
