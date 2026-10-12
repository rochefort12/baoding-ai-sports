-- V030: additive phase-one objects. Existing identities, receipts and snapshots remain unchanged.

SET LOCAL TIME ZONE 'Asia/Shanghai';

CREATE TABLE asp_competition_type (
    id bigint NOT NULL PRIMARY KEY,
    sport_id bigint NOT NULL,
    code varchar(64) NOT NULL,
    name varchar(100) NOT NULL,
    entry_type varchar(32) NOT NULL CHECK (entry_type IN ('individual', 'pair', 'team')),
    min_members integer NOT NULL CHECK (min_members >= 0),
    max_members integer NOT NULL CHECK (max_members >= 0),
    capability_status varchar(32) NOT NULL CHECK (capability_status IN ('catalog', 'registration', 'manual', 'automatic', 'verified')),
    status varchar(32) NOT NULL CHECK (status IN ('active', 'disabled')),
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
    CHECK (min_members > 0),
    CHECK (max_members >= min_members)
);

CREATE UNIQUE INDEX uq_asp_competition_type_2539bdab90 ON asp_competition_type (sport_id, code);

COMMENT ON TABLE asp_competition_type IS '运动下的比赛类型；人数和报名形式用于办赛、房间和报名的共同约束';

COMMENT ON COLUMN asp_competition_type.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_competition_type.sport_id IS '所属运动';

COMMENT ON COLUMN asp_competition_type.code IS '稳定类型编码';

COMMENT ON COLUMN asp_competition_type.name IS '比赛类型名称';

COMMENT ON COLUMN asp_competition_type.entry_type IS '独立业务状态；合法值不等于业务已获批准：individual pair team';

COMMENT ON COLUMN asp_competition_type.min_members IS '最低参赛人数';

COMMENT ON COLUMN asp_competition_type.max_members IS '最高参赛人数';

COMMENT ON COLUMN asp_competition_type.capability_status IS '独立业务状态；合法值不等于业务已获批准：catalog registration manual automatic verified';

COMMENT ON COLUMN asp_competition_type.status IS '独立业务状态；合法值不等于业务已获批准：active disabled';

COMMENT ON COLUMN asp_competition_type.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_competition_type.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_competition_type.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_competition_type.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_competition_type.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_competition_type.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_profile_display (
    id bigint NOT NULL PRIMARY KEY,
    account_id bigint NOT NULL,
    nickname varchar(40) NOT NULL,
    avatar_file_id bigint,
    avatar_style varchar(32) NOT NULL,
    tagline varchar(160),
    public_visible boolean NOT NULL DEFAULT false,
    sport_preferences jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0)
);

CREATE UNIQUE INDEX uq_asp_profile_display_4004d8b172 ON asp_profile_display (account_id);

COMMENT ON TABLE asp_profile_display IS '公开运动名片与真实参赛档案分开；未选择公开时只向本人及必要队友展示';

COMMENT ON COLUMN asp_profile_display.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_profile_display.account_id IS '本人账号';

COMMENT ON COLUMN asp_profile_display.nickname IS '展示昵称，不回退真实姓名';

COMMENT ON COLUMN asp_profile_display.avatar_file_id IS '头像文件编号；用途受控';

COMMENT ON COLUMN asp_profile_display.avatar_style IS '内置头像样式';

COMMENT ON COLUMN asp_profile_display.tagline IS '运动签名';

COMMENT ON COLUMN asp_profile_display.public_visible IS '本人选择对外公开';

COMMENT ON COLUMN asp_profile_display.sport_preferences IS '偏好运动编号；不代表资格或实力；必须按版本校验结构';

COMMENT ON COLUMN asp_profile_display.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_profile_display.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_profile_display.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_profile_display.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_profile_display.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_profile_display.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_team_room (
    id bigint NOT NULL PRIMARY KEY,
    unit_id bigint NOT NULL,
    competition_type_id bigint NOT NULL,
    host_account_id bigint NOT NULL,
    team_id bigint,
    name varchar(100) NOT NULL,
    status varchar(32) NOT NULL CHECK (status IN ('forming', 'ready', 'submitted', 'closed')),
    registration_id bigint,
    announcement varchar(1000),
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0)
);

COMMENT ON TABLE asp_team_room IS '本场参赛房间，与长期队伍及已提交名单分开；房主计入成员人数';

COMMENT ON COLUMN asp_team_room.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_team_room.unit_id IS '赛事报名单元';

COMMENT ON COLUMN asp_team_room.competition_type_id IS '比赛类型';

COMMENT ON COLUMN asp_team_room.host_account_id IS '当前房主';

COMMENT ON COLUMN asp_team_room.team_id IS '可选长期代表队';

COMMENT ON COLUMN asp_team_room.name IS '房间名称';

COMMENT ON COLUMN asp_team_room.status IS '独立业务状态；合法值不等于业务已获批准：forming ready submitted closed';

COMMENT ON COLUMN asp_team_room.registration_id IS '成功生成的报名草稿或事实编号';

COMMENT ON COLUMN asp_team_room.announcement IS '房间公告';

COMMENT ON COLUMN asp_team_room.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_team_room.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_team_room.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_team_room.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_team_room.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_team_room.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_team_room_member (
    id bigint NOT NULL PRIMARY KEY,
    room_id bigint NOT NULL,
    unit_id bigint NOT NULL,
    account_id bigint NOT NULL,
    person_id bigint NOT NULL,
    status varchar(32) NOT NULL CHECK (status IN ('active', 'left')),
    ready boolean NOT NULL DEFAULT false,
    joined_at timestamptz NOT NULL,
    left_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0)
);

CREATE UNIQUE INDEX uq_asp_team_room_member_25616d439d ON asp_team_room_member (room_id, account_id) WHERE status='active';

CREATE UNIQUE INDEX uq_asp_team_room_member_32b8256ff6 ON asp_team_room_member (unit_id, account_id) WHERE status='active';

COMMENT ON TABLE asp_team_room_member IS '参赛房间成员；加入不等于本人报名声明确认';

COMMENT ON COLUMN asp_team_room_member.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_team_room_member.room_id IS '房间';

COMMENT ON COLUMN asp_team_room_member.unit_id IS '同项目防重复参赛房间占位';

COMMENT ON COLUMN asp_team_room_member.account_id IS '成员';

COMMENT ON COLUMN asp_team_room_member.person_id IS '本人档案';

COMMENT ON COLUMN asp_team_room_member.status IS '独立业务状态；合法值不等于业务已获批准：active left';

COMMENT ON COLUMN asp_team_room_member.ready IS '本人备赛确认，不能替代参赛声明';

COMMENT ON COLUMN asp_team_room_member.joined_at IS '加入时间；有时区业务时间';

COMMENT ON COLUMN asp_team_room_member.left_at IS '离开时间；有时区业务时间';

COMMENT ON COLUMN asp_team_room_member.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_team_room_member.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_team_room_member.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_team_room_member.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_team_room_member.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_team_room_member.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_recruitment (
    id bigint NOT NULL PRIMARY KEY,
    room_id bigint NOT NULL,
    creator_account_id bigint NOT NULL,
    message varchar(500) NOT NULL,
    status varchar(32) NOT NULL CHECK (status IN ('open', 'filled', 'closed')),
    expires_at timestamptz NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0)
);

CREATE UNIQUE INDEX uq_asp_recruitment_ead6f77273 ON asp_recruitment (room_id) WHERE status='open';

COMMENT ON TABLE asp_recruitment IS '缺员招募；只展示受控运动名片，不公开私有联系与材料';

COMMENT ON COLUMN asp_recruitment.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_recruitment.room_id IS '招募房间';

COMMENT ON COLUMN asp_recruitment.creator_account_id IS '发布人';

COMMENT ON COLUMN asp_recruitment.message IS '招募介绍';

COMMENT ON COLUMN asp_recruitment.status IS '独立业务状态；合法值不等于业务已获批准：open filled closed';

COMMENT ON COLUMN asp_recruitment.expires_at IS '招募截止；有时区业务时间';

COMMENT ON COLUMN asp_recruitment.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_recruitment.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_recruitment.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_recruitment.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_recruitment.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_recruitment.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_matching_request (
    id bigint NOT NULL PRIMARY KEY,
    unit_id bigint NOT NULL,
    account_id bigint NOT NULL,
    room_id bigint,
    preferences jsonb NOT NULL,
    status varchar(32) NOT NULL CHECK (status IN ('waiting', 'offered', 'accepted', 'cancelled', 'expired')),
    expires_at timestamptz NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0)
);

CREATE UNIQUE INDEX uq_asp_matching_request_e7775cf341 ON asp_matching_request (unit_id, account_id) WHERE status IN ('waiting','offered');

COMMENT ON TABLE asp_matching_request IS '自动匹配排队意向；不占赛事正式报名名额';

COMMENT ON COLUMN asp_matching_request.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_matching_request.unit_id IS '同一报名项目';

COMMENT ON COLUMN asp_matching_request.account_id IS '排队本人';

COMMENT ON COLUMN asp_matching_request.room_id IS '补充现有房间；个人匹配可空';

COMMENT ON COLUMN asp_matching_request.preferences IS '本人选择的时间等偏好；必须按版本校验结构';

COMMENT ON COLUMN asp_matching_request.status IS '独立业务状态；合法值不等于业务已获批准：waiting offered accepted cancelled expired';

COMMENT ON COLUMN asp_matching_request.expires_at IS '意向截止；有时区业务时间';

COMMENT ON COLUMN asp_matching_request.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_matching_request.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_matching_request.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_matching_request.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_matching_request.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_matching_request.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_matching_offer (
    id bigint NOT NULL PRIMARY KEY,
    unit_id bigint NOT NULL,
    room_id bigint,
    status varchar(32) NOT NULL CHECK (status IN ('pending', 'accepted', 'declined', 'expired')),
    expires_at timestamptz NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0)
);

COMMENT ON TABLE asp_matching_offer IS '匹配确认邀请；每名成员本人接受，120秒确认席位与正式报名名额分开';

COMMENT ON COLUMN asp_matching_offer.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_matching_offer.unit_id IS '报名项目';

COMMENT ON COLUMN asp_matching_offer.room_id IS '现有或接受后创建的房间';

COMMENT ON COLUMN asp_matching_offer.status IS '独立业务状态；合法值不等于业务已获批准：pending accepted declined expired';

COMMENT ON COLUMN asp_matching_offer.expires_at IS '确认期限；有时区业务时间';

COMMENT ON COLUMN asp_matching_offer.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_matching_offer.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_matching_offer.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_matching_offer.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_matching_offer.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_matching_offer.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_matching_offer_member (
    id bigint NOT NULL PRIMARY KEY,
    offer_id bigint NOT NULL,
    account_id bigint NOT NULL,
    request_id bigint,
    status varchar(32) NOT NULL CHECK (status IN ('pending', 'accepted', 'declined')),
    answered_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0)
);

CREATE UNIQUE INDEX uq_asp_matching_offer_member_ce321fae43 ON asp_matching_offer_member (offer_id, account_id);

COMMENT ON TABLE asp_matching_offer_member IS '匹配邀请的一名接收者；全部接受后才加入房间';

COMMENT ON COLUMN asp_matching_offer_member.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_matching_offer_member.offer_id IS '邀请';

COMMENT ON COLUMN asp_matching_offer_member.account_id IS '接收人';

COMMENT ON COLUMN asp_matching_offer_member.request_id IS '来源排队';

COMMENT ON COLUMN asp_matching_offer_member.status IS '独立业务状态；合法值不等于业务已获批准：pending accepted declined';

COMMENT ON COLUMN asp_matching_offer_member.answered_at IS '本人回答时间；有时区业务时间';

COMMENT ON COLUMN asp_matching_offer_member.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_matching_offer_member.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_matching_offer_member.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_matching_offer_member.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_matching_offer_member.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_matching_offer_member.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_room_interaction (
    id bigint NOT NULL PRIMARY KEY,
    room_id bigint NOT NULL,
    account_id bigint NOT NULL,
    kind varchar(32) NOT NULL CHECK (kind IN ('welcome', 'encourage', 'ready', 'announcement')),
    text varchar(500) NOT NULL,
    request_key varchar(128) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0)
);

CREATE UNIQUE INDEX uq_asp_room_interaction_49044ce0f8 ON asp_room_interaction (account_id, request_key);

COMMENT ON TABLE asp_room_interaction IS '房间内可见欢迎与鼓励；不是社区或私聊平台';

COMMENT ON COLUMN asp_room_interaction.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_room_interaction.room_id IS '房间';

COMMENT ON COLUMN asp_room_interaction.account_id IS '发送人';

COMMENT ON COLUMN asp_room_interaction.kind IS '独立业务状态；合法值不等于业务已获批准：welcome encourage ready announcement';

COMMENT ON COLUMN asp_room_interaction.text IS '可见消息';

COMMENT ON COLUMN asp_room_interaction.request_key IS '防重键';

COMMENT ON COLUMN asp_room_interaction.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_room_interaction.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_room_interaction.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_room_interaction.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_room_interaction.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_room_interaction.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_governance_grant (
    id bigint NOT NULL PRIMARY KEY,
    sys_user_id bigint NOT NULL,
    organization_id bigint NOT NULL,
    permissions jsonb NOT NULL,
    status varchar(32) NOT NULL CHECK (status IN ('active', 'revoked')),
    valid_until timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0)
);

CREATE UNIQUE INDEX uq_asp_governance_grant_40a98a13e4 ON asp_governance_grant (sys_user_id, organization_id) WHERE status='active';

COMMENT ON TABLE asp_governance_grant IS '政府后台账号对指定主办方的管理范围；不能由模型或普通经办人自授';

COMMENT ON COLUMN asp_governance_grant.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_governance_grant.sys_user_id IS '政府若依用户编号';

COMMENT ON COLUMN asp_governance_grant.organization_id IS '指定主办方';

COMMENT ON COLUMN asp_governance_grant.permissions IS '准入、资格管理、汇总和投诉权限；必须按版本校验结构';

COMMENT ON COLUMN asp_governance_grant.status IS '独立业务状态；合法值不等于业务已获批准：active revoked';

COMMENT ON COLUMN asp_governance_grant.valid_until IS '授权截止；有时区业务时间';

COMMENT ON COLUMN asp_governance_grant.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_governance_grant.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_governance_grant.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_governance_grant.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_governance_grant.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_governance_grant.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_growth_policy (
    id bigint NOT NULL PRIMARY KEY,
    sport_id bigint NOT NULL,
    code varchar(64) NOT NULL,
    revision integer NOT NULL CHECK (revision >= 0),
    rules jsonb NOT NULL,
    status varchar(32) NOT NULL CHECK (status IN ('draft', 'active', 'superseded')),
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
    CHECK (revision > 0)
);

CREATE UNIQUE INDEX uq_asp_growth_policy_54670af7b3 ON asp_growth_policy (sport_id, code, revision);

COMMENT ON TABLE asp_growth_policy IS '版本化成长规则；段位不是官方竞技实力评级';

COMMENT ON COLUMN asp_growth_policy.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_growth_policy.sport_id IS '所属运动';

COMMENT ON COLUMN asp_growth_policy.code IS '规则编码';

COMMENT ON COLUMN asp_growth_policy.revision IS '规则版本';

COMMENT ON COLUMN asp_growth_policy.rules IS '段位门槛、奖励及称号阈值；必须按版本校验结构';

COMMENT ON COLUMN asp_growth_policy.status IS '独立业务状态；合法值不等于业务已获批准：draft active superseded';

COMMENT ON COLUMN asp_growth_policy.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_growth_policy.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_growth_policy.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_growth_policy.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_growth_policy.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_growth_policy.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_growth_profile (
    id bigint NOT NULL PRIMARY KEY,
    owner_type varchar(32) NOT NULL CHECK (owner_type IN ('person', 'team')),
    owner_id bigint NOT NULL,
    sport_id bigint NOT NULL,
    points integer NOT NULL CHECK (points >= 0),
    checkin_count integer NOT NULL CHECK (checkin_count >= 0),
    finish_count integer NOT NULL CHECK (finish_count >= 0),
    policy_version varchar(64) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0)
);

CREATE UNIQUE INDEX uq_asp_growth_profile_09683c1fb1 ON asp_growth_profile (owner_type, owner_id, sport_id);

COMMENT ON TABLE asp_growth_profile IS '由可追溯成长事实汇总的个人或队伍运动成长；可重建，不是原始事实';

COMMENT ON COLUMN asp_growth_profile.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_growth_profile.owner_type IS '独立业务状态；合法值不等于业务已获批准：person team';

COMMENT ON COLUMN asp_growth_profile.owner_id IS '本人档案或长期队伍编号';

COMMENT ON COLUMN asp_growth_profile.sport_id IS '运动';

COMMENT ON COLUMN asp_growth_profile.points IS '当前有效成长分';

COMMENT ON COLUMN asp_growth_profile.checkin_count IS '真实报到赛事数';

COMMENT ON COLUMN asp_growth_profile.finish_count IS '有效完赛赛事数';

COMMENT ON COLUMN asp_growth_profile.policy_version IS '汇总使用规则版本';

COMMENT ON COLUMN asp_growth_profile.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_growth_profile.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_growth_profile.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_growth_profile.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_growth_profile.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_growth_profile.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_title_equipment (
    id bigint NOT NULL PRIMARY KEY,
    owner_type varchar(32) NOT NULL CHECK (owner_type IN ('person', 'team')),
    owner_id bigint NOT NULL,
    sport_id bigint NOT NULL,
    title_code varchar(64) NOT NULL,
    honor_id bigint,
    frame_style varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0)
);

CREATE UNIQUE INDEX uq_asp_title_equipment_32b7cc75d3 ON asp_title_equipment (owner_type, owner_id, sport_id);

COMMENT ON TABLE asp_title_equipment IS '本人或队长选择当前佩戴的成长称号；授予来源由荣誉事实保留';

COMMENT ON COLUMN asp_title_equipment.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_title_equipment.owner_type IS '独立业务状态；合法值不等于业务已获批准：person team';

COMMENT ON COLUMN asp_title_equipment.owner_id IS '本人或队伍编号';

COMMENT ON COLUMN asp_title_equipment.sport_id IS '运动';

COMMENT ON COLUMN asp_title_equipment.title_code IS '规则目录中的称号编码';

COMMENT ON COLUMN asp_title_equipment.honor_id IS '获授荣誉事实；欢迎样式可空';

COMMENT ON COLUMN asp_title_equipment.frame_style IS '允许的头像边框样式';

COMMENT ON COLUMN asp_title_equipment.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_title_equipment.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_title_equipment.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_title_equipment.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_title_equipment.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_title_equipment.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_capability_version (
    id bigint NOT NULL PRIMARY KEY,
    code varchar(160) NOT NULL,
    revision integer NOT NULL CHECK (revision >= 0),
    definition jsonb NOT NULL,
    source_hash varchar(64) NOT NULL,
    status varchar(32) NOT NULL CHECK (status IN ('draft', 'tested', 'published', 'retired')),
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
    CHECK (revision > 0)
);

CREATE UNIQUE INDEX uq_asp_capability_version_283dedea1b ON asp_capability_version (code, revision);

COMMENT ON TABLE asp_capability_version IS '经过实现与测试的能力版本；描述不是授权';

COMMENT ON COLUMN asp_capability_version.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_capability_version.code IS '能力编码';

COMMENT ON COLUMN asp_capability_version.revision IS '版本';

COMMENT ON COLUMN asp_capability_version.definition IS '参数、结果、读写范围、确认和权限；必须按版本校验结构';

COMMENT ON COLUMN asp_capability_version.source_hash IS '定义SHA256';

COMMENT ON COLUMN asp_capability_version.status IS '独立业务状态；合法值不等于业务已获批准：draft tested published retired';

COMMENT ON COLUMN asp_capability_version.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_capability_version.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_capability_version.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_capability_version.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_capability_version.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_capability_version.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_capability_activation (
    id bigint NOT NULL PRIMARY KEY,
    code varchar(160) NOT NULL,
    capability_version_id bigint NOT NULL,
    channel varchar(32) NOT NULL CHECK (channel IN ('ui', 'agent', 'system')),
    enabled boolean NOT NULL DEFAULT false,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0)
);

CREATE UNIQUE INDEX uq_asp_capability_activation_43a359f141 ON asp_capability_activation (code, channel);

COMMENT ON TABLE asp_capability_activation IS '能力在人工、Agent和系统渠道的明确开放指针';

COMMENT ON COLUMN asp_capability_activation.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_capability_activation.code IS '能力编码';

COMMENT ON COLUMN asp_capability_activation.capability_version_id IS '已发布版本';

COMMENT ON COLUMN asp_capability_activation.channel IS '独立业务状态；合法值不等于业务已获批准：ui agent system';

COMMENT ON COLUMN asp_capability_activation.enabled IS '允许新调用';

COMMENT ON COLUMN asp_capability_activation.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_capability_activation.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_capability_activation.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_capability_activation.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_capability_activation.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_capability_activation.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_action_execution (
    id bigint NOT NULL PRIMARY KEY,
    action_code varchar(160) NOT NULL,
    actor_type varchar(32) NOT NULL,
    actor_id bigint NOT NULL,
    tenant_scope varchar(20),
    channel varchar(16) NOT NULL,
    request_key varchar(128) NOT NULL,
    payload_hash varchar(64) NOT NULL,
    status varchar(32) NOT NULL CHECK (status IN ('succeeded', 'failed', 'denied')),
    result_reference jsonb NOT NULL,
    error_code varchar(64),
    run_id bigint,
    occurred_at timestamptz NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0)
);

CREATE UNIQUE INDEX uq_asp_action_execution_7406d253d8 ON asp_action_execution (actor_type, actor_id, action_code, request_key) WHERE status='succeeded';

COMMENT ON TABLE asp_action_execution IS '统一动作终态回执；成功与业务同事务，失败独立留痕，不存私有完整响应';

COMMENT ON COLUMN asp_action_execution.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_action_execution.action_code IS '动作编码';

COMMENT ON COLUMN asp_action_execution.actor_type IS '真实主体类型';

COMMENT ON COLUMN asp_action_execution.actor_id IS '主体编号';

COMMENT ON COLUMN asp_action_execution.tenant_scope IS '服务器确定的组织范围';

COMMENT ON COLUMN asp_action_execution.channel IS '调用渠道';

COMMENT ON COLUMN asp_action_execution.request_key IS '防重请求键';

COMMENT ON COLUMN asp_action_execution.payload_hash IS '输入摘要';

COMMENT ON COLUMN asp_action_execution.status IS '独立业务状态；合法值不等于业务已获批准：succeeded failed denied';

COMMENT ON COLUMN asp_action_execution.result_reference IS '结果对象和允许的状态摘要；必须按版本校验结构';

COMMENT ON COLUMN asp_action_execution.error_code IS '失败代码';

COMMENT ON COLUMN asp_action_execution.run_id IS '关联智能体运行';

COMMENT ON COLUMN asp_action_execution.occurred_at IS '执行结束；有时区业务时间';

COMMENT ON COLUMN asp_action_execution.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_action_execution.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_action_execution.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_action_execution.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_action_execution.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_action_execution.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_agent (
    id bigint NOT NULL PRIMARY KEY,
    code varchar(64) NOT NULL,
    name varchar(100) NOT NULL,
    layer varchar(32) NOT NULL CHECK (layer IN ('global', 'domain', 'function')),
    domain_scope varchar(32),
    status varchar(32) NOT NULL CHECK (status IN ('active', 'disabled')),
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0)
);

CREATE UNIQUE INDEX uq_asp_agent_db65b3d20b ON asp_agent (code);

COMMENT ON TABLE asp_agent IS '智能体定义，按平台、业务域和职能分层；没有原始SQL能力';

COMMENT ON COLUMN asp_agent.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_agent.code IS '稳定编码';

COMMENT ON COLUMN asp_agent.name IS '名称';

COMMENT ON COLUMN asp_agent.layer IS '独立业务状态；合法值不等于业务已获批准：global domain function';

COMMENT ON COLUMN asp_agent.domain_scope IS '体育业务域范围';

COMMENT ON COLUMN asp_agent.status IS '独立业务状态；合法值不等于业务已获批准：active disabled';

COMMENT ON COLUMN asp_agent.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_agent.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_agent.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_agent.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_agent.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_agent.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_agent_version (
    id bigint NOT NULL PRIMARY KEY,
    agent_id bigint NOT NULL,
    revision integer NOT NULL CHECK (revision >= 0),
    model_name varchar(80) NOT NULL,
    instruction text NOT NULL,
    budget jsonb NOT NULL,
    status varchar(32) NOT NULL CHECK (status IN ('draft', 'active', 'retired')),
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
    CHECK (revision > 0)
);

CREATE UNIQUE INDEX uq_asp_agent_version_766dffb6fe ON asp_agent_version (agent_id, revision);

COMMENT ON TABLE asp_agent_version IS '智能体提示词与模型的可追溯版本；只记录可见业务指引';

COMMENT ON COLUMN asp_agent_version.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_agent_version.agent_id IS '智能体';

COMMENT ON COLUMN asp_agent_version.revision IS '版本';

COMMENT ON COLUMN asp_agent_version.model_name IS '固定接口模型名';

COMMENT ON COLUMN asp_agent_version.instruction IS '可信平台提示词，不能由上传材料改写';

COMMENT ON COLUMN asp_agent_version.budget IS '深度、调用和时间预算；必须按版本校验结构';

COMMENT ON COLUMN asp_agent_version.status IS '独立业务状态；合法值不等于业务已获批准：draft active retired';

COMMENT ON COLUMN asp_agent_version.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_agent_version.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_agent_version.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_agent_version.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_agent_version.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_agent_version.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_agent_grant (
    id bigint NOT NULL PRIMARY KEY,
    agent_id bigint NOT NULL,
    capability_code varchar(160) NOT NULL,
    scope jsonb NOT NULL,
    status varchar(32) NOT NULL CHECK (status IN ('active', 'revoked')),
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0)
);

CREATE UNIQUE INDEX uq_asp_agent_grant_44fe84c055 ON asp_agent_grant (agent_id, capability_code) WHERE status='active';

COMMENT ON TABLE asp_agent_grant IS '智能体能力及委派上限；与委托人实时权限取交集';

COMMENT ON COLUMN asp_agent_grant.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_agent_grant.agent_id IS '智能体';

COMMENT ON COLUMN asp_agent_grant.capability_code IS '允许能力或delegate目标';

COMMENT ON COLUMN asp_agent_grant.scope IS '能力、组织和对象上限；必须按版本校验结构';

COMMENT ON COLUMN asp_agent_grant.status IS '独立业务状态；合法值不等于业务已获批准：active revoked';

COMMENT ON COLUMN asp_agent_grant.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_agent_grant.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_agent_grant.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_agent_grant.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_agent_grant.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_agent_grant.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_agent_run (
    id bigint NOT NULL PRIMARY KEY,
    agent_version_id bigint NOT NULL,
    actor_type varchar(32) NOT NULL,
    actor_id bigint NOT NULL,
    parent_run_id bigint,
    root_run_id bigint,
    scope jsonb NOT NULL,
    goal varchar(2000) NOT NULL,
    status varchar(32) NOT NULL CHECK (status IN ('running', 'waiting_input', 'waiting_confirmation', 'completed', 'failed', 'stopped')),
    depth integer NOT NULL CHECK (depth >= 0),
    tool_count integer NOT NULL CHECK (tool_count >= 0),
    tokens_used integer NOT NULL CHECK (tokens_used >= 0),
    token_hash varchar(64) NOT NULL,
    expires_at timestamptz NOT NULL,
    started_at timestamptz NOT NULL,
    ended_at timestamptz,
    stop_reason varchar(64),
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0)
);

COMMENT ON TABLE asp_agent_run IS '服务端签发的运行身份与进度；不保存密钥或隐藏思考';

COMMENT ON COLUMN asp_agent_run.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_agent_run.agent_version_id IS '锁定版本';

COMMENT ON COLUMN asp_agent_run.actor_type IS '委托人主体类型';

COMMENT ON COLUMN asp_agent_run.actor_id IS '委托人编号';

COMMENT ON COLUMN asp_agent_run.parent_run_id IS '父运行';

COMMENT ON COLUMN asp_agent_run.root_run_id IS '根运行';

COMMENT ON COLUMN asp_agent_run.scope IS '服务器确定的对象和权限范围；必须按版本校验结构';

COMMENT ON COLUMN asp_agent_run.goal IS '用户可见目标';

COMMENT ON COLUMN asp_agent_run.status IS '独立业务状态；合法值不等于业务已获批准：running waiting_input waiting_confirmation completed failed stopped';

COMMENT ON COLUMN asp_agent_run.depth IS '绝对委派深度';

COMMENT ON COLUMN asp_agent_run.tool_count IS '已调用工具数';

COMMENT ON COLUMN asp_agent_run.tokens_used IS '供应商报告用量';

COMMENT ON COLUMN asp_agent_run.token_hash IS '运行令牌摘要，原令牌不入库';

COMMENT ON COLUMN asp_agent_run.expires_at IS '运行令牌截止；有时区业务时间';

COMMENT ON COLUMN asp_agent_run.started_at IS '开始；有时区业务时间';

COMMENT ON COLUMN asp_agent_run.ended_at IS '结束；有时区业务时间';

COMMENT ON COLUMN asp_agent_run.stop_reason IS '停止原因';

COMMENT ON COLUMN asp_agent_run.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_agent_run.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_agent_run.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_agent_run.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_agent_run.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_agent_run.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_agent_step (
    id bigint NOT NULL PRIMARY KEY,
    run_id bigint NOT NULL,
    sequence integer NOT NULL CHECK (sequence >= 0),
    kind varchar(32) NOT NULL CHECK (kind IN ('model', 'tool', 'delegate', 'confirmation', 'control')),
    name varchar(160) NOT NULL,
    status varchar(32) NOT NULL CHECK (status IN ('started', 'succeeded', 'failed', 'denied')),
    summary jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0)
);

CREATE UNIQUE INDEX uq_asp_agent_step_410c5b62e9 ON asp_agent_step (run_id, sequence);

COMMENT ON TABLE asp_agent_step IS '可见模型、工具和委派步骤摘要，不包含材料正文和隐藏思考';

COMMENT ON COLUMN asp_agent_step.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_agent_step.run_id IS '运行';

COMMENT ON COLUMN asp_agent_step.sequence IS '顺序';

COMMENT ON COLUMN asp_agent_step.kind IS '独立业务状态；合法值不等于业务已获批准：model tool delegate confirmation control';

COMMENT ON COLUMN asp_agent_step.name IS '模型或能力名称';

COMMENT ON COLUMN asp_agent_step.status IS '独立业务状态；合法值不等于业务已获批准：started succeeded failed denied';

COMMENT ON COLUMN asp_agent_step.summary IS '可见状态、来源引用与用量；必须按版本校验结构';

COMMENT ON COLUMN asp_agent_step.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_agent_step.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_agent_step.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_agent_step.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_agent_step.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_agent_step.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_agent_message (
    id bigint NOT NULL PRIMARY KEY,
    run_id bigint NOT NULL,
    role varchar(32) NOT NULL CHECK (role IN ('user', 'assistant')),
    content text NOT NULL,
    blocks jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0)
);

COMMENT ON TABLE asp_agent_message IS '本人可恢复的可见对话；用途受控，不向其他人共享';

COMMENT ON COLUMN asp_agent_message.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_agent_message.run_id IS '运行';

COMMENT ON COLUMN asp_agent_message.role IS '独立业务状态；合法值不等于业务已获批准：user assistant';

COMMENT ON COLUMN asp_agent_message.content IS '用户可见文本；不存密钥或隐藏思考';

COMMENT ON COLUMN asp_agent_message.blocks IS '经过校验的表单、确认、回执和跳转块；必须按版本校验结构';

COMMENT ON COLUMN asp_agent_message.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_agent_message.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_agent_message.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_agent_message.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_agent_message.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_agent_message.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_action_confirmation (
    id bigint NOT NULL PRIMARY KEY,
    run_id bigint,
    actor_type varchar(32) NOT NULL,
    actor_id bigint NOT NULL,
    action_code varchar(160) NOT NULL,
    payload_hash varchar(64) NOT NULL,
    object_versions jsonb NOT NULL,
    status varchar(32) NOT NULL CHECK (status IN ('pending', 'confirmed', 'consumed', 'expired')),
    expires_at timestamptz NOT NULL,
    confirmed_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0)
);

COMMENT ON TABLE asp_action_confirmation IS '登录本人对特定能力、输入摘要和对象版本的一次确认';

COMMENT ON COLUMN asp_action_confirmation.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_action_confirmation.run_id IS '关联运行';

COMMENT ON COLUMN asp_action_confirmation.actor_type IS '确认主体类型';

COMMENT ON COLUMN asp_action_confirmation.actor_id IS '确认人编号';

COMMENT ON COLUMN asp_action_confirmation.action_code IS '动作';

COMMENT ON COLUMN asp_action_confirmation.payload_hash IS '确认内容摘要';

COMMENT ON COLUMN asp_action_confirmation.object_versions IS '对象及预期版本；必须按版本校验结构';

COMMENT ON COLUMN asp_action_confirmation.status IS '独立业务状态；合法值不等于业务已获批准：pending confirmed consumed expired';

COMMENT ON COLUMN asp_action_confirmation.expires_at IS '有效期限；有时区业务时间';

COMMENT ON COLUMN asp_action_confirmation.confirmed_at IS '本人点击确认；有时区业务时间';

COMMENT ON COLUMN asp_action_confirmation.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_action_confirmation.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_action_confirmation.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_action_confirmation.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_action_confirmation.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_action_confirmation.version IS '乐观并发版本；不替代业务规则/名单版本';

CREATE TABLE asp_complaint_message (
    id bigint NOT NULL PRIMARY KEY,
    complaint_id bigint NOT NULL,
    actor_type varchar(32) NOT NULL,
    actor_id bigint NOT NULL,
    action varchar(32) NOT NULL,
    message varchar(2000) NOT NULL,
    occurred_at timestamptz NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0)
);

COMMENT ON TABLE asp_complaint_message IS '投诉回复、处理与重新打开的追加记录；只向获授权当事方展示';

COMMENT ON COLUMN asp_complaint_message.id IS '应用分配的稳定雪花 ID；不能随变更重建';

COMMENT ON COLUMN asp_complaint_message.complaint_id IS '投诉';

COMMENT ON COLUMN asp_complaint_message.actor_type IS '本人、主办方或政府角色';

COMMENT ON COLUMN asp_complaint_message.actor_id IS '处理主体';

COMMENT ON COLUMN asp_complaint_message.action IS '回复、转交、关闭或重开';

COMMENT ON COLUMN asp_complaint_message.message IS '可见回复与处理依据';

COMMENT ON COLUMN asp_complaint_message.occurred_at IS '发生时间；有时区业务时间';

COMMENT ON COLUMN asp_complaint_message.create_dept IS '操作创建部门；上游审计字段';

COMMENT ON COLUMN asp_complaint_message.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';

COMMENT ON COLUMN asp_complaint_message.create_time IS '记录创建时间；不同于实际发生时间';

COMMENT ON COLUMN asp_complaint_message.update_by IS '最近更新操作主体';

COMMENT ON COLUMN asp_complaint_message.update_time IS '最近更新记录时间；由服务维护';

COMMENT ON COLUMN asp_complaint_message.version IS '乐观并发版本；不替代业务规则/名单版本';

ALTER TABLE asp_competition_type ADD CONSTRAINT fk_asp_competition_type_171c7d41bc FOREIGN KEY (sport_id) REFERENCES asp_sport(id);

ALTER TABLE asp_profile_display ADD CONSTRAINT fk_asp_profile_display_4004d8b172 FOREIGN KEY (account_id) REFERENCES asp_account(id);

ALTER TABLE asp_team_room ADD CONSTRAINT fk_asp_team_room_9bb197d38e FOREIGN KEY (unit_id) REFERENCES asp_competition_unit(id);

ALTER TABLE asp_team_room ADD CONSTRAINT fk_asp_team_room_78abb6d8fa FOREIGN KEY (competition_type_id) REFERENCES asp_competition_type(id);

ALTER TABLE asp_team_room ADD CONSTRAINT fk_asp_team_room_41cce5f02e FOREIGN KEY (host_account_id) REFERENCES asp_account(id);

ALTER TABLE asp_team_room ADD CONSTRAINT fk_asp_team_room_97d2595381 FOREIGN KEY (team_id) REFERENCES asp_team(id);

ALTER TABLE asp_team_room_member ADD CONSTRAINT fk_asp_team_room_member_67b5f29a62 FOREIGN KEY (room_id) REFERENCES asp_team_room(id);

ALTER TABLE asp_team_room_member ADD CONSTRAINT fk_asp_team_room_member_c364cb6efa FOREIGN KEY (unit_id) REFERENCES asp_competition_unit(id);

ALTER TABLE asp_team_room_member ADD CONSTRAINT fk_asp_team_room_member_5e409a13b7 FOREIGN KEY (account_id) REFERENCES asp_account(id);

ALTER TABLE asp_team_room_member ADD CONSTRAINT fk_asp_team_room_member_4e4cf6dc92 FOREIGN KEY (person_id) REFERENCES asp_person(id);

ALTER TABLE asp_recruitment ADD CONSTRAINT fk_asp_recruitment_ead6f77273 FOREIGN KEY (room_id) REFERENCES asp_team_room(id);

ALTER TABLE asp_recruitment ADD CONSTRAINT fk_asp_recruitment_753c464296 FOREIGN KEY (creator_account_id) REFERENCES asp_account(id);

ALTER TABLE asp_matching_request ADD CONSTRAINT fk_asp_matching_request_600dd02184 FOREIGN KEY (unit_id) REFERENCES asp_competition_unit(id);

ALTER TABLE asp_matching_request ADD CONSTRAINT fk_asp_matching_request_00493307af FOREIGN KEY (account_id) REFERENCES asp_account(id);

ALTER TABLE asp_matching_request ADD CONSTRAINT fk_asp_matching_request_9742c3d66f FOREIGN KEY (room_id) REFERENCES asp_team_room(id);

ALTER TABLE asp_matching_offer ADD CONSTRAINT fk_asp_matching_offer_77aae21b6b FOREIGN KEY (unit_id) REFERENCES asp_competition_unit(id);

ALTER TABLE asp_matching_offer ADD CONSTRAINT fk_asp_matching_offer_7c52f06e1c FOREIGN KEY (room_id) REFERENCES asp_team_room(id);

ALTER TABLE asp_matching_offer_member ADD CONSTRAINT fk_asp_matching_offer_member_db8fdcae2e FOREIGN KEY (offer_id) REFERENCES asp_matching_offer(id);

ALTER TABLE asp_matching_offer_member ADD CONSTRAINT fk_asp_matching_offer_member_302eb57a1b FOREIGN KEY (account_id) REFERENCES asp_account(id);

ALTER TABLE asp_matching_offer_member ADD CONSTRAINT fk_asp_matching_offer_member_f86541945e FOREIGN KEY (request_id) REFERENCES asp_matching_request(id);

ALTER TABLE asp_room_interaction ADD CONSTRAINT fk_asp_room_interaction_5bd69eddfc FOREIGN KEY (room_id) REFERENCES asp_team_room(id);

ALTER TABLE asp_room_interaction ADD CONSTRAINT fk_asp_room_interaction_a43601fbcb FOREIGN KEY (account_id) REFERENCES asp_account(id);

ALTER TABLE asp_governance_grant ADD CONSTRAINT fk_asp_governance_grant_9046659b25 FOREIGN KEY (organization_id) REFERENCES asp_organization(id);

ALTER TABLE asp_growth_policy ADD CONSTRAINT fk_asp_growth_policy_72dce142e4 FOREIGN KEY (sport_id) REFERENCES asp_sport(id);

ALTER TABLE asp_growth_profile ADD CONSTRAINT fk_asp_growth_profile_5431d8e0c8 FOREIGN KEY (sport_id) REFERENCES asp_sport(id);

ALTER TABLE asp_title_equipment ADD CONSTRAINT fk_asp_title_equipment_75184f7b12 FOREIGN KEY (sport_id) REFERENCES asp_sport(id);

ALTER TABLE asp_title_equipment ADD CONSTRAINT fk_asp_title_equipment_ba878710fb FOREIGN KEY (honor_id) REFERENCES asp_honor(id);

ALTER TABLE asp_capability_activation ADD CONSTRAINT fk_asp_capability_activation_907a689487 FOREIGN KEY (capability_version_id) REFERENCES asp_capability_version(id);

ALTER TABLE asp_agent_version ADD CONSTRAINT fk_asp_agent_version_bc45a3950a FOREIGN KEY (agent_id) REFERENCES asp_agent(id);

ALTER TABLE asp_agent_grant ADD CONSTRAINT fk_asp_agent_grant_d058814e58 FOREIGN KEY (agent_id) REFERENCES asp_agent(id);

ALTER TABLE asp_agent_run ADD CONSTRAINT fk_asp_agent_run_c34bdeca1e FOREIGN KEY (agent_version_id) REFERENCES asp_agent_version(id);

ALTER TABLE asp_agent_step ADD CONSTRAINT fk_asp_agent_step_800194d51b FOREIGN KEY (run_id) REFERENCES asp_agent_run(id);

ALTER TABLE asp_agent_message ADD CONSTRAINT fk_asp_agent_message_3a55415c04 FOREIGN KEY (run_id) REFERENCES asp_agent_run(id);

ALTER TABLE asp_action_confirmation ADD CONSTRAINT fk_asp_action_confirmation_c3695ffd29 FOREIGN KEY (run_id) REFERENCES asp_agent_run(id);

ALTER TABLE asp_complaint_message ADD CONSTRAINT fk_asp_complaint_message_df2b4cf5af FOREIGN KEY (complaint_id) REFERENCES asp_complaint(id);

ALTER TABLE asp_competition_unit ADD COLUMN competition_type_id bigint REFERENCES asp_competition_type(id);

ALTER TABLE asp_registration ADD COLUMN manager_account_id bigint REFERENCES asp_account(id);

UPDATE asp_registration SET manager_account_id=submitter_account_id;

ALTER TABLE asp_match ADD COLUMN court_name varchar(80);

ALTER TABLE asp_event ADD COLUMN closure_status varchar(32) NOT NULL DEFAULT 'open' CHECK (closure_status IN ('open','wrap_up','closed'));

ALTER TABLE asp_growth_record ADD COLUMN sport_id bigint REFERENCES asp_sport(id), ADD COLUMN event_id bigint REFERENCES asp_event(id), ADD COLUMN milestone varchar(64), ADD COLUMN points_delta integer NOT NULL DEFAULT 0, ADD COLUMN source_key varchar(160);

CREATE UNIQUE INDEX uq_growth_source_key ON asp_growth_record(source_key) WHERE source_key IS NOT NULL;

ALTER TABLE asp_honor ADD COLUMN sport_id bigint REFERENCES asp_sport(id), ADD COLUMN title_code varchar(64);

ALTER TABLE asp_ai_task ADD COLUMN provider_consent boolean NOT NULL DEFAULT false, ADD COLUMN provider_name varchar(64) NOT NULL DEFAULT 'legacy-bailian', ADD COLUMN consent_version varchar(64) NOT NULL DEFAULT 'legacy';

DO $consent$ DECLARE item record; BEGIN FOR item IN SELECT conname FROM pg_constraint WHERE conrelid='asp_ai_task'::regclass AND contype='c' AND pg_get_constraintdef(oid) LIKE '%bailian_consent%' LOOP EXECUTE format('ALTER TABLE asp_ai_task DROP CONSTRAINT %I',item.conname); END LOOP; END $consent$;

ALTER TABLE asp_ai_task ADD CONSTRAINT ck_ai_actual_provider_consent CHECK (bailian_consent=true OR (provider_consent=true AND provider_name='deepseek'));

INSERT INTO asp_sport(id,code,name,rule_family,capability_status,status) VALUES (930000000000000001,'basketball','篮球','对抗','catalog','active'),(930000000000000002,'football','足球','对抗','catalog','active'),(930000000000000003,'table_tennis','乒乓球','对抗','catalog','active') ON CONFLICT (code) DO NOTHING;

INSERT INTO asp_competition_type(id,sport_id,code,name,entry_type,min_members,max_members,capability_status,status) SELECT 930000000000000011,id,'singles','羽毛球单打','individual',1,1,'manual','active' FROM asp_sport WHERE code='badminton' ON CONFLICT (sport_id,code) DO NOTHING;

INSERT INTO asp_competition_type(id,sport_id,code,name,entry_type,min_members,max_members,capability_status,status) SELECT 930000000000000012,id,'doubles','羽毛球双打','pair',2,2,'manual','active' FROM asp_sport WHERE code='badminton' ON CONFLICT (sport_id,code) DO NOTHING;

UPDATE asp_competition_unit u SET competition_type_id=t.id FROM asp_competition_type t WHERE t.sport_id=u.sport_id AND t.entry_type=u.entry_type AND t.min_members=u.min_members AND t.max_members=u.max_members;

CREATE INDEX ix_room_unit_status ON asp_team_room(unit_id,status);

CREATE INDEX ix_matching_unit_status ON asp_matching_request(unit_id,status,create_time);

CREATE INDEX ix_growth_owner ON asp_growth_record(person_id,team_id,sport_id,event_id);

CREATE INDEX ix_run_owner ON asp_agent_run(actor_type,actor_id,create_time);

CREATE INDEX ix_complaint_object ON asp_complaint(object_type,object_id,status);

GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO aisports_app;
