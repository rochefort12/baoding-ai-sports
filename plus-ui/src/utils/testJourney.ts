export const participantSteps = [
  { to: '/portal/login', label: '1. 登录或注册', hint: '平台账号用手机号。忘记密码在登录页。管理员仍走后台用户名登录。' },
  { to: '/portal/identity', label: '2. 本人档案', hint: '先保存档案。手机号是注册号码，不能改。注销也在这一页。' },
  { to: '/portal/organization', label: '3. 我要办赛', hint: '提交组织申请。通过后点「进入组织」。' },
  { to: '/public/events', label: '4. 公开赛事', hint: '看已发布的比赛，从这里进入报名。' },
  { to: '/portal/teams', label: '5. 长期队伍', hint: '队长建队、邀请；队员接受。当前队伍和退出记录分开。' },
  { to: '/portal/registration', label: '6. 我的报名', hint: '选项目、填采集项、提交、付款、撤回。已取消或已下架会标在标题上。' },
  { to: '/portal/notices', label: '7. 我的消息', hint: '赛事取消的站内信。短信未接通时不会真的发到手机。' },
  { to: '/portal/results', label: '8. 本人赛果', hint: '只看已确认赛果。取消赛事仍标明历史。' },
  { to: '/portal/proofs', label: '9. 成绩证明', hint: '只看自己的证明，不表示外部等级已核验。' },
  { to: '/portal/feedback', label: '10. 问题反馈', hint: '留下记录，不自动改报名或退款。' }
];

export const organizerSteps = [
  { to: '/org-desk/events', label: '1. 赛事', hint: '新建、发布、下架、恢复公开、取消。取消后可看通知投递。' },
  { to: '/org-desk/registrations', label: '2. 报名审核', hint: '建项目、收费、名额、采集字段、确认到账、冲正、退款、通过或拒绝。' },
  { to: '/org-desk/competition', label: '3. 报到录分', hint: '报到、建场次、保存并确认结果、填写依据后授奖。' },
  { to: '/portal/identity', label: '4. 返回参赛', hint: '顶栏「参赛者」。办赛页顶栏「办赛」可再进来。' },
  { to: '/platform/tools', label: '5. 平台办理', hint: '仅平台管理员。查看档案修改和反馈，关联已关闭账号的证件。' }
];
