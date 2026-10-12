# 成长名片与段位展示

`GrowthRankPresentation` 依据当前已发布规则输出 `rank`、`rankIndex`、`maxRankIndex`、`policyVersion` 和完整 `ranks` 门槛列表。最高等级不再固定为索引 6，星耀可继续到王者。当前显示变化不修改积分、历史事实或正式荣誉。

本人查询及有效队员查询继续由 `GrowthService` 校验。称号佩戴仍要求本人或当前队长，并绑定已有 verified 荣誉；静态图片不构成授权或获奖。

参赛界面以共享 `SportsRankBadge`、`AvatarFrame`、`SportsTitleBadge` 显示真实段位和已佩戴称号。7 类资源位于 `/images/sports/ranks/*.webp`、`/images/sports/frames/*.svg`；新星用基础框，历史“荣耀”保留文字并兼容既有高阶视觉。未达到等级只在段位目录中显示锁定状态，不作为当前头像佩戴。

`GrowthRankPresentationTest` 验证零分新星、原青铜门槛、星耀下一等级、王者封顶及旧荣耀规则。真实普通角色界面与权限边界由本轮独立验收脚本记录；不得重放报名、资金或比赛事实来制造等级。
# 2026-10-11 追加：传奇与只读称号目标

段位展示沿用当前活动规则的最大索引，九级规则中王者继续至传奇，历史七、八级仍保持原名称和终点。新增展示测试，不更新用户积分。

`growth.card` 追加可选 `titleGoals`：个人首次报到、首次完赛、赛场常客，小队默契初成、默契搭档、久经赛场。每项返回 `code/title/milestone/required/current/remaining/eligible/awarded`；门槛来自服务器当前运动规则，次数来自已有成长汇总，`awarded` 仅依据实际 verified 荣誉。条件已达到不等于已经授予，历史已获与当前新门槛分别呈现。该投影没有写入、补发或佩戴操作。

四个新增 local 单测覆盖未伪发奖、当前自定义门槛、团队有效完赛与个人报到分开，以及历史真实已获保留。等待根代理统一 JAR/迁移后再执行普通角色接口及页面补验。外部赛事冠亚季军认证独立于成长段位和这六类参与称号，不进入本投影。

