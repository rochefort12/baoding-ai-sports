"""Approved 2026-10-10 phase-one objects. Loaded by catalog; no automatic capability opening."""
def extend(m):
    table,c,ref,txt,time,js,state,num = (getattr(m,n) for n in ('table','c','ref','txt','time','js','state','num'))
    existing={t.name:t for t in m.TABLES}
    existing['asp_organization_application'].columns.append(c('assigned_reviewer_id','bigint','指定政府审核经办人；普通岗位只能处理明确分配给本人的申请',True))
    existing['asp_competition_unit'].columns.append(c('competition_type_id','bigint','统一比赛类型；旧数据按明确人数匹配，不能猜测未支持类型',True,reference='asp_competition_type'))
    existing['asp_registration'].columns.append(c('manager_account_id','bigint','稳定报名管理人，独立于当前队长与组织审核经办人',True,reference='asp_account'))
    existing['asp_match'].columns.append(txt('court_name','本场比赛球场名称，不表示资源预订交易',True,80))
    existing['asp_event'].columns.append(c('closure_status','varchar(32)','赛后问题与资金收尾状态',default="'open'",check="closure_status IN ('open','wrap_up','closed')"))
    existing['asp_growth_record'].columns.extend([
        c('sport_id','bigint','成长所属运动',True,reference='asp_sport'),c('event_id','bigint','来源赛事',True,reference='asp_event'),
        txt('milestone','checkin finish team_finish 或 correction；由业务事实确定',True,64),
        c('points_delta','integer','追加的成长分变化；负值为事实纠正补偿',default='0'),
        txt('source_key','事实唯一来源，包含被纠正原记录编号',True,160)
    ])
    existing['asp_growth_record'].unique.append(('source_key','source_key IS NOT NULL'))
    existing['asp_honor'].columns.extend([c('sport_id','bigint','所属运动；历史奖项可空',True,reference='asp_sport'),txt('title_code','成长称号规则编码；正式奖项可空',True,64)])
    existing['asp_ai_task'].columns.extend([
        c('provider_consent','boolean','对当前资料任务的实际模型供应商告知确认',default='false'),
        c('provider_name','varchar(64)','实际获授权供应商；旧百炼授权保留原含义',default="'legacy-bailian'"),
        c('consent_version','varchar(64)','实际告知版本',default="'legacy'")
    ])
    existing['asp_ai_task'].checks[:]=[check for check in existing['asp_ai_task'].checks if 'bailian_consent' not in check]
    existing['asp_ai_task'].checks.append("bailian_consent = true OR (provider_consent = true AND provider_name = 'deepseek')")
    table('competition_type','D04','运动下的比赛类型；人数和报名形式用于办赛、房间和报名的共同约束',[
        ref('sport_id','asp_sport','所属运动'),txt('code','稳定类型编码',size=64),txt('name','比赛类型名称'),
        state('entry_type','individual pair team'),num('min_members','最低参赛人数'),num('max_members','最高参赛人数'),
        state('capability_status','catalog registration manual automatic verified'),state('status','active disabled')
    ],False,checks=['min_members > 0','max_members >= min_members'],unique=[('sport_id, code',None)])
    table('profile_display','D02','公开运动名片与真实参赛档案分开；未选择公开时只向本人及必要队友展示',[
        ref('account_id','asp_account','本人账号'),txt('nickname','展示昵称，不回退真实姓名',size=40),
        c('avatar_file_id','bigint','头像文件编号；用途受控',True),txt('avatar_style','内置头像样式',size=32),
        txt('tagline','运动签名',True,160),c('public_visible','boolean','本人选择对外公开',default='false'),
        js('sport_preferences','偏好运动编号；不代表资格或实力')
    ],False,unique=[('account_id',None)])
    table('team_room','D03','本场参赛房间，与长期队伍及已提交名单分开；房主计入成员人数',[
        ref('unit_id','asp_competition_unit','赛事报名单元'),ref('competition_type_id','asp_competition_type','比赛类型'),
        ref('host_account_id','asp_account','当前房主'),ref('team_id','asp_team','可选长期代表队',True),
        txt('name','房间名称',size=100),state('status','forming ready submitted closed'),
        c('registration_id','bigint','成功生成的报名草稿或事实编号',True),txt('announcement','房间公告',True,1000)
    ],False)
    table('team_room_member','D03','参赛房间成员；加入不等于本人报名声明确认',[
        ref('room_id','asp_team_room','房间'),ref('unit_id','asp_competition_unit','同项目防重复参赛房间占位'),ref('account_id','asp_account','成员'),ref('person_id','asp_person','本人档案'),
        state('status','active left'),c('ready','boolean','本人备赛确认，不能替代参赛声明',default='false'),
        time('joined_at','加入时间'),time('left_at','离开时间',True)
    ],False,unique=[('room_id, account_id',"status='active'"),('unit_id, account_id',"status='active'")])
    table('recruitment','D03','缺员招募；只展示受控运动名片，不公开私有联系与材料',[
        ref('room_id','asp_team_room','招募房间'),ref('creator_account_id','asp_account','发布人'),
        txt('message','招募介绍',size=500),state('status','open filled closed'),time('expires_at','招募截止')
    ],False,unique=[('room_id',"status='open'")])
    table('matching_request','D03','自动匹配排队意向；不占赛事正式报名名额',[
        ref('unit_id','asp_competition_unit','同一报名项目'),ref('account_id','asp_account','排队本人'),
        ref('room_id','asp_team_room','补充现有房间；个人匹配可空',True),js('preferences','本人选择的时间等偏好'),
        state('status','waiting offered accepted cancelled expired'),time('expires_at','意向截止')
    ],False,unique=[('unit_id, account_id',"status IN ('waiting','offered')")])
    table('matching_offer','D03','匹配确认邀请；每名成员本人接受，120秒确认席位与正式报名名额分开',[
        ref('unit_id','asp_competition_unit','报名项目'),ref('room_id','asp_team_room','现有或接受后创建的房间',True),
        state('status','pending accepted declined expired'),time('expires_at','确认期限')
    ],False)
    table('matching_offer_member','D03','匹配邀请的一名接收者；全部接受后才加入房间',[
        ref('offer_id','asp_matching_offer','邀请'),ref('account_id','asp_account','接收人'),
        ref('request_id','asp_matching_request','来源排队',True),state('status','pending accepted declined'),
        time('answered_at','本人回答时间',True)
    ],False,unique=[('offer_id, account_id',None)])
    table('room_interaction','D03','房间内可见欢迎与鼓励；不是社区或私聊平台',[
        ref('room_id','asp_team_room','房间'),ref('account_id','asp_account','发送人'),
        state('kind','welcome encourage ready announcement'),txt('text','可见消息',size=500),txt('request_key','防重键',size=128)
    ],False,unique=[('account_id, request_key',None)])
    table('governance_grant','D01','政府后台账号对指定主办方的管理范围；不能由模型或普通经办人自授',[
        c('sys_user_id','bigint','政府若依用户编号'),ref('organization_id','asp_organization','指定主办方'),
        js('permissions','准入、资格管理、汇总和投诉权限'),state('status','active revoked'),time('valid_until','授权截止',True)
    ],False,unique=[('sys_user_id, organization_id',"status='active'")])
    table('growth_policy','D10','版本化成长规则；段位不是官方竞技实力评级',[
        ref('sport_id','asp_sport','所属运动'),txt('code','规则编码',size=64),num('revision','规则版本'),
        js('rules','版本化段位门槛、奖励及称号阈值；兼容历史七、八级及当前九级；新星基础级，王者9600、传奇19200为默认门槛，可另发版本调整'),state('status','draft active superseded')
    ],False,checks=['revision > 0'],unique=[('sport_id, code, revision',None)])
    table('growth_profile','D10','由可追溯成长事实汇总的个人或队伍运动成长；可重建，不是原始事实',[
        state('owner_type','person team'),c('owner_id','bigint','本人档案或长期队伍编号'),ref('sport_id','asp_sport','运动'),
        num('points','当前有效成长分'),num('checkin_count','真实报到赛事数'),num('finish_count','有效完赛赛事数'),
        txt('policy_version','汇总使用规则版本',size=64)
    ],False,unique=[('owner_type, owner_id, sport_id',None)])
    table('title_equipment','D10','本人或队长选择当前佩戴的成长称号；授予来源由荣誉事实保留',[
        state('owner_type','person team'),c('owner_id','bigint','本人或队伍编号'),ref('sport_id','asp_sport','运动'),
        txt('title_code','规则目录中的称号编码',size=64),ref('honor_id','asp_honor','获授荣誉事实；欢迎样式可空',True),
        txt('frame_style','允许的头像边框样式',size=32)
    ],False,unique=[('owner_type, owner_id, sport_id',None)])
    table('capability_version','D13','经过实现与测试的能力版本；描述不是授权',[
        txt('code','能力编码',size=160),num('revision','版本'),js('definition','参数、结果、读写范围、确认和权限'),
        txt('source_hash','定义SHA256',size=64),state('status','draft tested published retired')
    ],False,checks=['revision > 0'],unique=[('code, revision',None)])
    table('capability_activation','D13','能力在人工、Agent和系统渠道的明确开放指针',[
        txt('code','能力编码',size=160),ref('capability_version_id','asp_capability_version','已发布版本'),
        state('channel','ui agent system'),c('enabled','boolean','允许新调用',default='false')
    ],False,unique=[('code, channel',None)])
    table('action_execution','D13','统一动作终态回执；成功与业务同事务，失败独立留痕，不存私有完整响应',[
        txt('action_code','动作编码',size=160),txt('actor_type','真实主体类型',size=32),c('actor_id','bigint','主体编号'),
        txt('tenant_scope','服务器确定的组织范围',True,20),txt('channel','调用渠道',size=16),
        txt('request_key','防重请求键',size=128),txt('payload_hash','输入摘要',size=64),
        state('status','succeeded failed denied'),js('result_reference','结果对象和允许的状态摘要'),
        txt('error_code','失败代码',True,64),c('run_id','bigint','关联智能体运行',True),time('occurred_at','执行结束')
    ],False,unique=[('actor_type, actor_id, action_code, request_key',"status='succeeded'")])
    table('agent','D13','智能体定义，按平台、业务域和职能分层；没有原始SQL能力',[
        txt('code','稳定编码',size=64),txt('name','名称'),state('layer','global domain function'),
        txt('domain_scope','体育业务域范围',True,32),state('status','active disabled')
    ],False,unique=[('code',None)])
    table('agent_version','D13','智能体提示词与模型的可追溯版本；只记录可见业务指引',[
        ref('agent_id','asp_agent','智能体'),num('revision','版本'),txt('model_name','固定接口模型名',size=80),
        c('instruction','text','可信平台提示词，不能由上传材料改写'),js('budget','深度、调用和时间预算'),state('status','draft active retired')
    ],False,checks=['revision > 0'],unique=[('agent_id, revision',None)])
    table('agent_grant','D13','智能体能力及委派上限；与委托人实时权限取交集',[
        ref('agent_id','asp_agent','智能体'),txt('capability_code','允许能力或delegate目标',size=160),
        js('scope','能力、组织和对象上限'),state('status','active revoked')
    ],False,unique=[('agent_id, capability_code',"status='active'")])
    table('agent_run','D13','服务端签发的运行身份与进度；不保存密钥或隐藏思考',[
        ref('agent_version_id','asp_agent_version','锁定版本'),txt('actor_type','委托人主体类型',size=32),c('actor_id','bigint','委托人编号'),
        c('parent_run_id','bigint','父运行',True),c('root_run_id','bigint','根运行',True),js('scope','服务器确定的对象和权限范围'),
        txt('goal','用户可见目标',size=2000),state('status','running waiting_children waiting_input waiting_confirmation completed failed stopped'),
        num('depth','绝对委派深度'),num('tool_count','本轮已调用工具数'),num('tokens_used','供应商报告的累计用量'),
        num('tokens_reserved','正在执行轮次预留用量；根任务统一核对，已观察结算释放，未知超时保守计费'),
        c('round_key','varchar(64)','当前预算结算轮次的单向摘要；不是身份凭据，防止旧线程释放新轮次预算',default="''"),
        txt('token_hash','运行令牌摘要，原令牌不入库',size=64),time('expires_at','运行令牌截止'),
        time('started_at','开始'),time('ended_at','结束',True),txt('stop_reason','停止原因',True,64)
    ],False)
    table('agent_step','D13','可见模型、工具和委派步骤摘要，不包含材料正文和隐藏思考',[
        ref('run_id','asp_agent_run','运行'),num('sequence','顺序'),state('kind','model tool delegate confirmation control'),
        txt('name','模型或能力名称',size=160),state('status','started succeeded failed denied'),js('summary','可见状态、来源引用与用量')
    ],False,unique=[('run_id, sequence',None)])
    table('agent_message','D13','本人可恢复的可见对话；用途受控，不向其他人共享',[
        ref('run_id','asp_agent_run','运行'),state('role','user assistant'),c('content','text','用户可见文本；不存密钥或隐藏思考'),
        js('blocks','经过校验的表单、确认、回执和跳转块')
    ],False)
    table('action_confirmation','D13','登录本人对特定能力、输入摘要和对象版本的一次确认',[
        ref('run_id','asp_agent_run','关联运行',True),txt('actor_type','确认主体类型',size=32),c('actor_id','bigint','确认人编号'),
        txt('action_code','动作',size=160),txt('payload_hash','确认内容摘要',size=64),js('object_versions','对象及预期版本'),
        state('status','pending confirmed consumed expired'),time('expires_at','有效期限'),time('confirmed_at','本人点击确认',True)
    ],False)
    table('complaint_message','D13','投诉回复、处理与重新打开的追加记录；只向获授权当事方展示',[
        ref('complaint_id','asp_complaint','投诉'),txt('actor_type','本人、主办方或政府角色',size=32),c('actor_id','bigint','处理主体'),
        txt('action','回复、转交、关闭或重开',size=32),txt('message','可见回复与处理依据',size=2000),time('occurred_at','发生时间')
    ],False)
