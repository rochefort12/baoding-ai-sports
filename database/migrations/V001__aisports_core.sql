-- GENERATED from database/model/catalog.py. Do not hand edit.
-- V001: initial development model; apply exactly once to a fresh database.
-- PostgreSQL 17; bigint IDs supplied by application; NO cascading deletes.
BEGIN;
SET LOCAL TIME ZONE 'Asia/Shanghai';

-- D02: 平台登录账号；现实运动者与后台员工账号独立
CREATE TABLE asp_account (
    id bigint NOT NULL,
    display_name varchar(100) NOT NULL,
    backend_user_id bigint,
    status varchar(32) NOT NULL,
    closed_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (status IN ('active', 'restricted', 'recovery', 'closing', 'closed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_account IS '平台登录账号；现实运动者与后台员工账号独立；来源：母版 D02；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_account.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_account.display_name IS '登录账号展示名';
COMMENT ON COLUMN asp_account.backend_user_id IS '可选后台 sys_user 关联；应用核验租户和登录归属';
COMMENT ON COLUMN asp_account.status IS '独立业务状态；合法值不等于业务已获批准：active restricted recovery closing closed';
COMMENT ON COLUMN asp_account.closed_at IS '账号服务停止时间；有时区业务时间';
COMMENT ON COLUMN asp_account.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_account.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_account.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_account.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_account.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_account.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D02: 账号渠道绑定和解绑历史；手机号回收不直接转移历史档案
CREATE TABLE asp_login_identity (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    channel varchar(100) NOT NULL,
    subject_hash varchar(128) NOT NULL,
    subject_cipher varchar(1000),
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    verification_source varchar(100) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (valid_until IS NULL OR valid_until > valid_from),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_login_identity IS '账号渠道绑定和解绑历史；手机号回收不直接转移历史档案；来源：母版 D02；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_login_identity.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_login_identity.account_id IS '绑定平台账号';
CREATE INDEX ix_asp_login_identity_77f45262fd ON asp_login_identity (account_id);
COMMENT ON COLUMN asp_login_identity.channel IS 'phone/wechat/其他登录渠道';
COMMENT ON COLUMN asp_login_identity.subject_hash IS '渠道标识带密钥摘要；不得明文公开';
COMMENT ON COLUMN asp_login_identity.subject_cipher IS '需要恢复时的加密标识';
COMMENT ON COLUMN asp_login_identity.valid_from IS '绑定生效；有时区业务时间';
COMMENT ON COLUMN asp_login_identity.valid_until IS '绑定结束；有时区业务时间';
COMMENT ON COLUMN asp_login_identity.verification_source IS '核验依据及方式';
COMMENT ON COLUMN asp_login_identity.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_login_identity.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_login_identity.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_login_identity.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_login_identity.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_login_identity.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_login_identity_744f4a3e8e ON asp_login_identity (channel, subject_hash) WHERE valid_until IS NULL;

-- D02: 稳定现实参赛人；个人资料更正不改写报名快照
CREATE TABLE asp_person (
    id bigint NOT NULL,
    display_name varchar(100) NOT NULL,
    birth_date date,
    gender varchar(32) NOT NULL,
    identity_hash varchar(128),
    identity_cipher varchar(1000),
    verification_status varchar(32) NOT NULL,
    status varchar(32) NOT NULL,
    merged_into_id bigint,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (merged_into_id IS NULL OR merged_into_id <> id),
    CHECK (gender IN ('unknown', 'male', 'female', 'other')),
    CHECK (verification_status IN ('unverified', 'pending', 'verified', 'disputed')),
    CHECK (status IN ('active', 'restricted', 'merged', 'archived')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_person IS '稳定现实参赛人；个人资料更正不改写报名快照；来源：母版 D02；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_person.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_person.display_name IS '受控姓名或活动展示名';
COMMENT ON COLUMN asp_person.birth_date IS '出生日期；年龄按规程基准日判断';
COMMENT ON COLUMN asp_person.gender IS '参赛人提供的分组相关信息；适用范围由规程确认：unknown male female other';
COMMENT ON COLUMN asp_person.identity_hash IS '用于重复候选识别的带密钥摘要；禁止当公开编号';
COMMENT ON COLUMN asp_person.identity_cipher IS '最小必要身份依据加密值';
COMMENT ON COLUMN asp_person.verification_status IS '独立业务状态；合法值不等于业务已获批准：unverified pending verified disputed';
COMMENT ON COLUMN asp_person.status IS '独立业务状态；合法值不等于业务已获批准：active restricted merged archived';
COMMENT ON COLUMN asp_person.merged_into_id IS '经批准合并目标；必须先核对业务影响';
CREATE INDEX ix_asp_person_ef99cce6fe ON asp_person (merged_into_id);
COMMENT ON COLUMN asp_person.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_person.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_person.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_person.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_person.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_person.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_person_bc84cd008f ON asp_person (identity_hash) WHERE identity_hash IS NOT NULL AND status = 'active';

-- D02: 账号与现实参赛人的有效绑定；代办关系另存
CREATE TABLE asp_account_person (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    person_id bigint NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    basis varchar(500) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (valid_until IS NULL OR valid_until > valid_from),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_account_person IS '账号与现实参赛人的有效绑定；代办关系另存；来源：母版 D02；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_account_person.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_account_person.account_id IS '平台账号';
CREATE INDEX ix_asp_account_person_1c703bbfe2 ON asp_account_person (account_id);
COMMENT ON COLUMN asp_account_person.person_id IS '本人现实身份';
CREATE INDEX ix_asp_account_person_0ff84bc509 ON asp_account_person (person_id);
COMMENT ON COLUMN asp_account_person.valid_from IS '生效时间；有时区业务时间';
COMMENT ON COLUMN asp_account_person.valid_until IS '终止时间；有时区业务时间';
COMMENT ON COLUMN asp_account_person.basis IS '核验来源及变更理由';
COMMENT ON COLUMN asp_account_person.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_account_person.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_account_person.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_account_person.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_account_person.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_account_person.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_account_person_eb8a270cbf ON asp_account_person (account_id) WHERE valid_until IS NULL;
CREATE UNIQUE INDEX uq_asp_account_person_fcee05418f ON asp_account_person (person_id) WHERE valid_until IS NULL;

-- D02: 监护关系与行为范围；独立账号不能替代必要同意
CREATE TABLE asp_guardianship (
    id bigint NOT NULL,
    guardian_person_id bigint NOT NULL,
    child_person_id bigint NOT NULL,
    action_scope jsonb NOT NULL,
    basis varchar(500) NOT NULL,
    status varchar(32) NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (guardian_person_id <> child_person_id),
    CHECK (valid_until IS NULL OR valid_until > valid_from),
    CHECK (status IN ('pending', 'confirmed', 'revoked', 'disputed', 'expired')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_guardianship IS '监护关系与行为范围；独立账号不能替代必要同意；来源：母版 D02；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_guardianship.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_guardianship.guardian_person_id IS '监护人';
CREATE INDEX ix_asp_guardianship_de9e84fc13 ON asp_guardianship (guardian_person_id);
COMMENT ON COLUMN asp_guardianship.child_person_id IS '被监护人';
CREATE INDEX ix_asp_guardianship_8432f6051d ON asp_guardianship (child_person_id);
COMMENT ON COLUMN asp_guardianship.action_scope IS '允许行为清单及版本；必须按版本校验结构';
COMMENT ON COLUMN asp_guardianship.basis IS '监护关系依据';
COMMENT ON COLUMN asp_guardianship.status IS '独立业务状态；合法值不等于业务已获批准：pending confirmed revoked disputed expired';
COMMENT ON COLUMN asp_guardianship.valid_from IS '生效；有时区业务时间';
COMMENT ON COLUMN asp_guardianship.valid_until IS '有效期限；有时区业务时间';
COMMENT ON COLUMN asp_guardianship.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_guardianship.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_guardianship.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_guardianship.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_guardianship.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_guardianship.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D02: 代办授权；限定参赛人、赛事或队伍及可办行为
CREATE TABLE asp_delegation (
    id bigint NOT NULL,
    person_id bigint NOT NULL,
    operator_account_id bigint NOT NULL,
    scope_type varchar(100) NOT NULL,
    scope_id bigint,
    actions jsonb NOT NULL,
    status varchar(32) NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (valid_until IS NULL OR valid_until > valid_from),
    CHECK (status IN ('pending', 'active', 'revoked', 'expired')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_delegation IS '代办授权；限定参赛人、赛事或队伍及可办行为；来源：母版 D02；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_delegation.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_delegation.person_id IS '实际参赛人';
CREATE INDEX ix_asp_delegation_a535dd5844 ON asp_delegation (person_id);
COMMENT ON COLUMN asp_delegation.operator_account_id IS '被授权办理账号';
CREATE INDEX ix_asp_delegation_1e2c6e4501 ON asp_delegation (operator_account_id);
COMMENT ON COLUMN asp_delegation.scope_type IS 'person/team/event/registration；应用核验对象类型';
COMMENT ON COLUMN asp_delegation.scope_id IS '对应作用域业务 ID';
COMMENT ON COLUMN asp_delegation.actions IS '明确允许的事务及依据；必须按版本校验结构';
COMMENT ON COLUMN asp_delegation.status IS '独立业务状态；合法值不等于业务已获批准：pending active revoked expired';
COMMENT ON COLUMN asp_delegation.valid_from IS '生效；有时区业务时间';
COMMENT ON COLUMN asp_delegation.valid_until IS '到期；有时区业务时间';
COMMENT ON COLUMN asp_delegation.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_delegation.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_delegation.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_delegation.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_delegation.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_delegation.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D02: 具体行为的告知与同意证据；不以一个勾选代替所有用途
CREATE TABLE asp_consent (
    id bigint NOT NULL,
    person_id bigint NOT NULL,
    actor_account_id bigint NOT NULL,
    purpose varchar(100) NOT NULL,
    document_version varchar(100) NOT NULL,
    scope jsonb NOT NULL,
    accepted_at timestamptz NOT NULL,
    revoked_at timestamptz,
    evidence_hash varchar(128) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_consent IS '具体行为的告知与同意证据；不以一个勾选代替所有用途；来源：母版 D02；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_consent.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_consent.person_id IS '涉及参赛人';
CREATE INDEX ix_asp_consent_e38cc432c1 ON asp_consent (person_id);
COMMENT ON COLUMN asp_consent.actor_account_id IS '本人或合法监护办理人';
CREATE INDEX ix_asp_consent_68623c10a7 ON asp_consent (actor_account_id);
COMMENT ON COLUMN asp_consent.purpose IS '明确处理用途';
COMMENT ON COLUMN asp_consent.document_version IS '告知材料版本';
COMMENT ON COLUMN asp_consent.scope IS '行为和资料范围；必须按版本校验结构';
COMMENT ON COLUMN asp_consent.accepted_at IS '确认时间；有时区业务时间';
COMMENT ON COLUMN asp_consent.revoked_at IS '撤回时间；有时区业务时间';
COMMENT ON COLUMN asp_consent.evidence_hash IS '确认内容摘要';
COMMENT ON COLUMN asp_consent.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_consent.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_consent.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_consent.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_consent.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_consent.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D01: 承办责任主体与租户映射
CREATE TABLE asp_organization (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    name varchar(200) NOT NULL,
    subject_type varchar(100) NOT NULL,
    subject_hash varchar(128) NOT NULL,
    status varchar(32) NOT NULL,
    contact_cipher varchar(1000),
    current_qualification_id bigint,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('draft', 'pending', 'correction', 'certified', 'expired', 'restricted')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_organization IS '承办责任主体与租户映射；来源：母版 D01；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_organization.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_organization.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_organization.name IS '主体名称';
COMMENT ON COLUMN asp_organization.subject_type IS '企业/学校/协会/俱乐部等';
COMMENT ON COLUMN asp_organization.subject_hash IS '主体标识受控摘要';
COMMENT ON COLUMN asp_organization.status IS '独立业务状态；合法值不等于业务已获批准：draft pending correction certified expired restricted';
COMMENT ON COLUMN asp_organization.contact_cipher IS '必要联系资料加密值';
COMMENT ON COLUMN asp_organization.current_qualification_id IS '当前适用资质版本；服务核验归属';
COMMENT ON COLUMN asp_organization.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_organization.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_organization.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_organization.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_organization.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_organization.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_organization_3bf7fb149d ON asp_organization (tenant_id, subject_hash);

-- D01: 组织资质申请及审核版本；失效不删除未完责任
CREATE TABLE asp_qualification (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    organization_id bigint NOT NULL,
    revision integer NOT NULL,
    proof_snapshot jsonb NOT NULL,
    business_scope jsonb NOT NULL,
    status varchar(32) NOT NULL,
    valid_from timestamptz,
    valid_until timestamptz,
    reviewer_id bigint,
    review_reason varchar(1000),
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (revision > 0),
    CHECK (valid_until IS NULL OR valid_from IS NULL OR valid_until > valid_from),
    CHECK (length(tenant_id) > 0),
    CHECK (revision >= 0),
    CHECK (status IN ('draft', 'pending', 'correction', 'approved', 'rejected', 'expired', 'restricted')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_qualification IS '组织资质申请及审核版本；失效不删除未完责任；来源：母版 D01；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_qualification.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_qualification.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_qualification.organization_id IS '申请主体';
CREATE INDEX ix_asp_qualification_9b8109903a ON asp_qualification (tenant_id, organization_id);
COMMENT ON COLUMN asp_qualification.revision IS '申请版本';
COMMENT ON COLUMN asp_qualification.proof_snapshot IS '审核时材料与经办授权；必须按版本校验结构';
COMMENT ON COLUMN asp_qualification.business_scope IS '可办业务范围；必须按版本校验结构';
COMMENT ON COLUMN asp_qualification.status IS '独立业务状态；合法值不等于业务已获批准：draft pending correction approved rejected expired restricted';
COMMENT ON COLUMN asp_qualification.valid_from IS '有效开始；有时区业务时间';
COMMENT ON COLUMN asp_qualification.valid_until IS '有效截止；有时区业务时间';
COMMENT ON COLUMN asp_qualification.reviewer_id IS '平台审核人后台账号';
COMMENT ON COLUMN asp_qualification.review_reason IS '结论依据';
COMMENT ON COLUMN asp_qualification.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_qualification.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_qualification.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_qualification.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_qualification.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_qualification.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_qualification_f0fca6bd13 ON asp_qualification (tenant_id, organization_id, revision);

-- D01: 工作人员组织、赛事、动作及材料范围授权
CREATE TABLE asp_staff_grant (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    organization_id bigint NOT NULL,
    account_id bigint NOT NULL,
    event_id bigint,
    permissions jsonb NOT NULL,
    status varchar(32) NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (valid_until IS NULL OR valid_until > valid_from),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('invited', 'active', 'revoked', 'expired')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_staff_grant IS '工作人员组织、赛事、动作及材料范围授权；来源：母版 D01；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_staff_grant.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_staff_grant.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_staff_grant.organization_id IS '授权组织';
CREATE INDEX ix_asp_staff_grant_3d19349684 ON asp_staff_grant (tenant_id, organization_id);
COMMENT ON COLUMN asp_staff_grant.account_id IS '工作人员平台账号';
CREATE INDEX ix_asp_staff_grant_f9a5b0f5e5 ON asp_staff_grant (account_id);
COMMENT ON COLUMN asp_staff_grant.event_id IS '限定赛事 ID；为空为组织范围，应用核验';
COMMENT ON COLUMN asp_staff_grant.permissions IS '动作与材料范围；必须按版本校验结构';
COMMENT ON COLUMN asp_staff_grant.status IS '独立业务状态；合法值不等于业务已获批准：invited active revoked expired';
COMMENT ON COLUMN asp_staff_grant.valid_from IS '生效；有时区业务时间';
COMMENT ON COLUMN asp_staff_grant.valid_until IS '到期；有时区业务时间';
COMMENT ON COLUMN asp_staff_grant.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_staff_grant.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_staff_grant.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_staff_grant.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_staff_grant.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_staff_grant.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D01: 多方办赛展示与业务授权分离
CREATE TABLE asp_collaboration (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    event_id bigint NOT NULL,
    organization_id bigint NOT NULL,
    partner_tenant_id varchar(20) NOT NULL,
    partner_organization_id bigint NOT NULL,
    display_role varchar(100) NOT NULL,
    authorized_scope jsonb NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (valid_until IS NULL OR valid_until > valid_from),
    CHECK (length(tenant_id) > 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_collaboration IS '多方办赛展示与业务授权分离；来源：母版 D01；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_collaboration.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_collaboration.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_collaboration.event_id IS '主责组织赛事';
CREATE INDEX ix_asp_collaboration_5ba06833ac ON asp_collaboration (tenant_id, event_id);
COMMENT ON COLUMN asp_collaboration.organization_id IS '授权发出组织；同租户';
CREATE INDEX ix_asp_collaboration_3d3e434d98 ON asp_collaboration (tenant_id, organization_id);
COMMENT ON COLUMN asp_collaboration.partner_tenant_id IS '合作组织所在租户；跨租户访问需独立授权';
COMMENT ON COLUMN asp_collaboration.partner_organization_id IS '合作主体 ID；跨租户 API 核验';
COMMENT ON COLUMN asp_collaboration.display_role IS '主办/承办/协办展示身份';
COMMENT ON COLUMN asp_collaboration.authorized_scope IS '明确可见赛事、动作、材料；必须按版本校验结构';
COMMENT ON COLUMN asp_collaboration.valid_from IS '合作生效；有时区业务时间';
COMMENT ON COLUMN asp_collaboration.valid_until IS '合作终止；有时区业务时间';
COMMENT ON COLUMN asp_collaboration.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_collaboration.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_collaboration.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_collaboration.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_collaboration.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_collaboration.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D04: 开放运动目录与变体；收录不等于自动规则已验证
CREATE TABLE asp_sport (
    id bigint NOT NULL,
    code varchar(100) NOT NULL,
    name varchar(100) NOT NULL,
    rule_family varchar(100) NOT NULL,
    capability_status varchar(32) NOT NULL,
    status varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (capability_status IN ('catalog', 'registration', 'manual', 'automatic', 'verified')),
    CHECK (status IN ('active', 'disabled')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_sport IS '开放运动目录与变体；收录不等于自动规则已验证；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_sport.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_sport.code IS '稳定运动或变体编码';
COMMENT ON COLUMN asp_sport.name IS '名称';
COMMENT ON COLUMN asp_sport.rule_family IS '对抗/计时/评分/综合等规则族';
COMMENT ON COLUMN asp_sport.capability_status IS '独立业务状态；合法值不等于业务已获批准：catalog registration manual automatic verified';
COMMENT ON COLUMN asp_sport.status IS '独立业务状态；合法值不等于业务已获批准：active disabled';
COMMENT ON COLUMN asp_sport.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_sport.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_sport.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_sport.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_sport.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_sport.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_sport_64fed3dbd2 ON asp_sport (code);

-- D03: 长期项目队伍；队名变化保留历史
CREATE TABLE asp_team (
    id bigint NOT NULL,
    name varchar(200) NOT NULL,
    sport_id bigint NOT NULL,
    captain_person_id bigint NOT NULL,
    creator_account_id bigint NOT NULL,
    join_policy varchar(32) NOT NULL,
    visibility varchar(32) NOT NULL,
    status varchar(32) NOT NULL,
    region varchar(100),
    profile jsonb,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (join_policy IN ('application', 'invitation', 'closed')),
    CHECK (visibility IN ('private', 'members', 'public')),
    CHECK (status IN ('active', 'recruiting_closed', 'frozen', 'archived', 'dissolved')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_team IS '长期项目队伍；队名变化保留历史；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_team.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_team.name IS '当前队名';
COMMENT ON COLUMN asp_team.sport_id IS '项目或变体';
CREATE INDEX ix_asp_team_f98848e1b8 ON asp_team (sport_id);
COMMENT ON COLUMN asp_team.captain_person_id IS '当前队长';
CREATE INDEX ix_asp_team_f026743fd0 ON asp_team (captain_person_id);
COMMENT ON COLUMN asp_team.creator_account_id IS '创建人';
CREATE INDEX ix_asp_team_620fab166c ON asp_team (creator_account_id);
COMMENT ON COLUMN asp_team.join_policy IS '独立业务状态；合法值不等于业务已获批准：application invitation closed';
COMMENT ON COLUMN asp_team.visibility IS '独立业务状态；合法值不等于业务已获批准：private members public';
COMMENT ON COLUMN asp_team.status IS '独立业务状态；合法值不等于业务已获批准：active recruiting_closed frozen archived dissolved';
COMMENT ON COLUMN asp_team.region IS '活动区域';
COMMENT ON COLUMN asp_team.profile IS '非敏感展示资料；必须按版本校验结构';
COMMENT ON COLUMN asp_team.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_team.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_team.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_team.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_team.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_team.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D03: 队伍成员有效期间、角色和入队来源
CREATE TABLE asp_team_member (
    id bigint NOT NULL,
    team_id bigint NOT NULL,
    person_id bigint NOT NULL,
    role varchar(32) NOT NULL,
    status varchar(32) NOT NULL,
    join_source varchar(100) NOT NULL,
    joined_at timestamptz NOT NULL,
    left_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (left_at IS NULL OR left_at >= joined_at),
    CHECK (role IN ('captain', 'vice_captain', 'member')),
    CHECK (status IN ('active', 'left', 'removed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_team_member IS '队伍成员有效期间、角色和入队来源；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_team_member.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_team_member.team_id IS '长期队伍';
CREATE INDEX ix_asp_team_member_7591d37c1e ON asp_team_member (team_id);
COMMENT ON COLUMN asp_team_member.person_id IS '现实成员';
CREATE INDEX ix_asp_team_member_b732ce61cb ON asp_team_member (person_id);
COMMENT ON COLUMN asp_team_member.role IS '独立业务状态；合法值不等于业务已获批准：captain vice_captain member';
COMMENT ON COLUMN asp_team_member.status IS '独立业务状态；合法值不等于业务已获批准：active left removed';
COMMENT ON COLUMN asp_team_member.join_source IS '申请批准或本人接受邀请';
COMMENT ON COLUMN asp_team_member.joined_at IS '入队时间；有时区业务时间';
COMMENT ON COLUMN asp_team_member.left_at IS '离队时间；有时区业务时间';
COMMENT ON COLUMN asp_team_member.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_team_member.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_team_member.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_team_member.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_team_member.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_team_member.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_team_member_f641c8ca15 ON asp_team_member (team_id, person_id) WHERE status = 'active';
CREATE UNIQUE INDEX uq_asp_team_member_ffe09a36d7 ON asp_team_member (team_id) WHERE status = 'active' AND role = 'captain';

-- D03: 入队申请处理记录
CREATE TABLE asp_team_join_request (
    id bigint NOT NULL,
    team_id bigint NOT NULL,
    person_id bigint NOT NULL,
    status varchar(32) NOT NULL,
    reviewer_account_id bigint,
    reason varchar(500),
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (status IN ('pending', 'approved', 'rejected', 'withdrawn')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_team_join_request IS '入队申请处理记录；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_team_join_request.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_team_join_request.team_id IS '申请队伍';
CREATE INDEX ix_asp_team_join_request_af23f80eb0 ON asp_team_join_request (team_id);
COMMENT ON COLUMN asp_team_join_request.person_id IS '申请者';
CREATE INDEX ix_asp_team_join_request_502a2f141d ON asp_team_join_request (person_id);
COMMENT ON COLUMN asp_team_join_request.status IS '独立业务状态；合法值不等于业务已获批准：pending approved rejected withdrawn';
COMMENT ON COLUMN asp_team_join_request.reviewer_account_id IS '处理人';
CREATE INDEX ix_asp_team_join_request_47326fba24 ON asp_team_join_request (reviewer_account_id);
COMMENT ON COLUMN asp_team_join_request.reason IS '处理依据';
COMMENT ON COLUMN asp_team_join_request.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_team_join_request.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_team_join_request.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_team_join_request.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_team_join_request.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_team_join_request.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_team_join_request_526d694205 ON asp_team_join_request (team_id, person_id) WHERE status = 'pending';

-- D03: 有期限的入队邀请；必须本人接受
CREATE TABLE asp_team_invitation (
    id bigint NOT NULL,
    team_id bigint NOT NULL,
    inviter_account_id bigint NOT NULL,
    target_person_id bigint,
    token_hash varchar(128) NOT NULL,
    expires_at timestamptz NOT NULL,
    max_uses integer NOT NULL,
    used_count integer NOT NULL,
    status varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (max_uses > 0),
    CHECK (used_count <= max_uses),
    CHECK (max_uses >= 0),
    CHECK (used_count >= 0),
    CHECK (status IN ('active', 'revoked', 'expired', 'exhausted')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_team_invitation IS '有期限的入队邀请；必须本人接受；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_team_invitation.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_team_invitation.team_id IS '邀请队伍';
CREATE INDEX ix_asp_team_invitation_3aa2742054 ON asp_team_invitation (team_id);
COMMENT ON COLUMN asp_team_invitation.inviter_account_id IS '邀请者';
CREATE INDEX ix_asp_team_invitation_541edd1125 ON asp_team_invitation (inviter_account_id);
COMMENT ON COLUMN asp_team_invitation.target_person_id IS '指定受邀人';
CREATE INDEX ix_asp_team_invitation_7d44d535b7 ON asp_team_invitation (target_person_id);
COMMENT ON COLUMN asp_team_invitation.token_hash IS '邀请凭据摘要；不保存明文';
COMMENT ON COLUMN asp_team_invitation.expires_at IS '有效期限；有时区业务时间';
COMMENT ON COLUMN asp_team_invitation.max_uses IS '允许接受人数';
COMMENT ON COLUMN asp_team_invitation.used_count IS '已接受人数；事务更新';
COMMENT ON COLUMN asp_team_invitation.status IS '独立业务状态；合法值不等于业务已获批准：active revoked expired exhausted';
COMMENT ON COLUMN asp_team_invitation.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_team_invitation.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_team_invitation.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_team_invitation.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_team_invitation.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_team_invitation.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_team_invitation_a11e9f41c0 ON asp_team_invitation (token_hash);

-- D03: 队伍改名、转让、归档等事实和历史快照
CREATE TABLE asp_team_history (
    id bigint NOT NULL,
    team_id bigint NOT NULL,
    action varchar(100) NOT NULL,
    before_snapshot jsonb NOT NULL,
    after_snapshot jsonb NOT NULL,
    reason varchar(1000) NOT NULL,
    effective_at timestamptz NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_team_history IS '队伍改名、转让、归档等事实和历史快照；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_team_history.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_team_history.team_id IS '长期队伍';
CREATE INDEX ix_asp_team_history_912eca6b66 ON asp_team_history (team_id);
COMMENT ON COLUMN asp_team_history.action IS '变更动作';
COMMENT ON COLUMN asp_team_history.before_snapshot IS '原事实；必须按版本校验结构';
COMMENT ON COLUMN asp_team_history.after_snapshot IS '新事实；必须按版本校验结构';
COMMENT ON COLUMN asp_team_history.reason IS '变更依据';
COMMENT ON COLUMN asp_team_history.effective_at IS '生效时间；有时区业务时间';
COMMENT ON COLUMN asp_team_history.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_team_history.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_team_history.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_team_history.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_team_history.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_team_history.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D03: 账户建队与入队配额；数值必须有规则版本
CREATE TABLE asp_team_quota (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    create_limit integer NOT NULL,
    join_limit integer NOT NULL,
    policy_version varchar(100) NOT NULL,
    exception_basis varchar(500),
    valid_until timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (create_limit >= 0),
    CHECK (join_limit >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_team_quota IS '账户建队与入队配额；数值必须有规则版本；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_team_quota.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_team_quota.account_id IS '受配额账号';
CREATE INDEX ix_asp_team_quota_3a6859e632 ON asp_team_quota (account_id);
COMMENT ON COLUMN asp_team_quota.create_limit IS '有效自建队上限；非固定 3';
COMMENT ON COLUMN asp_team_quota.join_limit IS '有效加入队上限；非固定 10';
COMMENT ON COLUMN asp_team_quota.policy_version IS '平台公开配额版本';
COMMENT ON COLUMN asp_team_quota.exception_basis IS '扩额批准依据';
COMMENT ON COLUMN asp_team_quota.valid_until IS '豁免或规则到期；有时区业务时间';
COMMENT ON COLUMN asp_team_quota.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_team_quota.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_team_quota.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_team_quota.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_team_quota.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_team_quota.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_team_quota_3a6859e632 ON asp_team_quota (account_id);

-- D04: 赛事容器；公开、报名开放、收费和开赛分别判定
CREATE TABLE asp_event (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    organization_id bigint NOT NULL,
    name varchar(200) NOT NULL,
    series_id bigint,
    starts_at timestamptz,
    ends_at timestamptz,
    registration_opens_at timestamptz,
    registration_closes_at timestamptz,
    status varchar(32) NOT NULL,
    registration_status varchar(32) NOT NULL,
    payment_status varchar(32) NOT NULL,
    visibility varchar(32) NOT NULL,
    published_revision integer NOT NULL,
    contact_snapshot jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at),
    CHECK (registration_closes_at IS NULL OR registration_opens_at IS NULL OR registration_closes_at > registration_opens_at),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('draft', 'pending', 'published', 'postponed', 'cancelled', 'completed', 'archived')),
    CHECK (registration_status IN ('closed', 'scheduled', 'open', 'suspended', 'ended')),
    CHECK (payment_status IN ('disabled', 'enabled', 'suspended')),
    CHECK (visibility IN ('private', 'public')),
    CHECK (published_revision >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_event IS '赛事容器；公开、报名开放、收费和开赛分别判定；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_event.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_event.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_event.organization_id IS '主责组织';
CREATE INDEX ix_asp_event_ba1502a512 ON asp_event (tenant_id, organization_id);
COMMENT ON COLUMN asp_event.name IS '赛事名称';
COMMENT ON COLUMN asp_event.series_id IS '系列/联赛业务关联；后续系列服务核验';
COMMENT ON COLUMN asp_event.starts_at IS '赛事总窗口开始；有时区业务时间';
COMMENT ON COLUMN asp_event.ends_at IS '赛事总窗口结束；有时区业务时间';
COMMENT ON COLUMN asp_event.registration_opens_at IS '报名开放；有时区业务时间';
COMMENT ON COLUMN asp_event.registration_closes_at IS '报名截止；有时区业务时间';
COMMENT ON COLUMN asp_event.status IS '独立业务状态；合法值不等于业务已获批准：draft pending published postponed cancelled completed archived';
COMMENT ON COLUMN asp_event.registration_status IS '独立业务状态；合法值不等于业务已获批准：closed scheduled open suspended ended';
COMMENT ON COLUMN asp_event.payment_status IS '独立业务状态；合法值不等于业务已获批准：disabled enabled suspended';
COMMENT ON COLUMN asp_event.visibility IS '独立业务状态；合法值不等于业务已获批准：private public';
COMMENT ON COLUMN asp_event.published_revision IS '当前发布版本；0 为未发布';
COMMENT ON COLUMN asp_event.contact_snapshot IS '履约联系及外部准入状态；必须按版本校验结构';
COMMENT ON COLUMN asp_event.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_event.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_event.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_event.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_event.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_event.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D04: 赛事对外承诺版本和重大变更说明
CREATE TABLE asp_event_revision (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    event_id bigint NOT NULL,
    revision integer NOT NULL,
    snapshot jsonb NOT NULL,
    reason varchar(1000) NOT NULL,
    published_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (revision > 0),
    CHECK (length(tenant_id) > 0),
    CHECK (revision >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_event_revision IS '赛事对外承诺版本和重大变更说明；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_event_revision.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_event_revision.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_event_revision.event_id IS '赛事';
CREATE INDEX ix_asp_event_revision_f1ffb3e031 ON asp_event_revision (tenant_id, event_id);
COMMENT ON COLUMN asp_event_revision.revision IS '发布版本';
COMMENT ON COLUMN asp_event_revision.snapshot IS '结构、规程、责任、资源与费用公开快照；必须按版本校验结构';
COMMENT ON COLUMN asp_event_revision.reason IS '变更依据';
COMMENT ON COLUMN asp_event_revision.published_at IS '发布生效；有时区业务时间';
COMMENT ON COLUMN asp_event_revision.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_event_revision.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_event_revision.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_event_revision.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_event_revision.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_event_revision.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_event_revision_c8379d5a8c ON asp_event_revision (tenant_id, event_id, revision);

-- D04: 报名坐标；运动、玩法、组别和参赛单位
CREATE TABLE asp_competition_unit (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    event_id bigint NOT NULL,
    sport_id bigint NOT NULL,
    name varchar(200) NOT NULL,
    entry_type varchar(32) NOT NULL,
    min_members integer NOT NULL,
    max_members integer NOT NULL,
    birth_from date,
    birth_until date,
    age_reference_date date,
    status varchar(32) NOT NULL,
    current_rule_id bigint,
    current_fee_policy_id bigint,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (min_members > 0),
    CHECK (max_members >= min_members),
    CHECK (birth_until IS NULL OR birth_from IS NULL OR birth_until >= birth_from),
    CHECK (length(tenant_id) > 0),
    CHECK (entry_type IN ('individual', 'pair', 'team')),
    CHECK (min_members >= 0),
    CHECK (max_members >= 0),
    CHECK (status IN ('draft', 'open', 'suspended', 'closed', 'cancelled')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_competition_unit IS '报名坐标；运动、玩法、组别和参赛单位；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_competition_unit.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_competition_unit.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_competition_unit.event_id IS '赛事';
CREATE INDEX ix_asp_competition_unit_8535df1119 ON asp_competition_unit (tenant_id, event_id);
COMMENT ON COLUMN asp_competition_unit.sport_id IS '运动及变体';
CREATE INDEX ix_asp_competition_unit_aa7f9ddb3b ON asp_competition_unit (sport_id);
COMMENT ON COLUMN asp_competition_unit.name IS '项目组别名称';
COMMENT ON COLUMN asp_competition_unit.entry_type IS '独立业务状态；合法值不等于业务已获批准：individual pair team';
COMMENT ON COLUMN asp_competition_unit.min_members IS '最低成员人数';
COMMENT ON COLUMN asp_competition_unit.max_members IS '最高名单人数';
COMMENT ON COLUMN asp_competition_unit.birth_from IS '允许出生日期下界，含边界';
COMMENT ON COLUMN asp_competition_unit.birth_until IS '允许出生日期上界，含边界';
COMMENT ON COLUMN asp_competition_unit.age_reference_date IS '年龄规程基准日';
COMMENT ON COLUMN asp_competition_unit.status IS '独立业务状态；合法值不等于业务已获批准：draft open suspended closed cancelled';
COMMENT ON COLUMN asp_competition_unit.current_rule_id IS '当前确认规则版本；应用核对单元归属';
COMMENT ON COLUMN asp_competition_unit.current_fee_policy_id IS '当前费用版本；应用核对归属';
COMMENT ON COLUMN asp_competition_unit.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_competition_unit.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_competition_unit.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_competition_unit.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_competition_unit.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_competition_unit.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D04: 资格、赛制、晋级和排名规则版本与专业来源
CREATE TABLE asp_rule_version (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    unit_id bigint NOT NULL,
    revision integer NOT NULL,
    source varchar(1000) NOT NULL,
    parameters jsonb NOT NULL,
    status varchar(32) NOT NULL,
    verification_level varchar(32) NOT NULL,
    confirmed_by bigint,
    confirmed_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (revision > 0),
    CHECK (length(tenant_id) > 0),
    CHECK (revision >= 0),
    CHECK (status IN ('draft', 'confirmed', 'retired')),
    CHECK (verification_level IN ('unverified', 'samples_verified', 'professional_verified')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_rule_version IS '资格、赛制、晋级和排名规则版本与专业来源；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_rule_version.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_rule_version.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_rule_version.unit_id IS '适用竞赛单元';
CREATE INDEX ix_asp_rule_version_47a590e281 ON asp_rule_version (tenant_id, unit_id);
COMMENT ON COLUMN asp_rule_version.revision IS '规则版本';
COMMENT ON COLUMN asp_rule_version.source IS '专业/地方/特别规程来源';
COMMENT ON COLUMN asp_rule_version.parameters IS '结构化规则；不得猜测缺项；必须按版本校验结构';
COMMENT ON COLUMN asp_rule_version.status IS '独立业务状态；合法值不等于业务已获批准：draft confirmed retired';
COMMENT ON COLUMN asp_rule_version.verification_level IS '独立业务状态；合法值不等于业务已获批准：unverified samples_verified professional_verified';
COMMENT ON COLUMN asp_rule_version.confirmed_by IS '有权确认人';
COMMENT ON COLUMN asp_rule_version.confirmed_at IS '确认时间；有时区业务时间';
COMMENT ON COLUMN asp_rule_version.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_rule_version.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_rule_version.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_rule_version.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_rule_version.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_rule_version.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_rule_version_59801a3a8d ON asp_rule_version (tenant_id, unit_id, revision);

-- D04: 赛事材料、用途与各阶段前置
CREATE TABLE asp_material_requirement (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    rule_version_id bigint NOT NULL,
    code varchar(100) NOT NULL,
    purpose varchar(500) NOT NULL,
    sensitivity varchar(32) NOT NULL,
    gates jsonb NOT NULL,
    retention_days integer,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (sensitivity IN ('ordinary', 'identity', 'guardian', 'health', 'finance')),
    CHECK (retention_days >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_material_requirement IS '赛事材料、用途与各阶段前置；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_material_requirement.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_material_requirement.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_material_requirement.rule_version_id IS '规则版本';
CREATE INDEX ix_asp_material_requirement_e44238f2fd ON asp_material_requirement (tenant_id, rule_version_id);
COMMENT ON COLUMN asp_material_requirement.code IS '材料编码';
COMMENT ON COLUMN asp_material_requirement.purpose IS '资料使用用途';
COMMENT ON COLUMN asp_material_requirement.sensitivity IS '独立业务状态；合法值不等于业务已获批准：ordinary identity guardian health finance';
COMMENT ON COLUMN asp_material_requirement.gates IS '占位/审核/检录/公开分别的前置及确认；必须按版本校验结构';
COMMENT ON COLUMN asp_material_requirement.retention_days IS '保留期限；0 须按政策明确解释';
COMMENT ON COLUMN asp_material_requirement.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_material_requirement.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_material_requirement.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_material_requirement.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_material_requirement.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_material_requirement.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_material_requirement_485f48e2db ON asp_material_requirement (tenant_id, rule_version_id, code);

-- D06: 赛事费用条款版本；路径、计价、承担方式相互独立
CREATE TABLE asp_fee_policy (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    unit_id bigint NOT NULL,
    revision integer NOT NULL,
    pricing_unit varchar(32) NOT NULL,
    pricing_rules jsonb NOT NULL,
    payer_modes jsonb NOT NULL,
    collection_paths jsonb NOT NULL,
    refund_terms jsonb NOT NULL,
    status varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (revision > 0),
    CHECK (length(tenant_id) > 0),
    CHECK (revision >= 0),
    CHECK (pricing_unit IN ('free', 'person', 'pair', 'team', 'project', 'combination')),
    CHECK (status IN ('draft', 'confirmed', 'retired')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_fee_policy IS '赛事费用条款版本；路径、计价、承担方式相互独立；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_fee_policy.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_fee_policy.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_fee_policy.unit_id IS '适用单元';
CREATE INDEX ix_asp_fee_policy_a1c8078315 ON asp_fee_policy (tenant_id, unit_id);
COMMENT ON COLUMN asp_fee_policy.revision IS '费用版本';
COMMENT ON COLUMN asp_fee_policy.pricing_unit IS '独立业务状态；合法值不等于业务已获批准：free person pair team project combination';
COMMENT ON COLUMN asp_fee_policy.pricing_rules IS '已确认计价和优惠顺序；必须按版本校验结构';
COMMENT ON COLUMN asp_fee_policy.payer_modes IS '统一/成员/代付/混合允许范围；必须按版本校验结构';
COMMENT ON COLUMN asp_fee_policy.collection_paths IS '实际接收主体、二维码/线下/可信渠道及准入；必须按版本校验结构';
COMMENT ON COLUMN asp_fee_policy.refund_terms IS '退赛、部分失败、取消、服务费及渠道费责任；必须按版本校验结构';
COMMENT ON COLUMN asp_fee_policy.status IS '独立业务状态；合法值不等于业务已获批准：draft confirmed retired';
COMMENT ON COLUMN asp_fee_policy.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_fee_policy.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_fee_policy.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_fee_policy.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_fee_policy.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_fee_policy.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_fee_policy_1d97b077a1 ON asp_fee_policy (tenant_id, unit_id, revision);

-- D05: 领队提交批次；不等于一笔订单
CREATE TABLE asp_registration_batch (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    submitter_account_id bigint NOT NULL,
    request_key varchar(128) NOT NULL,
    status varchar(32) NOT NULL,
    total_count integer NOT NULL,
    success_count integer NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (success_count <= total_count),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('processing', 'completed', 'partial', 'failed')),
    CHECK (total_count >= 0),
    CHECK (success_count >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_registration_batch IS '领队提交批次；不等于一笔订单；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_registration_batch.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_registration_batch.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_registration_batch.submitter_account_id IS '提交人';
CREATE INDEX ix_asp_registration_batch_6523f9e051 ON asp_registration_batch (submitter_account_id);
COMMENT ON COLUMN asp_registration_batch.request_key IS '请求幂等键';
COMMENT ON COLUMN asp_registration_batch.status IS '独立业务状态；合法值不等于业务已获批准：processing completed partial failed';
COMMENT ON COLUMN asp_registration_batch.total_count IS '提交条目数';
COMMENT ON COLUMN asp_registration_batch.success_count IS '成功条目数';
COMMENT ON COLUMN asp_registration_batch.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_registration_batch.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_registration_batch.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_registration_batch.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_registration_batch.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_registration_batch.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_registration_batch_5aeb3df352 ON asp_registration_batch (tenant_id, submitter_account_id, request_key);

-- D05: 具体竞赛单元报名及临时资格
CREATE TABLE asp_registration (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    unit_id bigint NOT NULL,
    rule_version_id bigint NOT NULL,
    fee_policy_id bigint,
    batch_id bigint,
    team_id bigint,
    submitter_account_id bigint NOT NULL,
    operator_account_id bigint NOT NULL,
    request_key varchar(128) NOT NULL,
    status varchar(32) NOT NULL,
    hold_expires_at timestamptz,
    roster_revision integer NOT NULL,
    team_name_snapshot varchar(200),
    submitted_at timestamptz NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('pre_registered', 'supplement', 'valid', 'expired', 'rejected', 'withdrawn', 'cancelled')),
    CHECK (roster_revision >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_registration IS '具体竞赛单元报名及临时资格；来源：母版 D05；事务协调名额、现实身份兼项、费用义务和临时日历；重试复用原报名；规则与费用必须属于该单元。';
COMMENT ON COLUMN asp_registration.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_registration.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_registration.unit_id IS '报名单元';
CREATE INDEX ix_asp_registration_217fd3d0fd ON asp_registration (tenant_id, unit_id);
COMMENT ON COLUMN asp_registration.rule_version_id IS '提交时规则';
CREATE INDEX ix_asp_registration_f8b0175b47 ON asp_registration (tenant_id, rule_version_id);
COMMENT ON COLUMN asp_registration.fee_policy_id IS '费用依据';
CREATE INDEX ix_asp_registration_a0d5d3804d ON asp_registration (tenant_id, fee_policy_id);
COMMENT ON COLUMN asp_registration.batch_id IS '操作批次';
CREATE INDEX ix_asp_registration_c3c2a32d6f ON asp_registration (tenant_id, batch_id);
COMMENT ON COLUMN asp_registration.team_id IS '可选长期代表队';
CREATE INDEX ix_asp_registration_34a0daff97 ON asp_registration (team_id);
COMMENT ON COLUMN asp_registration.submitter_account_id IS '原提交人';
CREATE INDEX ix_asp_registration_ee864d6727 ON asp_registration (submitter_account_id);
COMMENT ON COLUMN asp_registration.operator_account_id IS '当前办理人';
CREATE INDEX ix_asp_registration_bddadcf747 ON asp_registration (operator_account_id);
COMMENT ON COLUMN asp_registration.request_key IS '提交幂等键';
COMMENT ON COLUMN asp_registration.status IS '独立业务状态；合法值不等于业务已获批准：pre_registered supplement valid expired rejected withdrawn cancelled';
COMMENT ON COLUMN asp_registration.hold_expires_at IS '临时占位期限；有时区业务时间';
COMMENT ON COLUMN asp_registration.roster_revision IS '当前名单版本';
COMMENT ON COLUMN asp_registration.team_name_snapshot IS '报名时队名';
COMMENT ON COLUMN asp_registration.submitted_at IS '实际提交时间；有时区业务时间';
COMMENT ON COLUMN asp_registration.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_registration.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_registration.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_registration.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_registration.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_registration.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_registration_5795931c89 ON asp_registration (tenant_id, submitter_account_id, request_key);

-- D05: 赛事报名名单版本；替补和冻结依据
CREATE TABLE asp_roster_version (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    registration_id bigint NOT NULL,
    revision integer NOT NULL,
    rule_version_id bigint NOT NULL,
    status varchar(32) NOT NULL,
    effective_at timestamptz,
    change_reason varchar(1000) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (revision > 0),
    CHECK (length(tenant_id) > 0),
    CHECK (revision >= 0),
    CHECK (status IN ('draft', 'effective', 'frozen', 'superseded')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_roster_version IS '赛事报名名单版本；替补和冻结依据；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_roster_version.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_roster_version.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_roster_version.registration_id IS '报名';
CREATE INDEX ix_asp_roster_version_945cc0a5de ON asp_roster_version (tenant_id, registration_id);
COMMENT ON COLUMN asp_roster_version.revision IS '名单版本';
COMMENT ON COLUMN asp_roster_version.rule_version_id IS '核验规则';
CREATE INDEX ix_asp_roster_version_8fd2ad298f ON asp_roster_version (tenant_id, rule_version_id);
COMMENT ON COLUMN asp_roster_version.status IS '独立业务状态；合法值不等于业务已获批准：draft effective frozen superseded';
COMMENT ON COLUMN asp_roster_version.effective_at IS '名单生效；有时区业务时间';
COMMENT ON COLUMN asp_roster_version.change_reason IS '换人/补员/冻结依据';
COMMENT ON COLUMN asp_roster_version.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_roster_version.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_roster_version.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_roster_version.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_roster_version.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_roster_version.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_roster_version_6b1031feba ON asp_roster_version (tenant_id, registration_id, revision);

-- D05: 名单内实际参赛人及资格快照
CREATE TABLE asp_roster_member (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    roster_version_id bigint NOT NULL,
    person_id bigint NOT NULL,
    role varchar(32) NOT NULL,
    person_snapshot jsonb NOT NULL,
    qualification_status varchar(32) NOT NULL,
    position integer,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (role IN ('starter', 'substitute', 'leader')),
    CHECK (qualification_status IN ('pending', 'supplement', 'approved', 'rejected', 'restricted')),
    CHECK (position >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_roster_member IS '名单内实际参赛人及资格快照；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_roster_member.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_roster_member.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_roster_member.roster_version_id IS '名单版本';
CREATE INDEX ix_asp_roster_member_d30ecbbac1 ON asp_roster_member (tenant_id, roster_version_id);
COMMENT ON COLUMN asp_roster_member.person_id IS '现实选手';
CREATE INDEX ix_asp_roster_member_b94356d0b2 ON asp_roster_member (person_id);
COMMENT ON COLUMN asp_roster_member.role IS '独立业务状态；合法值不等于业务已获批准：starter substitute leader';
COMMENT ON COLUMN asp_roster_member.person_snapshot IS '报名必要身份、年龄及代表资格；敏感字段受控；必须按版本校验结构';
COMMENT ON COLUMN asp_roster_member.qualification_status IS '独立业务状态；合法值不等于业务已获批准：pending supplement approved rejected restricted';
COMMENT ON COLUMN asp_roster_member.position IS '顺序或位置；0 是否适用由规则解释';
COMMENT ON COLUMN asp_roster_member.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_roster_member.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_roster_member.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_roster_member.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_roster_member.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_roster_member.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_roster_member_d3f3554a9f ON asp_roster_member (tenant_id, roster_version_id, person_id);

-- D05: 逐成员/整单审核记录；材料与到账不互相替代
CREATE TABLE asp_qualification_review (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    registration_id bigint NOT NULL,
    roster_member_id bigint,
    decision varchar(32) NOT NULL,
    basis jsonb NOT NULL,
    reviewer_id bigint NOT NULL,
    reviewed_at timestamptz NOT NULL,
    reason varchar(1000) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (decision IN ('supplement', 'approved', 'rejected')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_qualification_review IS '逐成员/整单审核记录；材料与到账不互相替代；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_qualification_review.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_qualification_review.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_qualification_review.registration_id IS '报名';
CREATE INDEX ix_asp_qualification_review_babfdefa39 ON asp_qualification_review (tenant_id, registration_id);
COMMENT ON COLUMN asp_qualification_review.roster_member_id IS '审核成员；整单可为空';
CREATE INDEX ix_asp_qualification_review_77130e3af5 ON asp_qualification_review (tenant_id, roster_member_id);
COMMENT ON COLUMN asp_qualification_review.decision IS '独立业务状态；合法值不等于业务已获批准：supplement approved rejected';
COMMENT ON COLUMN asp_qualification_review.basis IS '所见名单/材料/费用及规则版本；必须按版本校验结构';
COMMENT ON COLUMN asp_qualification_review.reviewer_id IS '审核后台账号';
COMMENT ON COLUMN asp_qualification_review.reviewed_at IS '确认时间；有时区业务时间';
COMMENT ON COLUMN asp_qualification_review.reason IS '具体结论依据';
COMMENT ON COLUMN asp_qualification_review.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_qualification_review.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_qualification_review.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_qualification_review.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_qualification_review.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_qualification_review.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D05: 总人数或项目容量；单位和去重范围显式
CREATE TABLE asp_capacity_pool (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    event_id bigint NOT NULL,
    unit_id bigint,
    capacity_unit varchar(32) NOT NULL,
    dedupe_scope varchar(100) NOT NULL,
    limit_count integer NOT NULL,
    used_count integer NOT NULL,
    status varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (used_count <= limit_count),
    CHECK (length(tenant_id) > 0),
    CHECK (capacity_unit IN ('person', 'pair', 'team', 'seat', 'lane')),
    CHECK (limit_count >= 0),
    CHECK (used_count >= 0),
    CHECK (status IN ('active', 'suspended', 'closed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_capacity_pool IS '总人数或项目容量；单位和去重范围显式；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_capacity_pool.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_capacity_pool.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_capacity_pool.event_id IS '赛事';
CREATE INDEX ix_asp_capacity_pool_94e0b99016 ON asp_capacity_pool (tenant_id, event_id);
COMMENT ON COLUMN asp_capacity_pool.unit_id IS '项目容量；总量可为空';
CREATE INDEX ix_asp_capacity_pool_44fc872a06 ON asp_capacity_pool (tenant_id, unit_id);
COMMENT ON COLUMN asp_capacity_pool.capacity_unit IS '独立业务状态；合法值不等于业务已获批准：person pair team seat lane';
COMMENT ON COLUMN asp_capacity_pool.dedupe_scope IS '计数去重范围';
COMMENT ON COLUMN asp_capacity_pool.limit_count IS '上限';
COMMENT ON COLUMN asp_capacity_pool.used_count IS '当前有效及临时占用数；同事务维护';
COMMENT ON COLUMN asp_capacity_pool.status IS '独立业务状态；合法值不等于业务已获批准：active suspended closed';
COMMENT ON COLUMN asp_capacity_pool.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_capacity_pool.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_capacity_pool.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_capacity_pool.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_capacity_pool.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_capacity_pool.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D05: 容量唯一占用对象；同人兼项总人数只占一次
CREATE TABLE asp_capacity_occupation (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    pool_id bigint NOT NULL,
    subject_key varchar(128) NOT NULL,
    person_id bigint,
    status varchar(32) NOT NULL,
    expires_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('held', 'effective', 'released')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_capacity_occupation IS '容量唯一占用对象；同人兼项总人数只占一次；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_capacity_occupation.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_capacity_occupation.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_capacity_occupation.pool_id IS '容量池';
CREATE INDEX ix_asp_capacity_occupation_b5f4c6ed4e ON asp_capacity_occupation (tenant_id, pool_id);
COMMENT ON COLUMN asp_capacity_occupation.subject_key IS 'person:<ID> 或 entry:<ID> 等稳定单位键';
COMMENT ON COLUMN asp_capacity_occupation.person_id IS '按人占用时对应身份';
CREATE INDEX ix_asp_capacity_occupation_14434dcbb9 ON asp_capacity_occupation (person_id);
COMMENT ON COLUMN asp_capacity_occupation.status IS '独立业务状态；合法值不等于业务已获批准：held effective released';
COMMENT ON COLUMN asp_capacity_occupation.expires_at IS '仅临时占用期限；有时区业务时间';
COMMENT ON COLUMN asp_capacity_occupation.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_capacity_occupation.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_capacity_occupation.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_capacity_occupation.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_capacity_occupation.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_capacity_occupation.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_capacity_occupation_4234bf62c2 ON asp_capacity_occupation (tenant_id, pool_id, subject_key) WHERE status IN ('held','effective');

-- D05: 报名到容量占用的引用；取消最后引用才释放去重人数
CREATE TABLE asp_occupation_reference (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    occupation_id bigint NOT NULL,
    registration_id bigint NOT NULL,
    status varchar(32) NOT NULL,
    released_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('active', 'released')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_occupation_reference IS '报名到容量占用的引用；取消最后引用才释放去重人数；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_occupation_reference.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_occupation_reference.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_occupation_reference.occupation_id IS '共享占用';
CREATE INDEX ix_asp_occupation_reference_82be73443c ON asp_occupation_reference (tenant_id, occupation_id);
COMMENT ON COLUMN asp_occupation_reference.registration_id IS '使用占用的报名';
CREATE INDEX ix_asp_occupation_reference_1adb05c0a7 ON asp_occupation_reference (tenant_id, registration_id);
COMMENT ON COLUMN asp_occupation_reference.status IS '独立业务状态；合法值不等于业务已获批准：active released';
COMMENT ON COLUMN asp_occupation_reference.released_at IS '解除引用；有时区业务时间';
COMMENT ON COLUMN asp_occupation_reference.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_occupation_reference.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_occupation_reference.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_occupation_reference.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_occupation_reference.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_occupation_reference.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_occupation_reference_b12e8bc97c ON asp_occupation_reference (tenant_id, occupation_id, registration_id) WHERE status = 'active';

-- D05: 候补排序、获邀确认及期限
CREATE TABLE asp_waitlist (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    registration_id bigint NOT NULL,
    pool_id bigint NOT NULL,
    rank integer NOT NULL,
    basis varchar(500) NOT NULL,
    status varchar(32) NOT NULL,
    confirm_until timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (rank >= 0),
    CHECK (status IN ('waiting', 'invited', 'confirmed', 'expired', 'withdrawn')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_waitlist IS '候补排序、获邀确认及期限；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_waitlist.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_waitlist.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_waitlist.registration_id IS '候补申请';
CREATE INDEX ix_asp_waitlist_7980fdb5d5 ON asp_waitlist (tenant_id, registration_id);
COMMENT ON COLUMN asp_waitlist.pool_id IS '容量池';
CREATE INDEX ix_asp_waitlist_41dba4146a ON asp_waitlist (tenant_id, pool_id);
COMMENT ON COLUMN asp_waitlist.rank IS '公布规则下候补排序';
COMMENT ON COLUMN asp_waitlist.basis IS '排序依据';
COMMENT ON COLUMN asp_waitlist.status IS '独立业务状态；合法值不等于业务已获批准：waiting invited confirmed expired withdrawn';
COMMENT ON COLUMN asp_waitlist.confirm_until IS '递补确认期限；有时区业务时间';
COMMENT ON COLUMN asp_waitlist.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_waitlist.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_waitlist.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_waitlist.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_waitlist.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_waitlist.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_waitlist_695512a614 ON asp_waitlist (tenant_id, registration_id, pool_id) WHERE status IN ('waiting','invited');

-- D05: 退赛申请、资格终止及退款义务接续
CREATE TABLE asp_withdrawal (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    registration_id bigint NOT NULL,
    person_id bigint,
    applicant_account_id bigint NOT NULL,
    status varchar(32) NOT NULL,
    reason varchar(1000) NOT NULL,
    impact jsonb NOT NULL,
    effective_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('requested', 'approved', 'rejected', 'completed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_withdrawal IS '退赛申请、资格终止及退款义务接续；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_withdrawal.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_withdrawal.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_withdrawal.registration_id IS '报名';
CREATE INDEX ix_asp_withdrawal_52d060aa3e ON asp_withdrawal (tenant_id, registration_id);
COMMENT ON COLUMN asp_withdrawal.person_id IS '允许局部退赛时对应成员';
CREATE INDEX ix_asp_withdrawal_541124a5f2 ON asp_withdrawal (person_id);
COMMENT ON COLUMN asp_withdrawal.applicant_account_id IS '申请者';
CREATE INDEX ix_asp_withdrawal_597f30ba70 ON asp_withdrawal (applicant_account_id);
COMMENT ON COLUMN asp_withdrawal.status IS '独立业务状态；合法值不等于业务已获批准：requested approved rejected completed';
COMMENT ON COLUMN asp_withdrawal.reason IS '请求及批准依据';
COMMENT ON COLUMN asp_withdrawal.impact IS '资格、名单、名额、时间和资金影响；必须按版本校验结构';
COMMENT ON COLUMN asp_withdrawal.effective_at IS '退赛生效；有时区业务时间';
COMMENT ON COLUMN asp_withdrawal.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_withdrawal.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_withdrawal.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_withdrawal.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_withdrawal.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_withdrawal.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D06: 确认应收义务；免费赛事无需虚构到账
CREATE TABLE asp_fee_obligation (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    registration_id bigint NOT NULL,
    fee_policy_id bigint NOT NULL,
    total_amount numeric(18,2) NOT NULL,
    currency varchar(3) NOT NULL,
    status varchar(32) NOT NULL,
    quote_snapshot jsonb NOT NULL,
    request_key varchar(128) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (total_amount >= 0),
    CHECK (status IN ('unassigned', 'pending', 'partial', 'completed', 'terminated')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_fee_obligation IS '确认应收义务；免费赛事无需虚构到账；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_fee_obligation.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_fee_obligation.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_fee_obligation.registration_id IS '报名';
CREATE INDEX ix_asp_fee_obligation_a44fb80ed8 ON asp_fee_obligation (tenant_id, registration_id);
COMMENT ON COLUMN asp_fee_obligation.fee_policy_id IS '费用版本';
CREATE INDEX ix_asp_fee_obligation_381f50c2e6 ON asp_fee_obligation (tenant_id, fee_policy_id);
COMMENT ON COLUMN asp_fee_obligation.total_amount IS '确认总额；人民币元，不能用浮点';
COMMENT ON COLUMN asp_fee_obligation.currency IS '币种 CNY；其他币种需另行确认';
COMMENT ON COLUMN asp_fee_obligation.status IS '独立业务状态；合法值不等于业务已获批准：unassigned pending partial completed terminated';
COMMENT ON COLUMN asp_fee_obligation.quote_snapshot IS '数量、单价、优惠与确认明细；必须按版本校验结构';
COMMENT ON COLUMN asp_fee_obligation.request_key IS '义务建立幂等键';
COMMENT ON COLUMN asp_fee_obligation.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_fee_obligation.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_fee_obligation.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_fee_obligation.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_fee_obligation.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_fee_obligation.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_fee_obligation_679d7db660 ON asp_fee_obligation (tenant_id, registration_id, request_key);

-- D06: 应收服务、选手及项目明细
CREATE TABLE asp_fee_item (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    obligation_id bigint NOT NULL,
    person_id bigint,
    service_code varchar(100) NOT NULL,
    quantity numeric(12,4) NOT NULL,
    unit varchar(100) NOT NULL,
    unit_price numeric(18,2) NOT NULL,
    discount_amount numeric(18,2) NOT NULL,
    amount numeric(18,2) NOT NULL,
    basis jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (quantity > 0),
    CHECK (unit_price >= 0),
    CHECK (discount_amount >= 0),
    CHECK (amount >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_fee_item IS '应收服务、选手及项目明细；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_fee_item.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_fee_item.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_fee_item.obligation_id IS '义务';
CREATE INDEX ix_asp_fee_item_387b639c71 ON asp_fee_item (tenant_id, obligation_id);
COMMENT ON COLUMN asp_fee_item.person_id IS '按人计价对应选手';
CREATE INDEX ix_asp_fee_item_c65d43fdbc ON asp_fee_item (person_id);
COMMENT ON COLUMN asp_fee_item.service_code IS '收费项目';
COMMENT ON COLUMN asp_fee_item.quantity IS '数量与计价单位';
COMMENT ON COLUMN asp_fee_item.unit IS '计价单位';
COMMENT ON COLUMN asp_fee_item.unit_price IS '单价；人民币元，不能用浮点';
COMMENT ON COLUMN asp_fee_item.discount_amount IS '优惠；人民币元，不能用浮点';
COMMENT ON COLUMN asp_fee_item.amount IS '最终明细金额；人民币元，不能用浮点';
COMMENT ON COLUMN asp_fee_item.basis IS '计价顺序与优惠依据；必须按版本校验结构';
COMMENT ON COLUMN asp_fee_item.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_fee_item.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_fee_item.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_fee_item.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_fee_item.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_fee_item.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D06: 经确认的承担者及代付范围
CREATE TABLE asp_fee_share (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    obligation_id bigint NOT NULL,
    account_id bigint NOT NULL,
    person_id bigint,
    amount numeric(18,2) NOT NULL,
    status varchar(32) NOT NULL,
    accepted_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (amount >= 0),
    CHECK (status IN ('pending', 'accepted', 'cancelled')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_fee_share IS '经确认的承担者及代付范围；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_fee_share.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_fee_share.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_fee_share.obligation_id IS '费用义务';
CREATE INDEX ix_asp_fee_share_a56fd0817d ON asp_fee_share (tenant_id, obligation_id);
COMMENT ON COLUMN asp_fee_share.account_id IS '承担账号';
CREATE INDEX ix_asp_fee_share_957a7049ae ON asp_fee_share (account_id);
COMMENT ON COLUMN asp_fee_share.person_id IS '对应选手';
CREATE INDEX ix_asp_fee_share_b0b119e510 ON asp_fee_share (person_id);
COMMENT ON COLUMN asp_fee_share.amount IS '承担金额；人民币元，不能用浮点';
COMMENT ON COLUMN asp_fee_share.status IS '独立业务状态；合法值不等于业务已获批准：pending accepted cancelled';
COMMENT ON COLUMN asp_fee_share.accepted_at IS '分担确认；有时区业务时间';
COMMENT ON COLUMN asp_fee_share.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_fee_share.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_fee_share.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_fee_share.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_fee_share.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_fee_share.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D06: 实际收款事实及可信核对；截图不代表到账
CREATE TABLE asp_payment (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    payer_account_id bigint NOT NULL,
    channel varchar(100) NOT NULL,
    payee_subject varchar(200) NOT NULL,
    transaction_id varchar(200),
    amount numeric(18,2) NOT NULL,
    currency varchar(3) NOT NULL,
    status varchar(32) NOT NULL,
    evidence jsonb NOT NULL,
    occurred_at timestamptz,
    confirmed_at timestamptz,
    request_key varchar(128) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (amount >= 0),
    CHECK (status IN ('processing', 'verifying', 'confirmed', 'abnormal', 'failed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_payment IS '实际收款事实及可信核对；截图不代表到账；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_payment.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_payment.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_payment.payer_account_id IS '真实付款人账号';
CREATE INDEX ix_asp_payment_4dcd39863b ON asp_payment (payer_account_id);
COMMENT ON COLUMN asp_payment.channel IS '线上渠道/人工码/线下';
COMMENT ON COLUMN asp_payment.payee_subject IS '真实接收主体';
COMMENT ON COLUMN asp_payment.transaction_id IS '渠道或人工核对业务号';
COMMENT ON COLUMN asp_payment.amount IS '实际金额；人民币元，不能用浮点';
COMMENT ON COLUMN asp_payment.currency IS '币种';
COMMENT ON COLUMN asp_payment.status IS '独立业务状态；合法值不等于业务已获批准：processing verifying confirmed abnormal failed';
COMMENT ON COLUMN asp_payment.evidence IS '渠道确认及核对依据；敏感信息受控；必须按版本校验结构';
COMMENT ON COLUMN asp_payment.occurred_at IS '实际发生；有时区业务时间';
COMMENT ON COLUMN asp_payment.confirmed_at IS '平台核实；有时区业务时间';
COMMENT ON COLUMN asp_payment.request_key IS '发起幂等键';
COMMENT ON COLUMN asp_payment.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_payment.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_payment.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_payment.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_payment.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_payment.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_payment_b59aec1c6f ON asp_payment (tenant_id, payer_account_id, request_key);
CREATE UNIQUE INDEX uq_asp_payment_2e67061e98 ON asp_payment (tenant_id, channel, payee_subject, transaction_id) WHERE transaction_id IS NOT NULL;

-- D06: 付款到义务与分担的映射；多付进入异常，不新增资格
CREATE TABLE asp_payment_allocation (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    payment_id bigint NOT NULL,
    obligation_id bigint NOT NULL,
    share_id bigint,
    amount numeric(18,2) NOT NULL,
    status varchar(32) NOT NULL,
    request_key varchar(128) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (amount > 0),
    CHECK (length(tenant_id) > 0),
    CHECK (amount >= 0),
    CHECK (status IN ('effective', 'reversed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_payment_allocation IS '付款到义务与分担的映射；多付进入异常，不新增资格；来源：母版 D06；事务锁定付款和义务，累计有效分配不能超过确认收款或待收余额；分担须属于义务。';
COMMENT ON COLUMN asp_payment_allocation.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_payment_allocation.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_payment_allocation.payment_id IS '实际付款';
CREATE INDEX ix_asp_payment_allocation_edb278edfd ON asp_payment_allocation (tenant_id, payment_id);
COMMENT ON COLUMN asp_payment_allocation.obligation_id IS '覆盖义务';
CREATE INDEX ix_asp_payment_allocation_fc85422adc ON asp_payment_allocation (tenant_id, obligation_id);
COMMENT ON COLUMN asp_payment_allocation.share_id IS '对应分担';
CREATE INDEX ix_asp_payment_allocation_f2b19b68bb ON asp_payment_allocation (tenant_id, share_id);
COMMENT ON COLUMN asp_payment_allocation.amount IS '有效分配金额；人民币元，不能用浮点';
COMMENT ON COLUMN asp_payment_allocation.status IS '独立业务状态；合法值不等于业务已获批准：effective reversed';
COMMENT ON COLUMN asp_payment_allocation.request_key IS '分配幂等键';
COMMENT ON COLUMN asp_payment_allocation.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_payment_allocation.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_payment_allocation.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_payment_allocation.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_payment_allocation.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_payment_allocation.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_payment_allocation_7550106937 ON asp_payment_allocation (tenant_id, payment_id, request_key);

-- D06: 少付、多付、迟到款、重复款及无法定位款的处理队列
CREATE TABLE asp_payment_exception (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    payment_id bigint NOT NULL,
    exception_type varchar(100) NOT NULL,
    status varchar(32) NOT NULL,
    owner_id bigint,
    resolution jsonb,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('open', 'investigating', 'resolved', 'disputed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_payment_exception IS '少付、多付、迟到款、重复款及无法定位款的处理队列；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_payment_exception.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_payment_exception.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_payment_exception.payment_id IS '付款事实';
CREATE INDEX ix_asp_payment_exception_b2f12c109c ON asp_payment_exception (tenant_id, payment_id);
COMMENT ON COLUMN asp_payment_exception.exception_type IS '明确资金异常类型';
COMMENT ON COLUMN asp_payment_exception.status IS '独立业务状态；合法值不等于业务已获批准：open investigating resolved disputed';
COMMENT ON COLUMN asp_payment_exception.owner_id IS '实际处理责任人';
COMMENT ON COLUMN asp_payment_exception.resolution IS '核对和处置证据；必须按版本校验结构';
COMMENT ON COLUMN asp_payment_exception.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_payment_exception.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_payment_exception.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_payment_exception.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_payment_exception.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_payment_exception.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D06: 退款请求、批准、执行和核实；关联原付款人
CREATE TABLE asp_refund (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    payment_id bigint NOT NULL,
    allocation_id bigint,
    withdrawal_id bigint,
    applicant_account_id bigint NOT NULL,
    requested_amount numeric(18,2) NOT NULL,
    approved_amount numeric(18,2),
    completed_amount numeric(18,2),
    status varchar(32) NOT NULL,
    channel_reference varchar(200),
    reason varchar(1000) NOT NULL,
    request_key varchar(128) NOT NULL,
    completed_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (approved_amount IS NULL OR approved_amount <= requested_amount),
    CHECK (completed_amount IS NULL OR (approved_amount IS NOT NULL AND completed_amount <= approved_amount)),
    CHECK (length(tenant_id) > 0),
    CHECK (requested_amount >= 0),
    CHECK (approved_amount >= 0),
    CHECK (completed_amount >= 0),
    CHECK (status IN ('requested', 'approved', 'rejected', 'executing', 'completed', 'failed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_refund IS '退款请求、批准、执行和核实；关联原付款人；来源：母版 D06；累计退款在锁定原确认付款后核对可退余额，原付款人不随队长变更；执行失败保留待办。';
COMMENT ON COLUMN asp_refund.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_refund.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_refund.payment_id IS '原实际付款';
CREATE INDEX ix_asp_refund_6c91a131df ON asp_refund (tenant_id, payment_id);
COMMENT ON COLUMN asp_refund.allocation_id IS '被退服务分配';
CREATE INDEX ix_asp_refund_4119153df3 ON asp_refund (tenant_id, allocation_id);
COMMENT ON COLUMN asp_refund.withdrawal_id IS '相关退赛';
CREATE INDEX ix_asp_refund_0889c78c72 ON asp_refund (tenant_id, withdrawal_id);
COMMENT ON COLUMN asp_refund.applicant_account_id IS '申请者';
CREATE INDEX ix_asp_refund_9796403cc4 ON asp_refund (applicant_account_id);
COMMENT ON COLUMN asp_refund.requested_amount IS '申请金额；人民币元，不能用浮点';
COMMENT ON COLUMN asp_refund.approved_amount IS '批准金额；人民币元，不能用浮点';
COMMENT ON COLUMN asp_refund.completed_amount IS '已核实退款金额；人民币元，不能用浮点';
COMMENT ON COLUMN asp_refund.status IS '独立业务状态；合法值不等于业务已获批准：requested approved rejected executing completed failed';
COMMENT ON COLUMN asp_refund.channel_reference IS '渠道退款唯一号';
COMMENT ON COLUMN asp_refund.reason IS '规则和退款责任依据';
COMMENT ON COLUMN asp_refund.request_key IS '幂等键';
COMMENT ON COLUMN asp_refund.completed_at IS '实际核实到账；有时区业务时间';
COMMENT ON COLUMN asp_refund.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_refund.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_refund.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_refund.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_refund.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_refund.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_refund_c08c271c10 ON asp_refund (tenant_id, payment_id, request_key);

-- D06: 平台服务收入依据；不能将报名流水认作平台收入
CREATE TABLE asp_service_fee (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    event_id bigint NOT NULL,
    contract_reference varchar(200) NOT NULL,
    calculation_basis jsonb NOT NULL,
    amount numeric(18,2) NOT NULL,
    status varchar(32) NOT NULL,
    confirmed_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (amount >= 0),
    CHECK (status IN ('calculated', 'confirmed', 'reversed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_service_fee IS '平台服务收入依据；不能将报名流水认作平台收入；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_service_fee.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_service_fee.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_service_fee.event_id IS '赛事';
CREATE INDEX ix_asp_service_fee_8b6014c1b8 ON asp_service_fee (tenant_id, event_id);
COMMENT ON COLUMN asp_service_fee.contract_reference IS '真实服务及合同依据';
COMMENT ON COLUMN asp_service_fee.calculation_basis IS '固定额/基数/费率/税及退费政策；必须按版本校验结构';
COMMENT ON COLUMN asp_service_fee.amount IS '确认服务费；人民币元，不能用浮点';
COMMENT ON COLUMN asp_service_fee.status IS '独立业务状态；合法值不等于业务已获批准：calculated confirmed reversed';
COMMENT ON COLUMN asp_service_fee.confirmed_at IS '收入核对；有时区业务时间';
COMMENT ON COLUMN asp_service_fee.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_service_fee.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_service_fee.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_service_fee.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_service_fee.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_service_fee.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D06: 收款方或支付机构结算证据；记账不证明已结算
CREATE TABLE asp_settlement (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    event_id bigint NOT NULL,
    subject varchar(200) NOT NULL,
    due_amount numeric(18,2) NOT NULL,
    settled_amount numeric(18,2) NOT NULL,
    status varchar(32) NOT NULL,
    evidence jsonb NOT NULL,
    reference varchar(200) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (settled_amount <= due_amount),
    CHECK (length(tenant_id) > 0),
    CHECK (due_amount >= 0),
    CHECK (settled_amount >= 0),
    CHECK (status IN ('pending', 'partial', 'completed', 'failed', 'disputed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_settlement IS '收款方或支付机构结算证据；记账不证明已结算；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_settlement.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_settlement.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_settlement.event_id IS '赛事';
CREATE INDEX ix_asp_settlement_9a2dc30a01 ON asp_settlement (tenant_id, event_id);
COMMENT ON COLUMN asp_settlement.subject IS '结算主体';
COMMENT ON COLUMN asp_settlement.due_amount IS '应结算；人民币元，不能用浮点';
COMMENT ON COLUMN asp_settlement.settled_amount IS '已核实结算；人民币元，不能用浮点';
COMMENT ON COLUMN asp_settlement.status IS '独立业务状态；合法值不等于业务已获批准：pending partial completed failed disputed';
COMMENT ON COLUMN asp_settlement.evidence IS '真实结算依据；必须按版本校验结构';
COMMENT ON COLUMN asp_settlement.reference IS '结算唯一号';
COMMENT ON COLUMN asp_settlement.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_settlement.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_settlement.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_settlement.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_settlement.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_settlement.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_settlement_a3c4d75445 ON asp_settlement (tenant_id, subject, reference);

-- D12: 场馆及实际管理责任
CREATE TABLE asp_venue (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    name varchar(200) NOT NULL,
    address varchar(500) NOT NULL,
    operator varchar(200) NOT NULL,
    contact_cipher varchar(1000),
    status varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('active', 'maintenance', 'disabled')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_venue IS '场馆及实际管理责任；来源：母版 D12；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_venue.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_venue.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_venue.name IS '场馆名';
COMMENT ON COLUMN asp_venue.address IS '地址';
COMMENT ON COLUMN asp_venue.operator IS '实际责任主体';
COMMENT ON COLUMN asp_venue.contact_cipher IS '受控联络';
COMMENT ON COLUMN asp_venue.status IS '独立业务状态；合法值不等于业务已获批准：active maintenance disabled';
COMMENT ON COLUMN asp_venue.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_venue.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_venue.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_venue.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_venue.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_venue.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D12: 可分配资源单元及容量；整体和半场不能重复占用
CREATE TABLE asp_resource (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    venue_id bigint NOT NULL,
    parent_id bigint,
    name varchar(200) NOT NULL,
    resource_type varchar(100) NOT NULL,
    capacity integer NOT NULL,
    capacity_unit varchar(100) NOT NULL,
    status varchar(32) NOT NULL,
    sport_scope jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (capacity > 0),
    CHECK (parent_id IS NULL OR parent_id <> id),
    CHECK (length(tenant_id) > 0),
    CHECK (capacity >= 0),
    CHECK (status IN ('available', 'unconfirmed', 'maintenance', 'disabled')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_resource IS '可分配资源单元及容量；整体和半场不能重复占用；来源：母版 D12；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_resource.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_resource.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_resource.venue_id IS '场馆';
CREATE INDEX ix_asp_resource_d336122926 ON asp_resource (tenant_id, venue_id);
COMMENT ON COLUMN asp_resource.parent_id IS '整体/拆分父资源';
CREATE INDEX ix_asp_resource_20d7e5a093 ON asp_resource (tenant_id, parent_id);
COMMENT ON COLUMN asp_resource.name IS '场地或泳道等名称';
COMMENT ON COLUMN asp_resource.resource_type IS 'court/table/lane/track/judge_group 等';
COMMENT ON COLUMN asp_resource.capacity IS '可同时使用容量';
COMMENT ON COLUMN asp_resource.capacity_unit IS '容量单位';
COMMENT ON COLUMN asp_resource.status IS '独立业务状态；合法值不等于业务已获批准：available unconfirmed maintenance disabled';
COMMENT ON COLUMN asp_resource.sport_scope IS '运动适配及必要限制；必须按版本校验结构';
COMMENT ON COLUMN asp_resource.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_resource.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_resource.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_resource.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_resource.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_resource.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D12: 赛事资源使用确认；不冒充商业预约交易
CREATE TABLE asp_resource_reservation (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    resource_id bigint NOT NULL,
    event_id bigint NOT NULL,
    starts_at timestamptz NOT NULL,
    ends_at timestamptz NOT NULL,
    quantity integer NOT NULL,
    status varchar(32) NOT NULL,
    confirmation jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (ends_at > starts_at),
    CHECK (quantity > 0),
    CHECK (length(tenant_id) > 0),
    CHECK (quantity >= 0),
    CHECK (status IN ('requested', 'confirmed', 'cancelled')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_resource_reservation IS '赛事资源使用确认；不冒充商业预约交易；来源：母版 D12；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_resource_reservation.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_resource_reservation.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_resource_reservation.resource_id IS '具体资源';
CREATE INDEX ix_asp_resource_reservation_d78872c2b3 ON asp_resource_reservation (tenant_id, resource_id);
COMMENT ON COLUMN asp_resource_reservation.event_id IS '赛事';
CREATE INDEX ix_asp_resource_reservation_70bea28f7e ON asp_resource_reservation (tenant_id, event_id);
COMMENT ON COLUMN asp_resource_reservation.starts_at IS '使用开始；有时区业务时间';
COMMENT ON COLUMN asp_resource_reservation.ends_at IS '使用结束；有时区业务时间';
COMMENT ON COLUMN asp_resource_reservation.quantity IS '占用容量';
COMMENT ON COLUMN asp_resource_reservation.status IS '独立业务状态；合法值不等于业务已获批准：requested confirmed cancelled';
COMMENT ON COLUMN asp_resource_reservation.confirmation IS '场地方和赛事方确认依据；必须按版本校验结构';
COMMENT ON COLUMN asp_resource_reservation.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_resource_reservation.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_resource_reservation.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_resource_reservation.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_resource_reservation.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_resource_reservation.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D07: 受控跨赛事时间事实；与名额生命周期关联但独立
CREATE TABLE asp_time_constraint (
    id bigint NOT NULL,
    person_id bigint,
    resource_id bigint,
    source_tenant_id varchar(20) NOT NULL,
    source_type varchar(100) NOT NULL,
    source_id bigint NOT NULL,
    parent_id bigint,
    starts_at timestamptz NOT NULL,
    ends_at timestamptz NOT NULL,
    certainty varchar(32) NOT NULL,
    strength varchar(32) NOT NULL,
    status varchar(32) NOT NULL,
    buffer_before_seconds integer NOT NULL,
    buffer_after_seconds integer NOT NULL,
    expires_at timestamptz,
    basis jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (ends_at > starts_at),
    CHECK ((person_id IS NOT NULL) <> (resource_id IS NOT NULL)),
    CHECK (parent_id IS NULL OR parent_id <> id),
    CHECK (certainty IN ('tentative', 'conditional', 'confirmed')),
    CHECK (strength IN ('soft', 'hard')),
    CHECK (status IN ('held', 'active', 'released', 'cancelled')),
    CHECK (buffer_before_seconds >= 0),
    CHECK (buffer_after_seconds >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_time_constraint IS '受控跨赛事时间事实；与名额生命周期关联但独立；来源：母版 D07；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_time_constraint.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_time_constraint.person_id IS '实际相关人员';
CREATE INDEX ix_asp_time_constraint_a8964e349e ON asp_time_constraint (person_id);
COMMENT ON COLUMN asp_time_constraint.resource_id IS '资源 ID；source_tenant_id 标识资源所属方';
COMMENT ON COLUMN asp_time_constraint.source_tenant_id IS '来源租户；只返回受限冲突结果';
COMMENT ON COLUMN asp_time_constraint.source_type IS '报名/阶段/场次/裁判任务';
COMMENT ON COLUMN asp_time_constraint.source_id IS '来源业务 ID';
COMMENT ON COLUMN asp_time_constraint.parent_id IS '父子安排，避免自冲突';
CREATE INDEX ix_asp_time_constraint_2071901409 ON asp_time_constraint (parent_id);
COMMENT ON COLUMN asp_time_constraint.starts_at IS '约束开始；有时区业务时间';
COMMENT ON COLUMN asp_time_constraint.ends_at IS '约束结束；有时区业务时间';
COMMENT ON COLUMN asp_time_constraint.certainty IS '独立业务状态；合法值不等于业务已获批准：tentative conditional confirmed';
COMMENT ON COLUMN asp_time_constraint.strength IS '独立业务状态；合法值不等于业务已获批准：soft hard';
COMMENT ON COLUMN asp_time_constraint.status IS '独立业务状态；合法值不等于业务已获批准：held active released cancelled';
COMMENT ON COLUMN asp_time_constraint.buffer_before_seconds IS '确认的准备或转场缓冲';
COMMENT ON COLUMN asp_time_constraint.buffer_after_seconds IS '确认的恢复缓冲';
COMMENT ON COLUMN asp_time_constraint.expires_at IS '临时约束期限；有时区业务时间';
COMMENT ON COLUMN asp_time_constraint.basis IS '来源版本、晋级路径与排他条件；必须按版本校验结构';
COMMENT ON COLUMN asp_time_constraint.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_time_constraint.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_time_constraint.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_time_constraint.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_time_constraint.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_time_constraint.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D07: 冲突发现与协调证据；通知已读不等于解决
CREATE TABLE asp_conflict_case (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    trigger_type varchar(100) NOT NULL,
    trigger_id bigint NOT NULL,
    affected_refs jsonb NOT NULL,
    severity varchar(32) NOT NULL,
    status varchar(32) NOT NULL,
    resolution jsonb,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (severity IN ('soft', 'hard')),
    CHECK (status IN ('open', 'coordinating', 'resolved', 'rejected')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_conflict_case IS '冲突发现与协调证据；通知已读不等于解决；来源：母版 D07；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_conflict_case.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_conflict_case.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_conflict_case.trigger_type IS '提交/换人/改期/编排等';
COMMENT ON COLUMN asp_conflict_case.trigger_id IS '触发业务 ID';
COMMENT ON COLUMN asp_conflict_case.affected_refs IS '受影响来源及授权摘要；必须按版本校验结构';
COMMENT ON COLUMN asp_conflict_case.severity IS '独立业务状态；合法值不等于业务已获批准：soft hard';
COMMENT ON COLUMN asp_conflict_case.status IS '独立业务状态；合法值不等于业务已获批准：open coordinating resolved rejected';
COMMENT ON COLUMN asp_conflict_case.resolution IS '选择方案与授权依据；必须按版本校验结构';
COMMENT ON COLUMN asp_conflict_case.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_conflict_case.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_conflict_case.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_conflict_case.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_conflict_case.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_conflict_case.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D08: 竞赛阶段及已确认赛制关系
CREATE TABLE asp_stage (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    unit_id bigint NOT NULL,
    rule_version_id bigint NOT NULL,
    name varchar(100) NOT NULL,
    format varchar(100) NOT NULL,
    sequence integer NOT NULL,
    status varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (sequence >= 0),
    CHECK (status IN ('draft', 'ready', 'published', 'running', 'completed', 'cancelled')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_stage IS '竞赛阶段及已确认赛制关系；来源：母版 D08；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_stage.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_stage.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_stage.unit_id IS '竞赛单元';
CREATE INDEX ix_asp_stage_85fc908ca2 ON asp_stage (tenant_id, unit_id);
COMMENT ON COLUMN asp_stage.rule_version_id IS '适用规则';
CREATE INDEX ix_asp_stage_f9269c0082 ON asp_stage (tenant_id, rule_version_id);
COMMENT ON COLUMN asp_stage.name IS '阶段名称';
COMMENT ON COLUMN asp_stage.format IS '淘汰/循环/分组/计时/评分等确认格式';
COMMENT ON COLUMN asp_stage.sequence IS '阶段顺序';
COMMENT ON COLUMN asp_stage.status IS '独立业务状态；合法值不等于业务已获批准：draft ready published running completed cancelled';
COMMENT ON COLUMN asp_stage.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_stage.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_stage.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_stage.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_stage.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_stage.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_stage_7e51921066 ON asp_stage (tenant_id, unit_id, sequence);

-- D08: 抽签运行与可复核输入；不反复随机选择有利结果
CREATE TABLE asp_draw_run (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    stage_id bigint NOT NULL,
    rule_version_id bigint NOT NULL,
    revision integer NOT NULL,
    input_snapshot jsonb NOT NULL,
    random_seed varchar(200) NOT NULL,
    output_snapshot jsonb NOT NULL,
    status varchar(32) NOT NULL,
    reason varchar(1000) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (revision >= 0),
    CHECK (status IN ('draft', 'confirmed', 'superseded', 'failed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_draw_run IS '抽签运行与可复核输入；不反复随机选择有利结果；来源：母版 D08；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_draw_run.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_draw_run.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_draw_run.stage_id IS '阶段';
CREATE INDEX ix_asp_draw_run_fceb0110bb ON asp_draw_run (tenant_id, stage_id);
COMMENT ON COLUMN asp_draw_run.rule_version_id IS '规则版本';
CREATE INDEX ix_asp_draw_run_be023de228 ON asp_draw_run (tenant_id, rule_version_id);
COMMENT ON COLUMN asp_draw_run.revision IS '抽签版本';
COMMENT ON COLUMN asp_draw_run.input_snapshot IS '有效名单版本、种子、轮空与回避依据；必须按版本校验结构';
COMMENT ON COLUMN asp_draw_run.random_seed IS '复核随机来源及种子';
COMMENT ON COLUMN asp_draw_run.output_snapshot IS '签位及约束检查；必须按版本校验结构';
COMMENT ON COLUMN asp_draw_run.status IS '独立业务状态；合法值不等于业务已获批准：draft confirmed superseded failed';
COMMENT ON COLUMN asp_draw_run.reason IS '运行或重抽依据';
COMMENT ON COLUMN asp_draw_run.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_draw_run.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_draw_run.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_draw_run.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_draw_run.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_draw_run.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_draw_run_f53550e154 ON asp_draw_run (tenant_id, stage_id, revision);

-- D08: 约束编排草案、不可行原因及发布版本
CREATE TABLE asp_schedule_run (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    stage_id bigint NOT NULL,
    draw_run_id bigint,
    revision integer NOT NULL,
    input_snapshot jsonb NOT NULL,
    diagnostics jsonb NOT NULL,
    status varchar(32) NOT NULL,
    published_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (revision >= 0),
    CHECK (status IN ('draft', 'feasible', 'infeasible', 'published', 'superseded')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_schedule_run IS '约束编排草案、不可行原因及发布版本；来源：母版 D08；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_schedule_run.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_schedule_run.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_schedule_run.stage_id IS '阶段';
CREATE INDEX ix_asp_schedule_run_de3cc075fb ON asp_schedule_run (tenant_id, stage_id);
COMMENT ON COLUMN asp_schedule_run.draw_run_id IS '抽签依据';
CREATE INDEX ix_asp_schedule_run_c24d09d900 ON asp_schedule_run (tenant_id, draw_run_id);
COMMENT ON COLUMN asp_schedule_run.revision IS '排程版本';
COMMENT ON COLUMN asp_schedule_run.input_snapshot IS '规则、人员、资源、窗口、时长和缓冲；必须按版本校验结构';
COMMENT ON COLUMN asp_schedule_run.diagnostics IS '已排/未排/冲突及取舍；必须按版本校验结构';
COMMENT ON COLUMN asp_schedule_run.status IS '独立业务状态；合法值不等于业务已获批准：draft feasible infeasible published superseded';
COMMENT ON COLUMN asp_schedule_run.published_at IS '生效发布；有时区业务时间';
COMMENT ON COLUMN asp_schedule_run.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_schedule_run.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_schedule_run.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_schedule_run.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_schedule_run.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_schedule_run.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_schedule_run_e428b3f84c ON asp_schedule_run (tenant_id, stage_id, revision);

-- D09: 稳定比赛身份；时间变更不改场次身份
CREATE TABLE asp_match (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    stage_id bigint NOT NULL,
    schedule_run_id bigint,
    code varchar(100) NOT NULL,
    round_number integer NOT NULL,
    resource_id bigint,
    scheduled_start timestamptz,
    scheduled_end timestamptz,
    actual_start timestamptz,
    actual_end timestamptz,
    status varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (scheduled_end IS NULL OR scheduled_start IS NULL OR scheduled_end > scheduled_start),
    CHECK (actual_end IS NULL OR actual_start IS NULL OR actual_end >= actual_start),
    CHECK (length(tenant_id) > 0),
    CHECK (round_number >= 0),
    CHECK (status IN ('draft', 'published', 'checkin', 'running', 'completed', 'abandoned', 'cancelled')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_match IS '稳定比赛身份；时间变更不改场次身份；来源：母版 D09；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_match.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_match.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_match.stage_id IS '阶段';
CREATE INDEX ix_asp_match_c2cf93ae06 ON asp_match (tenant_id, stage_id);
COMMENT ON COLUMN asp_match.schedule_run_id IS '当前排程版本';
CREATE INDEX ix_asp_match_8f34176002 ON asp_match (tenant_id, schedule_run_id);
COMMENT ON COLUMN asp_match.code IS '阶段内稳定比赛编号';
COMMENT ON COLUMN asp_match.round_number IS '轮次';
COMMENT ON COLUMN asp_match.resource_id IS '安排资源';
CREATE INDEX ix_asp_match_4b3dd35375 ON asp_match (tenant_id, resource_id);
COMMENT ON COLUMN asp_match.scheduled_start IS '预计开始；有时区业务时间';
COMMENT ON COLUMN asp_match.scheduled_end IS '预计结束；有时区业务时间';
COMMENT ON COLUMN asp_match.actual_start IS '实际开始；有时区业务时间';
COMMENT ON COLUMN asp_match.actual_end IS '实际结束；有时区业务时间';
COMMENT ON COLUMN asp_match.status IS '独立业务状态；合法值不等于业务已获批准：draft published checkin running completed abandoned cancelled';
COMMENT ON COLUMN asp_match.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_match.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_match.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_match.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_match.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_match.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_match_43038ff706 ON asp_match (tenant_id, stage_id, code);

-- D09: 对阵或计时评分参赛集合；未来晋级席位可待定
CREATE TABLE asp_match_entry (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    match_id bigint NOT NULL,
    registration_id bigint,
    roster_version_id bigint,
    slot varchar(100) NOT NULL,
    qualification_source jsonb NOT NULL,
    status varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('pending', 'confirmed', 'withdrawn', 'disqualified')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_match_entry IS '对阵或计时评分参赛集合；未来晋级席位可待定；来源：母版 D09；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_match_entry.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_match_entry.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_match_entry.match_id IS '场次';
CREATE INDEX ix_asp_match_entry_8fa587a58f ON asp_match_entry (tenant_id, match_id);
COMMENT ON COLUMN asp_match_entry.registration_id IS '参赛报名；尚未晋级可为空';
CREATE INDEX ix_asp_match_entry_ab5db3318d ON asp_match_entry (tenant_id, registration_id);
COMMENT ON COLUMN asp_match_entry.roster_version_id IS '本场名单依据';
CREATE INDEX ix_asp_match_entry_4907f195db ON asp_match_entry (tenant_id, roster_version_id);
COMMENT ON COLUMN asp_match_entry.slot IS '对阵位置/道次/试次等';
COMMENT ON COLUMN asp_match_entry.qualification_source IS '已确认报名或条件晋级路径；必须按版本校验结构';
COMMENT ON COLUMN asp_match_entry.status IS '独立业务状态；合法值不等于业务已获批准：pending confirmed withdrawn disqualified';
COMMENT ON COLUMN asp_match_entry.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_match_entry.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_match_entry.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_match_entry.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_match_entry.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_match_entry.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_match_entry_ef50ad9eec ON asp_match_entry (tenant_id, match_id, slot);

-- D09: 单场阵容及实际出场；不能从当前队伍直接拉人上场
CREATE TABLE asp_lineup_member (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    match_entry_id bigint NOT NULL,
    roster_member_id bigint NOT NULL,
    role varchar(32) NOT NULL,
    position integer,
    status varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (role IN ('starter', 'substitute')),
    CHECK (position >= 0),
    CHECK (status IN ('planned', 'confirmed', 'replaced', 'appeared')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_lineup_member IS '单场阵容及实际出场；不能从当前队伍直接拉人上场；来源：母版 D09；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_lineup_member.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_lineup_member.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_lineup_member.match_entry_id IS '场次参赛单位';
CREATE INDEX ix_asp_lineup_member_a761239472 ON asp_lineup_member (tenant_id, match_entry_id);
COMMENT ON COLUMN asp_lineup_member.roster_member_id IS '冻结赛事名单成员';
CREATE INDEX ix_asp_lineup_member_0f3cbbbe80 ON asp_lineup_member (tenant_id, roster_member_id);
COMMENT ON COLUMN asp_lineup_member.role IS '独立业务状态；合法值不等于业务已获批准：starter substitute';
COMMENT ON COLUMN asp_lineup_member.position IS '规程要求顺序';
COMMENT ON COLUMN asp_lineup_member.status IS '独立业务状态；合法值不等于业务已获批准：planned confirmed replaced appeared';
COMMENT ON COLUMN asp_lineup_member.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_lineup_member.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_lineup_member.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_lineup_member.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_lineup_member.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_lineup_member.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_lineup_member_813d197632 ON asp_lineup_member (tenant_id, match_entry_id, roster_member_id);

-- D09: 逐现实选手报到/检录；队长到场不代表全队
CREATE TABLE asp_checkin (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    event_id bigint NOT NULL,
    person_id bigint NOT NULL,
    match_id bigint,
    check_type varchar(100) NOT NULL,
    status varchar(32) NOT NULL,
    verification jsonb NOT NULL,
    occurred_at timestamptz NOT NULL,
    request_key varchar(128) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('confirmed', 'corrected', 'rejected')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_checkin IS '逐现实选手报到/检录；队长到场不代表全队；来源：母版 D09；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_checkin.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_checkin.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_checkin.event_id IS '赛事';
CREATE INDEX ix_asp_checkin_3cc20a9a3e ON asp_checkin (tenant_id, event_id);
COMMENT ON COLUMN asp_checkin.person_id IS '实际到场人';
CREATE INDEX ix_asp_checkin_446f2cc796 ON asp_checkin (person_id);
COMMENT ON COLUMN asp_checkin.match_id IS '单场检录；赛事报到可为空';
CREATE INDEX ix_asp_checkin_3e9e71d86e ON asp_checkin (tenant_id, match_id);
COMMENT ON COLUMN asp_checkin.check_type IS 'event 或 match';
COMMENT ON COLUMN asp_checkin.status IS '独立业务状态；合法值不等于业务已获批准：confirmed corrected rejected';
COMMENT ON COLUMN asp_checkin.verification IS '授权核验方式及必要材料；必须按版本校验结构';
COMMENT ON COLUMN asp_checkin.occurred_at IS '现场发生时间；有时区业务时间';
COMMENT ON COLUMN asp_checkin.request_key IS '扫描/离线补录幂等键';
COMMENT ON COLUMN asp_checkin.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_checkin.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_checkin.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_checkin.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_checkin.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_checkin.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_checkin_711722409b ON asp_checkin (tenant_id, request_key);

-- D09: 裁判、记录员及结果确认人员到场次的授权任务
CREATE TABLE asp_official_assignment (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    match_id bigint NOT NULL,
    person_id bigint NOT NULL,
    role varchar(100) NOT NULL,
    status varchar(32) NOT NULL,
    basis jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('proposed', 'accepted', 'replaced', 'completed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_official_assignment IS '裁判、记录员及结果确认人员到场次的授权任务；来源：母版 D09；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_official_assignment.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_official_assignment.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_official_assignment.match_id IS '场次';
CREATE INDEX ix_asp_official_assignment_7b513d632e ON asp_official_assignment (tenant_id, match_id);
COMMENT ON COLUMN asp_official_assignment.person_id IS '现实执行人员';
CREATE INDEX ix_asp_official_assignment_41dc7655f6 ON asp_official_assignment (person_id);
COMMENT ON COLUMN asp_official_assignment.role IS '录入/确认/发布等';
COMMENT ON COLUMN asp_official_assignment.status IS '独立业务状态；合法值不等于业务已获批准：proposed accepted replaced completed';
COMMENT ON COLUMN asp_official_assignment.basis IS '职责与专业资格来源；必须按版本校验结构';
COMMENT ON COLUMN asp_official_assignment.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_official_assignment.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_official_assignment.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_official_assignment.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_official_assignment.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_official_assignment.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D10: 原始表现、有效性、专业确认及修订链
CREATE TABLE asp_result_version (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    match_id bigint NOT NULL,
    revision integer NOT NULL,
    previous_id bigint,
    status varchar(32) NOT NULL,
    raw_performance jsonb NOT NULL,
    decision jsonb NOT NULL,
    confirmer_id bigint,
    confirmed_at timestamptz,
    published_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (revision > 0),
    CHECK (previous_id IS NULL OR previous_id <> id),
    CHECK (length(tenant_id) > 0),
    CHECK (revision >= 0),
    CHECK (status IN ('draft', 'confirmed', 'appealed', 'published', 'superseded', 'void')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_result_version IS '原始表现、有效性、专业确认及修订链；来源：母版 D10；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_result_version.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_result_version.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_result_version.match_id IS '比赛';
CREATE INDEX ix_asp_result_version_1c5bad7d2e ON asp_result_version (tenant_id, match_id);
COMMENT ON COLUMN asp_result_version.revision IS '结果版本';
COMMENT ON COLUMN asp_result_version.previous_id IS '更正前版本';
CREATE INDEX ix_asp_result_version_01a3014925 ON asp_result_version (tenant_id, previous_id);
COMMENT ON COLUMN asp_result_version.status IS '独立业务状态；合法值不等于业务已获批准：draft confirmed appealed published superseded void';
COMMENT ON COLUMN asp_result_version.raw_performance IS '比分/计时/计量/评分等原始分项；必须按版本校验结构';
COMMENT ON COLUMN asp_result_version.decision IS '弃权、处罚、取消及结果专业依据；必须按版本校验结构';
COMMENT ON COLUMN asp_result_version.confirmer_id IS '有权确认人员';
COMMENT ON COLUMN asp_result_version.confirmed_at IS '确认；有时区业务时间';
COMMENT ON COLUMN asp_result_version.published_at IS '发布；有时区业务时间';
COMMENT ON COLUMN asp_result_version.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_result_version.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_result_version.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_result_version.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_result_version.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_result_version.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_result_version_5dda592a74 ON asp_result_version (tenant_id, match_id, revision);

-- D10: 每参赛单位原始成绩及单位；零与缺失/未完赛分开
CREATE TABLE asp_result_item (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    result_version_id bigint NOT NULL,
    match_entry_id bigint NOT NULL,
    performance_status varchar(32) NOT NULL,
    value numeric(20,6),
    unit varchar(100),
    components jsonb,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (performance_status IN ('valid', 'did_not_start', 'did_not_finish', 'forfeited', 'disqualified', 'invalid')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_result_item IS '每参赛单位原始成绩及单位；零与缺失/未完赛分开；来源：母版 D10；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_result_item.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_result_item.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_result_item.result_version_id IS '结果版本';
CREATE INDEX ix_asp_result_item_2f40c34f6f ON asp_result_item (tenant_id, result_version_id);
COMMENT ON COLUMN asp_result_item.match_entry_id IS '实际参赛单位';
CREATE INDEX ix_asp_result_item_9a5d685503 ON asp_result_item (tenant_id, match_entry_id);
COMMENT ON COLUMN asp_result_item.performance_status IS '独立业务状态；合法值不等于业务已获批准：valid did_not_start did_not_finish forfeited disqualified invalid';
COMMENT ON COLUMN asp_result_item.value IS '可比较主数值；分项另存，缺失不是零';
COMMENT ON COLUMN asp_result_item.unit IS 'second/metre/point/kg 等确认单位';
COMMENT ON COLUMN asp_result_item.components IS '局、试次、裁判分项和处罚；必须按版本校验结构';
COMMENT ON COLUMN asp_result_item.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_result_item.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_result_item.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_result_item.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_result_item.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_result_item.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_result_item_0840c62a07 ON asp_result_item (tenant_id, result_version_id, match_entry_id);

-- D08: 确认结果驱动晋级；重复确认不重复产生席位
CREATE TABLE asp_advancement (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    result_version_id bigint NOT NULL,
    registration_id bigint NOT NULL,
    target_stage_id bigint NOT NULL,
    target_slot varchar(100) NOT NULL,
    status varchar(32) NOT NULL,
    basis jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('pending', 'confirmed', 'superseded', 'revoked')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_advancement IS '确认结果驱动晋级；重复确认不重复产生席位；来源：母版 D08；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_advancement.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_advancement.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_advancement.result_version_id IS '上游已确认结果';
CREATE INDEX ix_asp_advancement_e6fdd62047 ON asp_advancement (tenant_id, result_version_id);
COMMENT ON COLUMN asp_advancement.registration_id IS '晋级报名单位';
CREATE INDEX ix_asp_advancement_8de3a730b7 ON asp_advancement (tenant_id, registration_id);
COMMENT ON COLUMN asp_advancement.target_stage_id IS '下一阶段';
CREATE INDEX ix_asp_advancement_f36c110b02 ON asp_advancement (tenant_id, target_stage_id);
COMMENT ON COLUMN asp_advancement.target_slot IS '下一阶段稳定席位';
COMMENT ON COLUMN asp_advancement.status IS '独立业务状态；合法值不等于业务已获批准：pending confirmed superseded revoked';
COMMENT ON COLUMN asp_advancement.basis IS '名次或成绩资格依据；必须按版本校验结构';
COMMENT ON COLUMN asp_advancement.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_advancement.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_advancement.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_advancement.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_advancement.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_advancement.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_advancement_42f7e9c58c ON asp_advancement (tenant_id, target_stage_id, target_slot) WHERE status = 'confirmed';

-- D08: 排名计算输入与同分规则版本；可独立复算
CREATE TABLE asp_ranking_run (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    unit_id bigint NOT NULL,
    rule_version_id bigint NOT NULL,
    revision integer NOT NULL,
    input_results jsonb NOT NULL,
    comparison_rules jsonb NOT NULL,
    status varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (revision >= 0),
    CHECK (status IN ('draft', 'confirmed', 'published', 'superseded')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_ranking_run IS '排名计算输入与同分规则版本；可独立复算；来源：母版 D08；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_ranking_run.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_ranking_run.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_ranking_run.unit_id IS '统计单元';
CREATE INDEX ix_asp_ranking_run_82944954dd ON asp_ranking_run (tenant_id, unit_id);
COMMENT ON COLUMN asp_ranking_run.rule_version_id IS '排名规则';
CREATE INDEX ix_asp_ranking_run_707f86d252 ON asp_ranking_run (tenant_id, rule_version_id);
COMMENT ON COLUMN asp_ranking_run.revision IS '排名版本';
COMMENT ON COLUMN asp_ranking_run.input_results IS '有效原始结果引用与处罚；必须按版本校验结构';
COMMENT ON COLUMN asp_ranking_run.comparison_rules IS '比较顺序、范围和并列；必须按版本校验结构';
COMMENT ON COLUMN asp_ranking_run.status IS '独立业务状态；合法值不等于业务已获批准：draft confirmed published superseded';
COMMENT ON COLUMN asp_ranking_run.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_ranking_run.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_ranking_run.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_ranking_run.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_ranking_run.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_ranking_run.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_ranking_run_6aca9c4176 ON asp_ranking_run (tenant_id, unit_id, revision);

-- D08: 有范围的个人或参赛单位名次
CREATE TABLE asp_ranking_item (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    ranking_run_id bigint NOT NULL,
    registration_id bigint NOT NULL,
    rank integer NOT NULL,
    comparison_values jsonb NOT NULL,
    explanation varchar(1000),
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (rank > 0),
    CHECK (length(tenant_id) > 0),
    CHECK (rank >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_ranking_item IS '有范围的个人或参赛单位名次；来源：母版 D08；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_ranking_item.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_ranking_item.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_ranking_item.ranking_run_id IS '排名运行';
CREATE INDEX ix_asp_ranking_item_bd98d8edf2 ON asp_ranking_item (tenant_id, ranking_run_id);
COMMENT ON COLUMN asp_ranking_item.registration_id IS '参赛单位';
CREATE INDEX ix_asp_ranking_item_44d2543cf1 ON asp_ranking_item (tenant_id, registration_id);
COMMENT ON COLUMN asp_ranking_item.rank IS '允许并列的名次';
COMMENT ON COLUMN asp_ranking_item.comparison_values IS '独立复算需要的原值和单位；必须按版本校验结构';
COMMENT ON COLUMN asp_ranking_item.explanation IS '并列/取消/规则说明';
COMMENT ON COLUMN asp_ranking_item.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_ranking_item.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_ranking_item.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_ranking_item.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_ranking_item.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_ranking_item.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_ranking_item_5ee4e98c43 ON asp_ranking_item (tenant_id, ranking_run_id, registration_id);

-- D09: 专业申诉与裁定；客服不能直接改赛果
CREATE TABLE asp_appeal (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    match_id bigint,
    registration_id bigint NOT NULL,
    applicant_account_id bigint NOT NULL,
    result_version_id bigint,
    reason varchar(2000) NOT NULL,
    evidence jsonb NOT NULL,
    status varchar(32) NOT NULL,
    submitted_at timestamptz NOT NULL,
    deadline_at timestamptz NOT NULL,
    decision jsonb,
    fee_obligation_id bigint,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (match_id IS NOT NULL OR result_version_id IS NULL),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('submitted', 'accepted', 'rejected', 'reviewing', 'decided', 'withdrawn')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_appeal IS '专业申诉与裁定；客服不能直接改赛果；来源：母版 D09；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_appeal.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_appeal.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_appeal.match_id IS '比赛';
CREATE INDEX ix_asp_appeal_11fff99669 ON asp_appeal (tenant_id, match_id);
COMMENT ON COLUMN asp_appeal.registration_id IS '相关报名';
CREATE INDEX ix_asp_appeal_5b2c3f012c ON asp_appeal (tenant_id, registration_id);
COMMENT ON COLUMN asp_appeal.applicant_account_id IS '获授权申请者';
CREATE INDEX ix_asp_appeal_31cfd37310 ON asp_appeal (applicant_account_id);
COMMENT ON COLUMN asp_appeal.result_version_id IS '争议结果';
CREATE INDEX ix_asp_appeal_c2f5a9575f ON asp_appeal (tenant_id, result_version_id);
COMMENT ON COLUMN asp_appeal.reason IS '申诉理由';
COMMENT ON COLUMN asp_appeal.evidence IS '受控证据；必须按版本校验结构';
COMMENT ON COLUMN asp_appeal.status IS '独立业务状态；合法值不等于业务已获批准：submitted accepted rejected reviewing decided withdrawn';
COMMENT ON COLUMN asp_appeal.submitted_at IS '实际提交；有时区业务时间';
COMMENT ON COLUMN asp_appeal.deadline_at IS '规程期限；有时区业务时间';
COMMENT ON COLUMN asp_appeal.decision IS '专业裁定及后续晋级影响；必须按版本校验结构';
COMMENT ON COLUMN asp_appeal.fee_obligation_id IS '如规程要求申诉费，另行费用义务核验';
COMMENT ON COLUMN asp_appeal.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_appeal.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_appeal.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_appeal.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_appeal.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_appeal.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D10: 分级荣誉及来源；当前佩戴不替代历史获得记录
CREATE TABLE asp_honor (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    event_id bigint,
    person_id bigint,
    team_id bigint,
    category varchar(32) NOT NULL,
    title varchar(200) NOT NULL,
    source jsonb NOT NULL,
    status varchar(32) NOT NULL,
    awarded_at timestamptz NOT NULL,
    display_until timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK ((person_id IS NOT NULL) <> (team_id IS NOT NULL)),
    CHECK (length(tenant_id) > 0),
    CHECK (category IN ('official', 'event', 'achievement', 'self_reported')),
    CHECK (status IN ('pending', 'verified', 'suspended', 'revised', 'revoked')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_honor IS '分级荣誉及来源；当前佩戴不替代历史获得记录；来源：母版 D10；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_honor.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_honor.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_honor.event_id IS '来源赛事';
CREATE INDEX ix_asp_honor_21af8d4817 ON asp_honor (tenant_id, event_id);
COMMENT ON COLUMN asp_honor.person_id IS '个人获得者';
CREATE INDEX ix_asp_honor_619408751b ON asp_honor (person_id);
COMMENT ON COLUMN asp_honor.team_id IS '队伍获得者';
CREATE INDEX ix_asp_honor_8b978dd3d7 ON asp_honor (team_id);
COMMENT ON COLUMN asp_honor.category IS '独立业务状态；合法值不等于业务已获批准：official event achievement self_reported';
COMMENT ON COLUMN asp_honor.title IS '含项目、届次、层级和范围的名称';
COMMENT ON COLUMN asp_honor.source IS '授予或公布主体、证据和实际获奖成员快照；必须按版本校验结构';
COMMENT ON COLUMN asp_honor.status IS '独立业务状态；合法值不等于业务已获批准：pending verified suspended revised revoked';
COMMENT ON COLUMN asp_honor.awarded_at IS '获得时间；有时区业务时间';
COMMENT ON COLUMN asp_honor.display_until IS '当前展示期限；有时区业务时间';
COMMENT ON COLUMN asp_honor.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_honor.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_honor.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_honor.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_honor.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_honor.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D10: 非竞技成长事实；规则有来源，防止刷空赛事
CREATE TABLE asp_growth_record (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    person_id bigint,
    team_id bigint,
    policy_version varchar(100) NOT NULL,
    achievement varchar(100) NOT NULL,
    source jsonb NOT NULL,
    status varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK ((person_id IS NOT NULL) <> (team_id IS NOT NULL)),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('effective', 'disputed', 'revoked')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_growth_record IS '非竞技成长事实；规则有来源，防止刷空赛事；来源：母版 D10；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_growth_record.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_growth_record.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_growth_record.person_id IS '个人';
CREATE INDEX ix_asp_growth_record_b8e456a801 ON asp_growth_record (person_id);
COMMENT ON COLUMN asp_growth_record.team_id IS '队伍';
CREATE INDEX ix_asp_growth_record_8fb8a219a7 ON asp_growth_record (team_id);
COMMENT ON COLUMN asp_growth_record.policy_version IS '成长规则版本';
COMMENT ON COLUMN asp_growth_record.achievement IS '参与/完赛/志愿等经确认行为';
COMMENT ON COLUMN asp_growth_record.source IS '原业务事实及范围；必须按版本校验结构';
COMMENT ON COLUMN asp_growth_record.status IS '独立业务状态；合法值不等于业务已获批准：effective disputed revoked';
COMMENT ON COLUMN asp_growth_record.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_growth_record.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_growth_record.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_growth_record.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_growth_record.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_growth_record.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D13: 重大变更旧新版本、影响及责任接续
CREATE TABLE asp_change_case (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    object_type varchar(100) NOT NULL,
    object_id bigint NOT NULL,
    before_snapshot jsonb NOT NULL,
    after_snapshot jsonb NOT NULL,
    impact jsonb NOT NULL,
    status varchar(32) NOT NULL,
    reason varchar(2000) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('draft', 'reviewing', 'approved', 'published', 'coordinating', 'completed', 'rejected')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_change_case IS '重大变更旧新版本、影响及责任接续；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_change_case.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_change_case.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_change_case.object_type IS '赛事/名单/收费/结果等';
COMMENT ON COLUMN asp_change_case.object_id IS '业务对象';
COMMENT ON COLUMN asp_change_case.before_snapshot IS '原事实；必须按版本校验结构';
COMMENT ON COLUMN asp_change_case.after_snapshot IS '草案或已确认事实；必须按版本校验结构';
COMMENT ON COLUMN asp_change_case.impact IS '受影响人员、资源、金额、晋级、证书及通知；必须按版本校验结构';
COMMENT ON COLUMN asp_change_case.status IS '独立业务状态；合法值不等于业务已获批准：draft reviewing approved published coordinating completed rejected';
COMMENT ON COLUMN asp_change_case.reason IS '变更依据';
COMMENT ON COLUMN asp_change_case.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_change_case.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_change_case.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_change_case.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_change_case.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_change_case.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D11: 业务通知内容版本及对象；不可夹带未授权营销
CREATE TABLE asp_notification (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    recipient_account_id bigint NOT NULL,
    business_type varchar(100) NOT NULL,
    business_id bigint NOT NULL,
    business_revision integer NOT NULL,
    purpose varchar(100) NOT NULL,
    content jsonb NOT NULL,
    dedupe_key varchar(200) NOT NULL,
    read_at timestamptz,
    confirmed_at timestamptz,
    response jsonb,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (business_revision >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_notification IS '业务通知内容版本及对象；不可夹带未授权营销；来源：母版 D11；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_notification.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_notification.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_notification.recipient_account_id IS '目标账号';
CREATE INDEX ix_asp_notification_54506f0b85 ON asp_notification (recipient_account_id);
COMMENT ON COLUMN asp_notification.business_type IS '来源业务类型';
COMMENT ON COLUMN asp_notification.business_id IS '来源业务对象';
COMMENT ON COLUMN asp_notification.business_revision IS '来源版本';
COMMENT ON COLUMN asp_notification.purpose IS '必要服务或经同意营销';
COMMENT ON COLUMN asp_notification.content IS '允许告知范围；必须按版本校验结构';
COMMENT ON COLUMN asp_notification.dedupe_key IS '重复处理防重键';
COMMENT ON COLUMN asp_notification.read_at IS '已读；有时区业务时间';
COMMENT ON COLUMN asp_notification.confirmed_at IS '用户作出决定；有时区业务时间';
COMMENT ON COLUMN asp_notification.response IS '接受/协调/退赛等业务决定；必须按版本校验结构';
COMMENT ON COLUMN asp_notification.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_notification.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_notification.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_notification.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_notification.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_notification.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_notification_51234987a2 ON asp_notification (tenant_id, recipient_account_id, dedupe_key);

-- D11: 逐渠道发送和送达结果；失败需责任人跟进
CREATE TABLE asp_notification_delivery (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    notification_id bigint NOT NULL,
    channel varchar(100) NOT NULL,
    attempt integer NOT NULL,
    status varchar(32) NOT NULL,
    channel_reference varchar(200),
    sent_at timestamptz,
    delivered_at timestamptz,
    failure_reason varchar(1000),
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (attempt >= 0),
    CHECK (status IN ('pending', 'sent', 'delivered', 'failed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_notification_delivery IS '逐渠道发送和送达结果；失败需责任人跟进；来源：母版 D11；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_notification_delivery.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_notification_delivery.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_notification_delivery.notification_id IS '通知';
CREATE INDEX ix_asp_notification_delivery_4d1557bb10 ON asp_notification_delivery (tenant_id, notification_id);
COMMENT ON COLUMN asp_notification_delivery.channel IS '站内/短信/小程序等';
COMMENT ON COLUMN asp_notification_delivery.attempt IS '尝试次数';
COMMENT ON COLUMN asp_notification_delivery.status IS '独立业务状态；合法值不等于业务已获批准：pending sent delivered failed';
COMMENT ON COLUMN asp_notification_delivery.channel_reference IS '渠道回执';
COMMENT ON COLUMN asp_notification_delivery.sent_at IS '发送；有时区业务时间';
COMMENT ON COLUMN asp_notification_delivery.delivered_at IS '送达；有时区业务时间';
COMMENT ON COLUMN asp_notification_delivery.failure_reason IS '失败原因';
COMMENT ON COLUMN asp_notification_delivery.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_notification_delivery.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_notification_delivery.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_notification_delivery.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_notification_delivery.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_notification_delivery.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_notification_delivery_d5acc6e672 ON asp_notification_delivery (tenant_id, notification_id, channel, attempt);

-- D13: 共享文件元数据；无永久公开凭据，访问由用途授权
CREATE TABLE asp_file (
    id bigint NOT NULL,
    owner_account_id bigint NOT NULL,
    owning_tenant_id varchar(20),
    object_key varchar(500) NOT NULL,
    sha256 varchar(64) NOT NULL,
    purpose varchar(200) NOT NULL,
    sensitivity varchar(32) NOT NULL,
    retain_until timestamptz,
    status varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (sensitivity IN ('public', 'ordinary', 'identity', 'guardian', 'health', 'finance', 'result')),
    CHECK (status IN ('active', 'restricted', 'expired', 'deleted')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_file IS '共享文件元数据；无永久公开凭据，访问由用途授权；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_file.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_file.owner_account_id IS '上传及权利主体';
CREATE INDEX ix_asp_file_71cbb06677 ON asp_file (owner_account_id);
COMMENT ON COLUMN asp_file.owning_tenant_id IS '组织资料归属租户；个人资料可为空';
COMMENT ON COLUMN asp_file.object_key IS '存储键；不能直接形成无鉴权 URL';
COMMENT ON COLUMN asp_file.sha256 IS '内容摘要';
COMMENT ON COLUMN asp_file.purpose IS '必要用途';
COMMENT ON COLUMN asp_file.sensitivity IS '独立业务状态；合法值不等于业务已获批准：public ordinary identity guardian health finance result';
COMMENT ON COLUMN asp_file.retain_until IS '保留政策截止；有时区业务时间';
COMMENT ON COLUMN asp_file.status IS '独立业务状态；合法值不等于业务已获批准：active restricted expired deleted';
COMMENT ON COLUMN asp_file.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_file.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_file.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_file.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_file.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_file.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_file_9194f64174 ON asp_file (object_key);

-- D05: 报名材料提交版本、核验与现场验证分离
CREATE TABLE asp_material_submission (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    registration_id bigint NOT NULL,
    roster_member_id bigint,
    requirement_id bigint NOT NULL,
    file_id bigint NOT NULL,
    revision integer NOT NULL,
    status varchar(32) NOT NULL,
    valid_until timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (revision >= 0),
    CHECK (status IN ('submitted', 'correction', 'accepted', 'rejected', 'expired')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_material_submission IS '报名材料提交版本、核验与现场验证分离；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_material_submission.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_material_submission.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_material_submission.registration_id IS '报名';
CREATE INDEX ix_asp_material_submission_e06913ebbf ON asp_material_submission (tenant_id, registration_id);
COMMENT ON COLUMN asp_material_submission.roster_member_id IS '相关成员';
CREATE INDEX ix_asp_material_submission_2247bbd71d ON asp_material_submission (tenant_id, roster_member_id);
COMMENT ON COLUMN asp_material_submission.requirement_id IS '规程要求';
CREATE INDEX ix_asp_material_submission_2c753b4f5d ON asp_material_submission (tenant_id, requirement_id);
COMMENT ON COLUMN asp_material_submission.file_id IS '受控材料';
CREATE INDEX ix_asp_material_submission_ec40f1fb3b ON asp_material_submission (file_id);
COMMENT ON COLUMN asp_material_submission.revision IS '提交版本';
COMMENT ON COLUMN asp_material_submission.status IS '独立业务状态；合法值不等于业务已获批准：submitted correction accepted rejected expired';
COMMENT ON COLUMN asp_material_submission.valid_until IS '材料有效截止；有时区业务时间';
COMMENT ON COLUMN asp_material_submission.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_material_submission.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_material_submission.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_material_submission.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_material_submission.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_material_submission.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_material_submission_7354dd7460 ON asp_material_submission (tenant_id, registration_id, requirement_id, roster_member_id, revision);

-- D13: 平台投诉、反馈及分派；专业结果争议移交申诉
CREATE TABLE asp_complaint (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    applicant_account_id bigint NOT NULL,
    object_type varchar(100) NOT NULL,
    object_id bigint NOT NULL,
    request varchar(2000) NOT NULL,
    evidence jsonb NOT NULL,
    status varchar(32) NOT NULL,
    owner_id bigint,
    resolution jsonb,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('submitted', 'accepted', 'investigating', 'resolved', 'rejected', 'appealed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_complaint IS '平台投诉、反馈及分派；专业结果争议移交申诉；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_complaint.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_complaint.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_complaint.applicant_account_id IS '投诉人';
CREATE INDEX ix_asp_complaint_143ba948f2 ON asp_complaint (applicant_account_id);
COMMENT ON COLUMN asp_complaint.object_type IS '组织/赛事/队伍/付款/资料';
COMMENT ON COLUMN asp_complaint.object_id IS '关联对象';
COMMENT ON COLUMN asp_complaint.request IS '诉求';
COMMENT ON COLUMN asp_complaint.evidence IS '最小披露证据；必须按版本校验结构';
COMMENT ON COLUMN asp_complaint.status IS '独立业务状态；合法值不等于业务已获批准：submitted accepted investigating resolved rejected appealed';
COMMENT ON COLUMN asp_complaint.owner_id IS '处理责任人';
COMMENT ON COLUMN asp_complaint.resolution IS '处理及告知；必须按版本校验结构';
COMMENT ON COLUMN asp_complaint.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_complaint.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_complaint.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_complaint.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_complaint.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_complaint.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D13: 个人资料查询、更正、撤回、注销及删除请求
CREATE TABLE asp_data_request (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    person_id bigint NOT NULL,
    request_type varchar(100) NOT NULL,
    scope jsonb NOT NULL,
    status varchar(32) NOT NULL,
    resolution jsonb,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (status IN ('submitted', 'verifying', 'approved', 'rejected', 'processing', 'completed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_data_request IS '个人资料查询、更正、撤回、注销及删除请求；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_data_request.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_data_request.account_id IS '请求人';
CREATE INDEX ix_asp_data_request_698240e2f8 ON asp_data_request (account_id);
COMMENT ON COLUMN asp_data_request.person_id IS '资料对象';
CREATE INDEX ix_asp_data_request_894abf225a ON asp_data_request (person_id);
COMMENT ON COLUMN asp_data_request.request_type IS '明确权利请求类型';
COMMENT ON COLUMN asp_data_request.scope IS '范围和授权；必须按版本校验结构';
COMMENT ON COLUMN asp_data_request.status IS '独立业务状态；合法值不等于业务已获批准：submitted verifying approved rejected processing completed';
COMMENT ON COLUMN asp_data_request.resolution IS '公开下架、必要留存及未完义务接续；必须按版本校验结构';
COMMENT ON COLUMN asp_data_request.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_data_request.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_data_request.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_data_request.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_data_request.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_data_request.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D13: 关键业务决定与资料访问审计；不写入原始敏感材料
CREATE TABLE asp_audit_event (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    actor_account_id bigint,
    action varchar(100) NOT NULL,
    object_type varchar(100) NOT NULL,
    object_id bigint,
    request_id varchar(128) NOT NULL,
    occurred_at timestamptz NOT NULL,
    summary jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_audit_event IS '关键业务决定与资料访问审计；不写入原始敏感材料；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_audit_event.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_audit_event.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_audit_event.actor_account_id IS '操作人';
CREATE INDEX ix_asp_audit_event_055aabf6fb ON asp_audit_event (actor_account_id);
COMMENT ON COLUMN asp_audit_event.action IS '业务或资料访问动作';
COMMENT ON COLUMN asp_audit_event.object_type IS '对象类型';
COMMENT ON COLUMN asp_audit_event.object_id IS '对象 ID';
COMMENT ON COLUMN asp_audit_event.request_id IS '调用追踪 ID';
COMMENT ON COLUMN asp_audit_event.occurred_at IS '发生时间；有时区业务时间';
COMMENT ON COLUMN asp_audit_event.summary IS '理由、版本及允许的最小变化摘要；必须按版本校验结构';
COMMENT ON COLUMN asp_audit_event.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_audit_event.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_audit_event.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_audit_event.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_audit_event.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_audit_event.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D13: 本地事务提交的跨模块通知/事件；消费必须幂等
CREATE TABLE asp_outbox (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    event_key varchar(128) NOT NULL,
    aggregate_type varchar(100) NOT NULL,
    aggregate_id bigint NOT NULL,
    aggregate_revision integer NOT NULL,
    event_type varchar(100) NOT NULL,
    payload jsonb NOT NULL,
    status varchar(32) NOT NULL,
    attempts integer NOT NULL,
    next_attempt_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (aggregate_revision >= 0),
    CHECK (status IN ('pending', 'processing', 'delivered', 'failed')),
    CHECK (attempts >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_outbox IS '本地事务提交的跨模块通知/事件；消费必须幂等；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_outbox.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_outbox.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_outbox.event_key IS '稳定事件去重 ID';
COMMENT ON COLUMN asp_outbox.aggregate_type IS '来源聚合';
COMMENT ON COLUMN asp_outbox.aggregate_id IS '来源 ID';
COMMENT ON COLUMN asp_outbox.aggregate_revision IS '来源业务版本';
COMMENT ON COLUMN asp_outbox.event_type IS '版本化事件名';
COMMENT ON COLUMN asp_outbox.payload IS '最小必要跨模块契约；必须按版本校验结构';
COMMENT ON COLUMN asp_outbox.status IS '独立业务状态；合法值不等于业务已获批准：pending processing delivered failed';
COMMENT ON COLUMN asp_outbox.attempts IS '尝试数';
COMMENT ON COLUMN asp_outbox.next_attempt_at IS '下次尝试；有时区业务时间';
COMMENT ON COLUMN asp_outbox.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_outbox.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_outbox.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_outbox.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_outbox.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_outbox.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_outbox_70dab87176 ON asp_outbox (tenant_id, event_key);

-- D13: 请求去重及不确定响应恢复；不得只靠页面按钮防重
CREATE TABLE asp_idempotency (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    account_id bigint NOT NULL,
    operation varchar(100) NOT NULL,
    request_key varchar(128) NOT NULL,
    payload_hash varchar(128) NOT NULL,
    status varchar(32) NOT NULL,
    result_reference jsonb,
    expires_at timestamptz NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('processing', 'completed', 'failed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_idempotency IS '请求去重及不确定响应恢复；不得只靠页面按钮防重；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_idempotency.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_idempotency.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_idempotency.account_id IS '调用者';
CREATE INDEX ix_asp_idempotency_362594cd27 ON asp_idempotency (account_id);
COMMENT ON COLUMN asp_idempotency.operation IS '动作';
COMMENT ON COLUMN asp_idempotency.request_key IS '客户端重试键';
COMMENT ON COLUMN asp_idempotency.payload_hash IS '输入摘要；同键不同输入拒绝';
COMMENT ON COLUMN asp_idempotency.status IS '独立业务状态；合法值不等于业务已获批准：processing completed failed';
COMMENT ON COLUMN asp_idempotency.result_reference IS '原业务结果引用；不存敏感完整响应；必须按版本校验结构';
COMMENT ON COLUMN asp_idempotency.expires_at IS '去重记录保留截止；有时区业务时间';
COMMENT ON COLUMN asp_idempotency.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_idempotency.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_idempotency.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_idempotency.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_idempotency.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_idempotency.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_idempotency_7a30f217c3 ON asp_idempotency (tenant_id, account_id, operation, request_key);

-- D13: 旧系统来源、授权及数量金额差异核对
CREATE TABLE asp_migration_batch (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    source_system varchar(100) NOT NULL,
    source_version varchar(100) NOT NULL,
    authorization_snapshot jsonb NOT NULL,
    reconciliation jsonb NOT NULL,
    status varchar(32) NOT NULL,
    cutover_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('importing', 'checking', 'verified', 'blocked', 'cutover', 'rolled_back')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_migration_batch IS '旧系统来源、授权及数量金额差异核对；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_migration_batch.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_migration_batch.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_migration_batch.source_system IS '来源系统';
COMMENT ON COLUMN asp_migration_batch.source_version IS '导出及切换版本';
COMMENT ON COLUMN asp_migration_batch.authorization_snapshot IS '迁移范围及接收责任；必须按版本校验结构';
COMMENT ON COLUMN asp_migration_batch.reconciliation IS '身份、名单、金额、退款、赛程及结果汇总；必须按版本校验结构';
COMMENT ON COLUMN asp_migration_batch.status IS '独立业务状态；合法值不等于业务已获批准：importing checking verified blocked cutover rolled_back';
COMMENT ON COLUMN asp_migration_batch.cutover_at IS '唯一生效切换时间；有时区业务时间';
COMMENT ON COLUMN asp_migration_batch.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_migration_batch.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_migration_batch.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_migration_batch.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_migration_batch.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_migration_batch.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D13: 旧新记录映射、差异及未完责任；不虚构调平
CREATE TABLE asp_migration_mapping (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    batch_id bigint NOT NULL,
    object_type varchar(100) NOT NULL,
    source_key varchar(200) NOT NULL,
    target_id bigint,
    status varchar(32) NOT NULL,
    difference jsonb,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('matched', 'missing', 'conflict', 'reconciled')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_migration_mapping IS '旧新记录映射、差异及未完责任；不虚构调平；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_migration_mapping.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_migration_mapping.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_migration_mapping.batch_id IS '迁移批次';
CREATE INDEX ix_asp_migration_mapping_c8d7b46161 ON asp_migration_mapping (tenant_id, batch_id);
COMMENT ON COLUMN asp_migration_mapping.object_type IS '业务对象类型';
COMMENT ON COLUMN asp_migration_mapping.source_key IS '旧系统稳定键';
COMMENT ON COLUMN asp_migration_mapping.target_id IS '新对象 ID';
COMMENT ON COLUMN asp_migration_mapping.status IS '独立业务状态；合法值不等于业务已获批准：matched missing conflict reconciled';
COMMENT ON COLUMN asp_migration_mapping.difference IS '来源、差异和处理人；必须按版本校验结构';
COMMENT ON COLUMN asp_migration_mapping.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_migration_mapping.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_migration_mapping.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_migration_mapping.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_migration_mapping.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_migration_mapping.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_migration_mapping_979f0926d3 ON asp_migration_mapping (tenant_id, batch_id, object_type, source_key);

-- Add foreign keys after all tables exist, including forward references.
ALTER TABLE asp_login_identity ADD CONSTRAINT fk_asp_login_identity_77f45262fd FOREIGN KEY (account_id) REFERENCES asp_account (id);
ALTER TABLE asp_person ADD CONSTRAINT fk_asp_person_ef99cce6fe FOREIGN KEY (merged_into_id) REFERENCES asp_person (id);
ALTER TABLE asp_account_person ADD CONSTRAINT fk_asp_account_person_1c703bbfe2 FOREIGN KEY (account_id) REFERENCES asp_account (id);
ALTER TABLE asp_account_person ADD CONSTRAINT fk_asp_account_person_0ff84bc509 FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_guardianship ADD CONSTRAINT fk_asp_guardianship_de9e84fc13 FOREIGN KEY (guardian_person_id) REFERENCES asp_person (id);
ALTER TABLE asp_guardianship ADD CONSTRAINT fk_asp_guardianship_8432f6051d FOREIGN KEY (child_person_id) REFERENCES asp_person (id);
ALTER TABLE asp_delegation ADD CONSTRAINT fk_asp_delegation_a535dd5844 FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_delegation ADD CONSTRAINT fk_asp_delegation_1e2c6e4501 FOREIGN KEY (operator_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_consent ADD CONSTRAINT fk_asp_consent_e38cc432c1 FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_consent ADD CONSTRAINT fk_asp_consent_68623c10a7 FOREIGN KEY (actor_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_qualification ADD CONSTRAINT fk_asp_qualification_9b8109903a FOREIGN KEY (tenant_id, organization_id) REFERENCES asp_organization (tenant_id, id);
ALTER TABLE asp_staff_grant ADD CONSTRAINT fk_asp_staff_grant_3d19349684 FOREIGN KEY (tenant_id, organization_id) REFERENCES asp_organization (tenant_id, id);
ALTER TABLE asp_staff_grant ADD CONSTRAINT fk_asp_staff_grant_f9a5b0f5e5 FOREIGN KEY (account_id) REFERENCES asp_account (id);
ALTER TABLE asp_collaboration ADD CONSTRAINT fk_asp_collaboration_5ba06833ac FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
ALTER TABLE asp_collaboration ADD CONSTRAINT fk_asp_collaboration_3d3e434d98 FOREIGN KEY (tenant_id, organization_id) REFERENCES asp_organization (tenant_id, id);
ALTER TABLE asp_team ADD CONSTRAINT fk_asp_team_f98848e1b8 FOREIGN KEY (sport_id) REFERENCES asp_sport (id);
ALTER TABLE asp_team ADD CONSTRAINT fk_asp_team_f026743fd0 FOREIGN KEY (captain_person_id) REFERENCES asp_person (id);
ALTER TABLE asp_team ADD CONSTRAINT fk_asp_team_620fab166c FOREIGN KEY (creator_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_team_member ADD CONSTRAINT fk_asp_team_member_7591d37c1e FOREIGN KEY (team_id) REFERENCES asp_team (id);
ALTER TABLE asp_team_member ADD CONSTRAINT fk_asp_team_member_b732ce61cb FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_team_join_request ADD CONSTRAINT fk_asp_team_join_request_af23f80eb0 FOREIGN KEY (team_id) REFERENCES asp_team (id);
ALTER TABLE asp_team_join_request ADD CONSTRAINT fk_asp_team_join_request_502a2f141d FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_team_join_request ADD CONSTRAINT fk_asp_team_join_request_47326fba24 FOREIGN KEY (reviewer_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_team_invitation ADD CONSTRAINT fk_asp_team_invitation_3aa2742054 FOREIGN KEY (team_id) REFERENCES asp_team (id);
ALTER TABLE asp_team_invitation ADD CONSTRAINT fk_asp_team_invitation_541edd1125 FOREIGN KEY (inviter_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_team_invitation ADD CONSTRAINT fk_asp_team_invitation_7d44d535b7 FOREIGN KEY (target_person_id) REFERENCES asp_person (id);
ALTER TABLE asp_team_history ADD CONSTRAINT fk_asp_team_history_912eca6b66 FOREIGN KEY (team_id) REFERENCES asp_team (id);
ALTER TABLE asp_team_quota ADD CONSTRAINT fk_asp_team_quota_3a6859e632 FOREIGN KEY (account_id) REFERENCES asp_account (id);
ALTER TABLE asp_event ADD CONSTRAINT fk_asp_event_ba1502a512 FOREIGN KEY (tenant_id, organization_id) REFERENCES asp_organization (tenant_id, id);
ALTER TABLE asp_event_revision ADD CONSTRAINT fk_asp_event_revision_f1ffb3e031 FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
ALTER TABLE asp_competition_unit ADD CONSTRAINT fk_asp_competition_unit_8535df1119 FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
ALTER TABLE asp_competition_unit ADD CONSTRAINT fk_asp_competition_unit_aa7f9ddb3b FOREIGN KEY (sport_id) REFERENCES asp_sport (id);
ALTER TABLE asp_rule_version ADD CONSTRAINT fk_asp_rule_version_47a590e281 FOREIGN KEY (tenant_id, unit_id) REFERENCES asp_competition_unit (tenant_id, id);
ALTER TABLE asp_material_requirement ADD CONSTRAINT fk_asp_material_requirement_e44238f2fd FOREIGN KEY (tenant_id, rule_version_id) REFERENCES asp_rule_version (tenant_id, id);
ALTER TABLE asp_fee_policy ADD CONSTRAINT fk_asp_fee_policy_a1c8078315 FOREIGN KEY (tenant_id, unit_id) REFERENCES asp_competition_unit (tenant_id, id);
ALTER TABLE asp_registration_batch ADD CONSTRAINT fk_asp_registration_batch_6523f9e051 FOREIGN KEY (submitter_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_registration ADD CONSTRAINT fk_asp_registration_217fd3d0fd FOREIGN KEY (tenant_id, unit_id) REFERENCES asp_competition_unit (tenant_id, id);
ALTER TABLE asp_registration ADD CONSTRAINT fk_asp_registration_f8b0175b47 FOREIGN KEY (tenant_id, rule_version_id) REFERENCES asp_rule_version (tenant_id, id);
ALTER TABLE asp_registration ADD CONSTRAINT fk_asp_registration_a0d5d3804d FOREIGN KEY (tenant_id, fee_policy_id) REFERENCES asp_fee_policy (tenant_id, id);
ALTER TABLE asp_registration ADD CONSTRAINT fk_asp_registration_c3c2a32d6f FOREIGN KEY (tenant_id, batch_id) REFERENCES asp_registration_batch (tenant_id, id);
ALTER TABLE asp_registration ADD CONSTRAINT fk_asp_registration_34a0daff97 FOREIGN KEY (team_id) REFERENCES asp_team (id);
ALTER TABLE asp_registration ADD CONSTRAINT fk_asp_registration_ee864d6727 FOREIGN KEY (submitter_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_registration ADD CONSTRAINT fk_asp_registration_bddadcf747 FOREIGN KEY (operator_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_roster_version ADD CONSTRAINT fk_asp_roster_version_945cc0a5de FOREIGN KEY (tenant_id, registration_id) REFERENCES asp_registration (tenant_id, id);
ALTER TABLE asp_roster_version ADD CONSTRAINT fk_asp_roster_version_8fd2ad298f FOREIGN KEY (tenant_id, rule_version_id) REFERENCES asp_rule_version (tenant_id, id);
ALTER TABLE asp_roster_member ADD CONSTRAINT fk_asp_roster_member_d30ecbbac1 FOREIGN KEY (tenant_id, roster_version_id) REFERENCES asp_roster_version (tenant_id, id);
ALTER TABLE asp_roster_member ADD CONSTRAINT fk_asp_roster_member_b94356d0b2 FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_qualification_review ADD CONSTRAINT fk_asp_qualification_review_babfdefa39 FOREIGN KEY (tenant_id, registration_id) REFERENCES asp_registration (tenant_id, id);
ALTER TABLE asp_qualification_review ADD CONSTRAINT fk_asp_qualification_review_77130e3af5 FOREIGN KEY (tenant_id, roster_member_id) REFERENCES asp_roster_member (tenant_id, id);
ALTER TABLE asp_capacity_pool ADD CONSTRAINT fk_asp_capacity_pool_94e0b99016 FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
ALTER TABLE asp_capacity_pool ADD CONSTRAINT fk_asp_capacity_pool_44fc872a06 FOREIGN KEY (tenant_id, unit_id) REFERENCES asp_competition_unit (tenant_id, id);
ALTER TABLE asp_capacity_occupation ADD CONSTRAINT fk_asp_capacity_occupation_b5f4c6ed4e FOREIGN KEY (tenant_id, pool_id) REFERENCES asp_capacity_pool (tenant_id, id);
ALTER TABLE asp_capacity_occupation ADD CONSTRAINT fk_asp_capacity_occupation_14434dcbb9 FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_occupation_reference ADD CONSTRAINT fk_asp_occupation_reference_82be73443c FOREIGN KEY (tenant_id, occupation_id) REFERENCES asp_capacity_occupation (tenant_id, id);
ALTER TABLE asp_occupation_reference ADD CONSTRAINT fk_asp_occupation_reference_1adb05c0a7 FOREIGN KEY (tenant_id, registration_id) REFERENCES asp_registration (tenant_id, id);
ALTER TABLE asp_waitlist ADD CONSTRAINT fk_asp_waitlist_7980fdb5d5 FOREIGN KEY (tenant_id, registration_id) REFERENCES asp_registration (tenant_id, id);
ALTER TABLE asp_waitlist ADD CONSTRAINT fk_asp_waitlist_41dba4146a FOREIGN KEY (tenant_id, pool_id) REFERENCES asp_capacity_pool (tenant_id, id);
ALTER TABLE asp_withdrawal ADD CONSTRAINT fk_asp_withdrawal_52d060aa3e FOREIGN KEY (tenant_id, registration_id) REFERENCES asp_registration (tenant_id, id);
ALTER TABLE asp_withdrawal ADD CONSTRAINT fk_asp_withdrawal_541124a5f2 FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_withdrawal ADD CONSTRAINT fk_asp_withdrawal_597f30ba70 FOREIGN KEY (applicant_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_fee_obligation ADD CONSTRAINT fk_asp_fee_obligation_a44fb80ed8 FOREIGN KEY (tenant_id, registration_id) REFERENCES asp_registration (tenant_id, id);
ALTER TABLE asp_fee_obligation ADD CONSTRAINT fk_asp_fee_obligation_381f50c2e6 FOREIGN KEY (tenant_id, fee_policy_id) REFERENCES asp_fee_policy (tenant_id, id);
ALTER TABLE asp_fee_item ADD CONSTRAINT fk_asp_fee_item_387b639c71 FOREIGN KEY (tenant_id, obligation_id) REFERENCES asp_fee_obligation (tenant_id, id);
ALTER TABLE asp_fee_item ADD CONSTRAINT fk_asp_fee_item_c65d43fdbc FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_fee_share ADD CONSTRAINT fk_asp_fee_share_a56fd0817d FOREIGN KEY (tenant_id, obligation_id) REFERENCES asp_fee_obligation (tenant_id, id);
ALTER TABLE asp_fee_share ADD CONSTRAINT fk_asp_fee_share_957a7049ae FOREIGN KEY (account_id) REFERENCES asp_account (id);
ALTER TABLE asp_fee_share ADD CONSTRAINT fk_asp_fee_share_b0b119e510 FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_payment ADD CONSTRAINT fk_asp_payment_4dcd39863b FOREIGN KEY (payer_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_payment_allocation ADD CONSTRAINT fk_asp_payment_allocation_edb278edfd FOREIGN KEY (tenant_id, payment_id) REFERENCES asp_payment (tenant_id, id);
ALTER TABLE asp_payment_allocation ADD CONSTRAINT fk_asp_payment_allocation_fc85422adc FOREIGN KEY (tenant_id, obligation_id) REFERENCES asp_fee_obligation (tenant_id, id);
ALTER TABLE asp_payment_allocation ADD CONSTRAINT fk_asp_payment_allocation_f2b19b68bb FOREIGN KEY (tenant_id, share_id) REFERENCES asp_fee_share (tenant_id, id);
ALTER TABLE asp_payment_exception ADD CONSTRAINT fk_asp_payment_exception_b2f12c109c FOREIGN KEY (tenant_id, payment_id) REFERENCES asp_payment (tenant_id, id);
ALTER TABLE asp_refund ADD CONSTRAINT fk_asp_refund_6c91a131df FOREIGN KEY (tenant_id, payment_id) REFERENCES asp_payment (tenant_id, id);
ALTER TABLE asp_refund ADD CONSTRAINT fk_asp_refund_4119153df3 FOREIGN KEY (tenant_id, allocation_id) REFERENCES asp_payment_allocation (tenant_id, id);
ALTER TABLE asp_refund ADD CONSTRAINT fk_asp_refund_0889c78c72 FOREIGN KEY (tenant_id, withdrawal_id) REFERENCES asp_withdrawal (tenant_id, id);
ALTER TABLE asp_refund ADD CONSTRAINT fk_asp_refund_9796403cc4 FOREIGN KEY (applicant_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_service_fee ADD CONSTRAINT fk_asp_service_fee_8b6014c1b8 FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
ALTER TABLE asp_settlement ADD CONSTRAINT fk_asp_settlement_9a2dc30a01 FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
ALTER TABLE asp_resource ADD CONSTRAINT fk_asp_resource_d336122926 FOREIGN KEY (tenant_id, venue_id) REFERENCES asp_venue (tenant_id, id);
ALTER TABLE asp_resource ADD CONSTRAINT fk_asp_resource_20d7e5a093 FOREIGN KEY (tenant_id, parent_id) REFERENCES asp_resource (tenant_id, id);
ALTER TABLE asp_resource_reservation ADD CONSTRAINT fk_asp_resource_reservation_d78872c2b3 FOREIGN KEY (tenant_id, resource_id) REFERENCES asp_resource (tenant_id, id);
ALTER TABLE asp_resource_reservation ADD CONSTRAINT fk_asp_resource_reservation_70bea28f7e FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
ALTER TABLE asp_time_constraint ADD CONSTRAINT fk_asp_time_constraint_a8964e349e FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_time_constraint ADD CONSTRAINT fk_asp_time_constraint_2071901409 FOREIGN KEY (parent_id) REFERENCES asp_time_constraint (id);
ALTER TABLE asp_stage ADD CONSTRAINT fk_asp_stage_85fc908ca2 FOREIGN KEY (tenant_id, unit_id) REFERENCES asp_competition_unit (tenant_id, id);
ALTER TABLE asp_stage ADD CONSTRAINT fk_asp_stage_f9269c0082 FOREIGN KEY (tenant_id, rule_version_id) REFERENCES asp_rule_version (tenant_id, id);
ALTER TABLE asp_draw_run ADD CONSTRAINT fk_asp_draw_run_fceb0110bb FOREIGN KEY (tenant_id, stage_id) REFERENCES asp_stage (tenant_id, id);
ALTER TABLE asp_draw_run ADD CONSTRAINT fk_asp_draw_run_be023de228 FOREIGN KEY (tenant_id, rule_version_id) REFERENCES asp_rule_version (tenant_id, id);
ALTER TABLE asp_schedule_run ADD CONSTRAINT fk_asp_schedule_run_de3cc075fb FOREIGN KEY (tenant_id, stage_id) REFERENCES asp_stage (tenant_id, id);
ALTER TABLE asp_schedule_run ADD CONSTRAINT fk_asp_schedule_run_c24d09d900 FOREIGN KEY (tenant_id, draw_run_id) REFERENCES asp_draw_run (tenant_id, id);
ALTER TABLE asp_match ADD CONSTRAINT fk_asp_match_c2cf93ae06 FOREIGN KEY (tenant_id, stage_id) REFERENCES asp_stage (tenant_id, id);
ALTER TABLE asp_match ADD CONSTRAINT fk_asp_match_8f34176002 FOREIGN KEY (tenant_id, schedule_run_id) REFERENCES asp_schedule_run (tenant_id, id);
ALTER TABLE asp_match ADD CONSTRAINT fk_asp_match_4b3dd35375 FOREIGN KEY (tenant_id, resource_id) REFERENCES asp_resource (tenant_id, id);
ALTER TABLE asp_match_entry ADD CONSTRAINT fk_asp_match_entry_8fa587a58f FOREIGN KEY (tenant_id, match_id) REFERENCES asp_match (tenant_id, id);
ALTER TABLE asp_match_entry ADD CONSTRAINT fk_asp_match_entry_ab5db3318d FOREIGN KEY (tenant_id, registration_id) REFERENCES asp_registration (tenant_id, id);
ALTER TABLE asp_match_entry ADD CONSTRAINT fk_asp_match_entry_4907f195db FOREIGN KEY (tenant_id, roster_version_id) REFERENCES asp_roster_version (tenant_id, id);
ALTER TABLE asp_lineup_member ADD CONSTRAINT fk_asp_lineup_member_a761239472 FOREIGN KEY (tenant_id, match_entry_id) REFERENCES asp_match_entry (tenant_id, id);
ALTER TABLE asp_lineup_member ADD CONSTRAINT fk_asp_lineup_member_0f3cbbbe80 FOREIGN KEY (tenant_id, roster_member_id) REFERENCES asp_roster_member (tenant_id, id);
ALTER TABLE asp_checkin ADD CONSTRAINT fk_asp_checkin_3cc20a9a3e FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
ALTER TABLE asp_checkin ADD CONSTRAINT fk_asp_checkin_446f2cc796 FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_checkin ADD CONSTRAINT fk_asp_checkin_3e9e71d86e FOREIGN KEY (tenant_id, match_id) REFERENCES asp_match (tenant_id, id);
ALTER TABLE asp_official_assignment ADD CONSTRAINT fk_asp_official_assignment_7b513d632e FOREIGN KEY (tenant_id, match_id) REFERENCES asp_match (tenant_id, id);
ALTER TABLE asp_official_assignment ADD CONSTRAINT fk_asp_official_assignment_41dc7655f6 FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_result_version ADD CONSTRAINT fk_asp_result_version_1c5bad7d2e FOREIGN KEY (tenant_id, match_id) REFERENCES asp_match (tenant_id, id);
ALTER TABLE asp_result_version ADD CONSTRAINT fk_asp_result_version_01a3014925 FOREIGN KEY (tenant_id, previous_id) REFERENCES asp_result_version (tenant_id, id);
ALTER TABLE asp_result_item ADD CONSTRAINT fk_asp_result_item_2f40c34f6f FOREIGN KEY (tenant_id, result_version_id) REFERENCES asp_result_version (tenant_id, id);
ALTER TABLE asp_result_item ADD CONSTRAINT fk_asp_result_item_9a5d685503 FOREIGN KEY (tenant_id, match_entry_id) REFERENCES asp_match_entry (tenant_id, id);
ALTER TABLE asp_advancement ADD CONSTRAINT fk_asp_advancement_e6fdd62047 FOREIGN KEY (tenant_id, result_version_id) REFERENCES asp_result_version (tenant_id, id);
ALTER TABLE asp_advancement ADD CONSTRAINT fk_asp_advancement_8de3a730b7 FOREIGN KEY (tenant_id, registration_id) REFERENCES asp_registration (tenant_id, id);
ALTER TABLE asp_advancement ADD CONSTRAINT fk_asp_advancement_f36c110b02 FOREIGN KEY (tenant_id, target_stage_id) REFERENCES asp_stage (tenant_id, id);
ALTER TABLE asp_ranking_run ADD CONSTRAINT fk_asp_ranking_run_82944954dd FOREIGN KEY (tenant_id, unit_id) REFERENCES asp_competition_unit (tenant_id, id);
ALTER TABLE asp_ranking_run ADD CONSTRAINT fk_asp_ranking_run_707f86d252 FOREIGN KEY (tenant_id, rule_version_id) REFERENCES asp_rule_version (tenant_id, id);
ALTER TABLE asp_ranking_item ADD CONSTRAINT fk_asp_ranking_item_bd98d8edf2 FOREIGN KEY (tenant_id, ranking_run_id) REFERENCES asp_ranking_run (tenant_id, id);
ALTER TABLE asp_ranking_item ADD CONSTRAINT fk_asp_ranking_item_44d2543cf1 FOREIGN KEY (tenant_id, registration_id) REFERENCES asp_registration (tenant_id, id);
ALTER TABLE asp_appeal ADD CONSTRAINT fk_asp_appeal_11fff99669 FOREIGN KEY (tenant_id, match_id) REFERENCES asp_match (tenant_id, id);
ALTER TABLE asp_appeal ADD CONSTRAINT fk_asp_appeal_5b2c3f012c FOREIGN KEY (tenant_id, registration_id) REFERENCES asp_registration (tenant_id, id);
ALTER TABLE asp_appeal ADD CONSTRAINT fk_asp_appeal_31cfd37310 FOREIGN KEY (applicant_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_appeal ADD CONSTRAINT fk_asp_appeal_c2f5a9575f FOREIGN KEY (tenant_id, result_version_id) REFERENCES asp_result_version (tenant_id, id);
ALTER TABLE asp_honor ADD CONSTRAINT fk_asp_honor_21af8d4817 FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
ALTER TABLE asp_honor ADD CONSTRAINT fk_asp_honor_619408751b FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_honor ADD CONSTRAINT fk_asp_honor_8b978dd3d7 FOREIGN KEY (team_id) REFERENCES asp_team (id);
ALTER TABLE asp_growth_record ADD CONSTRAINT fk_asp_growth_record_b8e456a801 FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_growth_record ADD CONSTRAINT fk_asp_growth_record_8fb8a219a7 FOREIGN KEY (team_id) REFERENCES asp_team (id);
ALTER TABLE asp_notification ADD CONSTRAINT fk_asp_notification_54506f0b85 FOREIGN KEY (recipient_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_notification_delivery ADD CONSTRAINT fk_asp_notification_delivery_4d1557bb10 FOREIGN KEY (tenant_id, notification_id) REFERENCES asp_notification (tenant_id, id);
ALTER TABLE asp_file ADD CONSTRAINT fk_asp_file_71cbb06677 FOREIGN KEY (owner_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_material_submission ADD CONSTRAINT fk_asp_material_submission_e06913ebbf FOREIGN KEY (tenant_id, registration_id) REFERENCES asp_registration (tenant_id, id);
ALTER TABLE asp_material_submission ADD CONSTRAINT fk_asp_material_submission_2247bbd71d FOREIGN KEY (tenant_id, roster_member_id) REFERENCES asp_roster_member (tenant_id, id);
ALTER TABLE asp_material_submission ADD CONSTRAINT fk_asp_material_submission_2c753b4f5d FOREIGN KEY (tenant_id, requirement_id) REFERENCES asp_material_requirement (tenant_id, id);
ALTER TABLE asp_material_submission ADD CONSTRAINT fk_asp_material_submission_ec40f1fb3b FOREIGN KEY (file_id) REFERENCES asp_file (id);
ALTER TABLE asp_complaint ADD CONSTRAINT fk_asp_complaint_143ba948f2 FOREIGN KEY (applicant_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_data_request ADD CONSTRAINT fk_asp_data_request_698240e2f8 FOREIGN KEY (account_id) REFERENCES asp_account (id);
ALTER TABLE asp_data_request ADD CONSTRAINT fk_asp_data_request_894abf225a FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_audit_event ADD CONSTRAINT fk_asp_audit_event_055aabf6fb FOREIGN KEY (actor_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_idempotency ADD CONSTRAINT fk_asp_idempotency_362594cd27 FOREIGN KEY (account_id) REFERENCES asp_account (id);
ALTER TABLE asp_migration_mapping ADD CONSTRAINT fk_asp_migration_mapping_c8d7b46161 FOREIGN KEY (tenant_id, batch_id) REFERENCES asp_migration_batch (tenant_id, id);

COMMIT;
