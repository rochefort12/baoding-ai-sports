-- GENERATED from database/model/catalog.py. Do not hand edit.
-- Current model, not the applied baseline. Ship structure changes as a new migration after review.
-- PostgreSQL 17; bigint IDs supplied by application; NO cascading deletes.
BEGIN;
SET LOCAL TIME ZONE 'Asia/Shanghai';

-- D02: 平台账号。一名自然人一份。参赛档案可选。登录号使用本表主键，不把后台用户当成平台身份
CREATE TABLE asp_account (
    id bigint NOT NULL,
    display_name varchar(100) NOT NULL,
    password_hash varchar(100),
    backend_user_id bigint,
    person_id bigint,
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
COMMENT ON TABLE asp_account IS '平台账号。一名自然人一份。参赛档案可选。登录号使用本表主键，不把后台用户当成平台身份；来源：母版 D02；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_account.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_account.display_name IS '登录账号展示名';
COMMENT ON COLUMN asp_account.password_hash IS '登录密码散列。只供平台登录校验，不写入日志';
COMMENT ON COLUMN asp_account.backend_user_id IS '遗留的后台 sys_user。当前注册仍写入，平台登录不使用它判断身份';
COMMENT ON COLUMN asp_account.person_id IS '本人参赛档案；空表示尚未建档';
CREATE INDEX ix_asp_account_39cbbedbdb ON asp_account (person_id);
COMMENT ON COLUMN asp_account.status IS '独立业务状态；合法值不等于业务已获批准：active restricted recovery closing closed';
COMMENT ON COLUMN asp_account.closed_at IS '账号服务停止时间；有时区业务时间';
COMMENT ON COLUMN asp_account.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_account.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_account.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_account.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_account.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_account.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_account_557a4bff7a ON asp_account (backend_user_id) WHERE backend_user_id IS NOT NULL;
CREATE UNIQUE INDEX uq_asp_account_59cbd13cbc ON asp_account (person_id) WHERE person_id IS NOT NULL;

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

-- D02: 一名独立参赛者的稳定档案；同名不合并，资料更正不改写报名快照。通用联系和体貌资料在本表，不进赛事属性目录
CREATE TABLE asp_person (
    id bigint NOT NULL,
    legal_name varchar(100) NOT NULL,
    display_name varchar(100),
    birth_date date NOT NULL,
    gender varchar(32) NOT NULL,
    mobile varchar(20) NOT NULL,
    id_doc_type varchar(32),
    identity_hash varchar(128),
    identity_cipher varchar(1000),
    city varchar(100),
    address_detail varchar(200),
    blood_type varchar(32),
    clothing_size varchar(32),
    emergency_contact_name varchar(100),
    emergency_contact_phone varchar(20),
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
    CHECK (mobile ~ '^1[3-9][0-9]{9}$'),
    CHECK ((id_doc_type IS NULL) = (identity_hash IS NULL)),
    CHECK ((identity_hash IS NULL) = (identity_cipher IS NULL)),
    CHECK (emergency_contact_phone IS NULL OR emergency_contact_phone ~ '^1[3-9][0-9]{9}$'),
    CHECK (gender IN ('male', 'female', 'other')),
    CHECK (id_doc_type IS NULL OR id_doc_type IN ('id_card', 'passport', 'hmt_pass', 'other')),
    CHECK (blood_type IS NULL OR blood_type IN ('A', 'B', 'AB', 'O', 'unknown')),
    CHECK (clothing_size IS NULL OR clothing_size IN ('XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL')),
    CHECK (verification_status IN ('unverified', 'pending', 'verified', 'disputed')),
    CHECK (status IN ('active', 'restricted', 'merged', 'archived')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_person IS '一名独立参赛者的稳定档案；同名不合并，资料更正不改写报名快照。通用联系和体貌资料在本表，不进赛事属性目录；来源：母版 D02；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_person.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_person.legal_name IS '真实姓名；必填';
COMMENT ON COLUMN asp_person.display_name IS '活动展示名；空则对外使用真实姓名';
COMMENT ON COLUMN asp_person.birth_date IS '出生日期；必填。年龄按赛事自己的基准日判断';
COMMENT ON COLUMN asp_person.gender IS '分组用性别；必填：male female other';
COMMENT ON COLUMN asp_person.mobile IS '联系手机；必填，公开页不展示。当前因手机号注册尚未回填而手填。后续只回显注册时验证过的手机号，不能改成其他号码';
COMMENT ON COLUMN asp_person.id_doc_type IS '证件类型：id_card passport hmt_pass other；可空';
COMMENT ON COLUMN asp_person.identity_hash IS '证件号码带密钥摘要；一个有效证件只对应一份档案。未填证件时为空';
COMMENT ON COLUMN asp_person.identity_cipher IS '证件号码加密值；不作为公开编号。未填证件时为空';
COMMENT ON COLUMN asp_person.city IS '所在城市；通用资料，可空';
COMMENT ON COLUMN asp_person.address_detail IS '详细地址；通用资料，可空';
COMMENT ON COLUMN asp_person.blood_type IS '血型：A B AB O unknown；通用资料，可空，不公开';
COMMENT ON COLUMN asp_person.clothing_size IS '衣服尺码：XS S M L XL XXL XXXL；通用资料，可空';
COMMENT ON COLUMN asp_person.emergency_contact_name IS '紧急联系人；通用资料，可空';
COMMENT ON COLUMN asp_person.emergency_contact_phone IS '紧急联系号码；通用资料，可空，不公开';
COMMENT ON COLUMN asp_person.verification_status IS '独立业务状态；合法值不等于业务已获批准：unverified pending verified disputed';
COMMENT ON COLUMN asp_person.status IS '独立业务状态；合法值不等于业务已获批准：active restricted merged archived';
COMMENT ON COLUMN asp_person.merged_into_id IS '经平台核对后的合并目标；参赛者不能自行合并';
CREATE INDEX ix_asp_person_ef99cce6fe ON asp_person (merged_into_id);
COMMENT ON COLUMN asp_person.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_person.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_person.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_person.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_person.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_person.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_person_5d15eceeb3 ON asp_person (identity_hash) WHERE status = 'active' AND identity_hash IS NOT NULL;

-- D02: 跨项目参赛属性目录；新项目增加目录项，不改参赛人表结构
CREATE TABLE asp_attribute_definition (
    id bigint NOT NULL,
    code varchar(100) NOT NULL,
    name varchar(100) NOT NULL,
    value_type varchar(32) NOT NULL,
    unit varchar(32),
    sensitivity varchar(32) NOT NULL,
    storage_scope varchar(32) NOT NULL,
    sport_id bigint,
    enum_options jsonb,
    status varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (value_type IN ('text', 'number', 'date', 'enum')),
    CHECK (sensitivity IN ('ordinary', 'identity', 'health')),
    CHECK (storage_scope IN ('profile', 'entry')),
    CHECK (status IN ('active', 'disabled')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_attribute_definition IS '跨项目参赛属性目录；新项目增加目录项，不改参赛人表结构；来源：母版 D02；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_attribute_definition.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_attribute_definition.code IS '稳定编码；一经参赛使用不改含义';
COMMENT ON COLUMN asp_attribute_definition.name IS '展示名称';
COMMENT ON COLUMN asp_attribute_definition.value_type IS '取值类型：text number date enum';
COMMENT ON COLUMN asp_attribute_definition.unit IS '数值单位；文本和日期可空';
COMMENT ON COLUMN asp_attribute_definition.sensitivity IS '可见范围：ordinary identity health';
COMMENT ON COLUMN asp_attribute_definition.storage_scope IS 'profile 可复用到个人档案；entry 只在当次报名采集：profile entry';
COMMENT ON COLUMN asp_attribute_definition.sport_id IS '建议适用的运动；空表示任何运动都可选用';
CREATE INDEX ix_asp_attribute_definition_914b0984d9 ON asp_attribute_definition (sport_id);
COMMENT ON COLUMN asp_attribute_definition.enum_options IS '枚举可选项及版本；非枚举为空；必须按版本校验结构';
COMMENT ON COLUMN asp_attribute_definition.status IS '独立业务状态；合法值不等于业务已获批准：active disabled';
COMMENT ON COLUMN asp_attribute_definition.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_attribute_definition.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_attribute_definition.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_attribute_definition.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_attribute_definition.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_attribute_definition.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_attribute_definition_236e380b15 ON asp_attribute_definition (code);

-- D02: 参赛者已保存的可复用属性；只接受目录中 storage_scope 为 profile 的项
CREATE TABLE asp_person_attribute (
    id bigint NOT NULL,
    person_id bigint NOT NULL,
    attribute_id bigint NOT NULL,
    value jsonb NOT NULL,
    measured_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_person_attribute IS '参赛者已保存的可复用属性；只接受目录中 storage_scope 为 profile 的项；来源：母版 D02；应用拒绝把 storage_scope=entry 的属性写入个人档案；报名使用名单快照，不回写本表。';
COMMENT ON COLUMN asp_person_attribute.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_person_attribute.person_id IS '本人档案';
CREATE INDEX ix_asp_person_attribute_ba773cd5eb ON asp_person_attribute (person_id);
COMMENT ON COLUMN asp_person_attribute.attribute_id IS '属性目录项';
CREATE INDEX ix_asp_person_attribute_e66e4d63bd ON asp_person_attribute (attribute_id);
COMMENT ON COLUMN asp_person_attribute.value IS '按值类型校验后的取值；必须按版本校验结构';
COMMENT ON COLUMN asp_person_attribute.measured_at IS '测量或声明时间；体重等会变化的属性使用；有时区业务时间';
COMMENT ON COLUMN asp_person_attribute.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_person_attribute.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_person_attribute.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_person_attribute.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_person_attribute.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_person_attribute.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_person_attribute_52d1b032a0 ON asp_person_attribute (person_id, attribute_id);

-- D02: 本人对具体用途的告知确认；保存档案和以后的报名材料分别记录
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
COMMENT ON TABLE asp_consent IS '本人对具体用途的告知确认；保存档案和以后的报名材料分别记录；来源：母版 D02；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_consent.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_consent.person_id IS '本人参赛人';
CREATE INDEX ix_asp_consent_e38cc432c1 ON asp_consent (person_id);
COMMENT ON COLUMN asp_consent.actor_account_id IS '作出确认的本人账号';
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

-- D01: 承办责任主体与租户映射。本期只在办赛申请通过后创建
CREATE TABLE asp_organization (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    name varchar(200) NOT NULL,
    subject_type varchar(100),
    subject_hash varchar(128),
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
COMMENT ON TABLE asp_organization IS '承办责任主体与租户映射。本期只在办赛申请通过后创建；来源：母版 D01；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_organization.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_organization.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_organization.name IS '主体名称';
COMMENT ON COLUMN asp_organization.subject_type IS '企业/学校/协会/俱乐部等。本期办赛申请不采集，可空';
COMMENT ON COLUMN asp_organization.subject_hash IS '主体标识受控摘要。空摘要不互相占用';
COMMENT ON COLUMN asp_organization.status IS '独立业务状态；合法值不等于业务已获批准：draft pending correction certified expired restricted';
COMMENT ON COLUMN asp_organization.contact_cipher IS '必要联系资料加密值';
COMMENT ON COLUMN asp_organization.current_qualification_id IS '当前适用资质版本；服务核验归属';
COMMENT ON COLUMN asp_organization.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_organization.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_organization.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_organization.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_organization.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_organization.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_organization_8a2fba9ad2 ON asp_organization (tenant_id, subject_hash) WHERE subject_hash IS NOT NULL;

-- D01: 办赛申请。平台级数据，没有业务租户。审核只决定是否开放办赛，不表示主体已验真
CREATE TABLE asp_organization_application (
    id bigint NOT NULL,
    applicant_account_id bigint NOT NULL,
    status varchar(32) NOT NULL,
    name varchar(200),
    contact_name varchar(100),
    contact_cipher varchar(1000),
    statement varchar(1000),
    file_ids jsonb,
    organization_id bigint,
    organization_tenant_id varchar(20),
    assigned_reviewer_id bigint,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (organization_tenant_id IS NULL OR length(organization_tenant_id) > 0),
    CHECK (status <> 'approved' OR (organization_id IS NOT NULL AND organization_tenant_id IS NOT NULL)),
    CHECK (status IN ('draft', 'pending', 'approved', 'rejected')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_organization_application IS '办赛申请。平台级数据，没有业务租户。审核只决定是否开放办赛，不表示主体已验真；来源：母版 D01；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_organization_application.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_organization_application.applicant_account_id IS '申请人。本期一人一份';
CREATE INDEX ix_asp_organization_application_9b40cddf36 ON asp_organization_application (applicant_account_id);
COMMENT ON COLUMN asp_organization_application.status IS '独立业务状态；合法值不等于业务已获批准：draft pending approved rejected';
COMMENT ON COLUMN asp_organization_application.name IS '组织名称。草稿可空，提交必填';
COMMENT ON COLUMN asp_organization_application.contact_name IS '联系人。可以和登录用户不同。草稿可空，提交必填';
COMMENT ON COLUMN asp_organization_application.contact_cipher IS '联系方式加密值。不要求是手机号，不发送短信';
COMMENT ON COLUMN asp_organization_application.statement IS '申请说明';
COMMENT ON COLUMN asp_organization_application.file_ids IS '当前稿附件编号。结构为 fileIds 数组。更换附件不删除旧文件；必须按版本校验结构';
COMMENT ON COLUMN asp_organization_application.organization_id IS '通过后写入的组织编号。组织属于租户，这里不建外键';
COMMENT ON COLUMN asp_organization_application.organization_tenant_id IS '通过后的组织租户编号';
COMMENT ON COLUMN asp_organization_application.assigned_reviewer_id IS '指定政府审核经办人；普通岗位只能处理明确分配给本人的申请';
COMMENT ON COLUMN asp_organization_application.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_organization_application.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_organization_application.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_organization_application.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_organization_application.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_organization_application.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_organization_application_9b40cddf36 ON asp_organization_application (applicant_account_id);

-- D01: 办赛申请每次提交时冻结的内容和附件。拒绝后的旧版不改
CREATE TABLE asp_organization_application_version (
    id bigint NOT NULL,
    application_id bigint NOT NULL,
    revision integer NOT NULL,
    name varchar(200) NOT NULL,
    contact_name varchar(100) NOT NULL,
    contact_cipher varchar(1000) NOT NULL,
    statement varchar(1000),
    file_ids jsonb NOT NULL,
    status varchar(32) NOT NULL,
    reviewer_id bigint,
    review_reason varchar(1000),
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (revision > 0),
    CHECK (revision >= 0),
    CHECK (status IN ('pending', 'approved', 'rejected')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_organization_application_version IS '办赛申请每次提交时冻结的内容和附件。拒绝后的旧版不改；来源：母版 D01；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_organization_application_version.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_organization_application_version.application_id IS '申请';
CREATE INDEX ix_asp_organization_application_version_56a5b63ed9 ON asp_organization_application_version (application_id);
COMMENT ON COLUMN asp_organization_application_version.revision IS '从 1 开始的提交版本';
COMMENT ON COLUMN asp_organization_application_version.name IS '该版组织名称';
COMMENT ON COLUMN asp_organization_application_version.contact_name IS '该版联系人';
COMMENT ON COLUMN asp_organization_application_version.contact_cipher IS '该版联系方式加密值';
COMMENT ON COLUMN asp_organization_application_version.statement IS '该版申请说明';
COMMENT ON COLUMN asp_organization_application_version.file_ids IS '该版附件编号。结构为 fileIds 数组；必须按版本校验结构';
COMMENT ON COLUMN asp_organization_application_version.status IS '独立业务状态；合法值不等于业务已获批准：pending approved rejected';
COMMENT ON COLUMN asp_organization_application_version.reviewer_id IS '审核人后台用户编号。只有超级管理员';
COMMENT ON COLUMN asp_organization_application_version.review_reason IS '拒绝理由。通过时可空';
COMMENT ON COLUMN asp_organization_application_version.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_organization_application_version.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_organization_application_version.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_organization_application_version.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_organization_application_version.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_organization_application_version.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_organization_application_version_5c7aaefaa6 ON asp_organization_application_version (application_id, revision);

-- D01: 平台账号在一个租户里的若依用户映射。映射存在不等于可以进入组织
CREATE TABLE asp_account_tenant_principal (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    sys_user_id bigint NOT NULL,
    status varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('active', 'revoked')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_account_tenant_principal IS '平台账号在一个租户里的若依用户映射。映射存在不等于可以进入组织；来源：母版 D01；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_account_tenant_principal.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_account_tenant_principal.account_id IS '平台账号';
CREATE INDEX ix_asp_account_tenant_principal_9b72fe7744 ON asp_account_tenant_principal (account_id);
COMMENT ON COLUMN asp_account_tenant_principal.tenant_id IS '组织租户编号。由服务写入和查询，不作为租户拦截条件';
COMMENT ON COLUMN asp_account_tenant_principal.sys_user_id IS '该租户内的若依用户。不是平台自然人';
COMMENT ON COLUMN asp_account_tenant_principal.status IS '独立业务状态；合法值不等于业务已获批准：active revoked';
COMMENT ON COLUMN asp_account_tenant_principal.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_account_tenant_principal.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_account_tenant_principal.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_account_tenant_principal.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_account_tenant_principal.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_account_tenant_principal.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_account_tenant_principal_a7d31f54f9 ON asp_account_tenant_principal (account_id, tenant_id);
CREATE UNIQUE INDEX uq_asp_account_tenant_principal_dc518270da ON asp_account_tenant_principal (sys_user_id);

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

-- D03: 长期项目队伍。一期只有有效和解散，解散后不恢复，不归属组织
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
    CHECK (join_policy IN ('open', 'application', 'invitation', 'closed')),
    CHECK (visibility IN ('private', 'members', 'public')),
    CHECK (status IN ('active', 'disbanded')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_team IS '长期项目队伍。一期只有有效和解散，解散后不恢复，不归属组织；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_team.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_team.name IS '当前队名。已提交报名使用自己的队名快照';
COMMENT ON COLUMN asp_team.sport_id IS '项目。一期创建时写入羽毛球，之后不改';
CREATE INDEX ix_asp_team_f98848e1b8 ON asp_team (sport_id);
COMMENT ON COLUMN asp_team.captain_person_id IS '当前队长档案。解散后保留最后一任，有效队伍还必须有一条有效队长成员';
CREATE INDEX ix_asp_team_f026743fd0 ON asp_team (captain_person_id);
COMMENT ON COLUMN asp_team.creator_account_id IS '创建人。不代表当前能否代表队伍报名';
CREATE INDEX ix_asp_team_620fab166c ON asp_team (creator_account_id);
COMMENT ON COLUMN asp_team.join_policy IS '一期创建写 open。申请和邀请同时开放，服务不按这列分支：open application invitation closed';
COMMENT ON COLUMN asp_team.visibility IS '一期创建写 members。不做队伍广场，服务不按这列分支：private members public';
COMMENT ON COLUMN asp_team.status IS '独立业务状态；合法值不等于业务已获批准：active disbanded';
COMMENT ON COLUMN asp_team.region IS '活动区域。一期页面不维护';
COMMENT ON COLUMN asp_team.profile IS '非敏感展示资料。一期页面不维护；必须按版本校验结构';
COMMENT ON COLUMN asp_team.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_team.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_team.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_team.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_team.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_team.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D03: 队伍成员的一段关系。结束后不重新激活，再次加入另起一行
CREATE TABLE asp_team_member (
    id bigint NOT NULL,
    team_id bigint NOT NULL,
    person_id bigint NOT NULL,
    role varchar(32) NOT NULL,
    status varchar(32) NOT NULL,
    end_reason varchar(32),
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
    CHECK ((status = 'active' AND left_at IS NULL AND end_reason IS NULL) OR (status = 'ended' AND left_at IS NOT NULL AND end_reason IS NOT NULL)),
    CHECK (role IN ('captain', 'member')),
    CHECK (status IN ('active', 'ended')),
    CHECK (end_reason IS NULL OR end_reason IN ('member_left', 'captain_removed', 'team_disbanded')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_team_member IS '队伍成员的一段关系。结束后不重新激活，再次加入另起一行；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_team_member.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_team_member.team_id IS '长期队伍';
CREATE INDEX ix_asp_team_member_7591d37c1e ON asp_team_member (team_id);
COMMENT ON COLUMN asp_team_member.person_id IS '现实成员';
CREATE INDEX ix_asp_team_member_b732ce61cb ON asp_team_member (person_id);
COMMENT ON COLUMN asp_team_member.role IS '独立业务状态；合法值不等于业务已获批准：captain member';
COMMENT ON COLUMN asp_team_member.status IS '独立业务状态；合法值不等于业务已获批准：active ended';
COMMENT ON COLUMN asp_team_member.end_reason IS '结束原因。有效成员必须为空：member_left captain_removed team_disbanded';
COMMENT ON COLUMN asp_team_member.join_source IS 'create、application 或 invitation';
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

-- D03: 入队申请。待处理不是成员，失效不能记成申请人撤销或队长拒绝
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
    CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled', 'invalidated')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_team_join_request IS '入队申请。待处理不是成员，失效不能记成申请人撤销或队长拒绝；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_team_join_request.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_team_join_request.team_id IS '申请队伍';
CREATE INDEX ix_asp_team_join_request_af23f80eb0 ON asp_team_join_request (team_id);
COMMENT ON COLUMN asp_team_join_request.person_id IS '申请者';
CREATE INDEX ix_asp_team_join_request_502a2f141d ON asp_team_join_request (person_id);
COMMENT ON COLUMN asp_team_join_request.status IS '独立业务状态；合法值不等于业务已获批准：pending approved rejected cancelled invalidated';
COMMENT ON COLUMN asp_team_join_request.reviewer_account_id IS '处理人。申请人撤销和系统失效时为空';
CREATE INDEX ix_asp_team_join_request_47326fba24 ON asp_team_join_request (reviewer_account_id);
COMMENT ON COLUMN asp_team_join_request.reason IS '处理依据';
COMMENT ON COLUMN asp_team_join_request.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_team_join_request.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_team_join_request.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_team_join_request.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_team_join_request.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_team_join_request.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_team_join_request_526d694205 ON asp_team_join_request (team_id, person_id) WHERE status = 'pending';

-- D03: 指定本人邀请、队长可转发分享授权及本人接受事实。分享不公开队内名单；离队后不重放旧授权
CREATE TABLE asp_team_invitation (
    id bigint NOT NULL,
    team_id bigint NOT NULL,
    inviter_account_id bigint NOT NULL,
    inviter_person_id bigint,
    target_person_id bigint,
    invitation_kind varchar(32) NOT NULL DEFAULT 'direct',
    invite_token varchar(64),
    expires_at timestamptz,
    share_invitation_id bigint,
    status varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK ((invitation_kind = 'direct' AND target_person_id IS NOT NULL AND invite_token IS NULL AND expires_at IS NULL) OR (invitation_kind = 'share' AND target_person_id IS NULL AND inviter_person_id IS NOT NULL AND invite_token IS NOT NULL AND expires_at IS NOT NULL AND share_invitation_id IS NULL AND status IN ('pending', 'revoked', 'invalidated'))),
    CHECK (share_invitation_id IS NULL OR (invitation_kind = 'direct' AND status = 'accepted' AND share_invitation_id <> id)),
    CHECK (invitation_kind IN ('direct', 'share')),
    CHECK (invite_token IS NULL OR invite_token ~ '^[a-f0-9]{64}$'),
    CHECK (status IN ('pending', 'accepted', 'declined', 'revoked', 'invalidated')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_team_invitation IS '指定本人邀请、队长可转发分享授权及本人接受事实。分享不公开队内名单；离队后不重放旧授权；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_team_invitation.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_team_invitation.team_id IS '邀请队伍';
CREATE INDEX ix_asp_team_invitation_3aa2742054 ON asp_team_invitation (team_id);
COMMENT ON COLUMN asp_team_invitation.inviter_account_id IS '邀请者';
CREATE INDEX ix_asp_team_invitation_541edd1125 ON asp_team_invitation (inviter_account_id);
COMMENT ON COLUMN asp_team_invitation.inviter_person_id IS '分享授权时的队长稳定档案，转让或账号停止后失效；旧定向邀请为空';
CREATE INDEX ix_asp_team_invitation_ff2af7a6fe ON asp_team_invitation (inviter_person_id);
COMMENT ON COLUMN asp_team_invitation.target_person_id IS '指定受邀人；share 分享授权为空，接受后另插指定本人事实';
CREATE INDEX ix_asp_team_invitation_7d44d535b7 ON asp_team_invitation (target_person_id);
COMMENT ON COLUMN asp_team_invitation.invitation_kind IS 'direct 定向邀请或分享接受事实；share 可转发队伍授权';
COMMENT ON COLUMN asp_team_invitation.invite_token IS '256位随机业务链接凭据，仅当前队长回显；不进日志、通知或匿名预览，不授予成员资料权限';
COMMENT ON COLUMN asp_team_invitation.expires_at IS '分享授权七天到期；旧定向邀请不设到期；有时区业务时间';
COMMENT ON COLUMN asp_team_invitation.share_invitation_id IS '本人接受分享的来源；同来源同本人仅一次，结束成员后不复活';
CREATE INDEX ix_asp_team_invitation_e3672ea44b ON asp_team_invitation (share_invitation_id);
COMMENT ON COLUMN asp_team_invitation.status IS '独立业务状态；合法值不等于业务已获批准：pending accepted declined revoked invalidated';
COMMENT ON COLUMN asp_team_invitation.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_team_invitation.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_team_invitation.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_team_invitation.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_team_invitation.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_team_invitation.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_team_invitation_6300200126 ON asp_team_invitation (team_id, target_person_id) WHERE status = 'pending';
CREATE UNIQUE INDEX uq_asp_team_invitation_2025c7b47c ON asp_team_invitation (invite_token) WHERE invite_token IS NOT NULL;
CREATE UNIQUE INDEX uq_asp_team_invitation_ce39d0c8ce ON asp_team_invitation (team_id) WHERE invitation_kind = 'share' AND status = 'pending';
CREATE UNIQUE INDEX uq_asp_team_invitation_8bc78abb4b ON asp_team_invitation (share_invitation_id, target_person_id) WHERE share_invitation_id IS NOT NULL;

-- D03: 队伍改名、转让、解散的事实和快照。不代替成员终止行，也不回写已提交报名
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
COMMENT ON TABLE asp_team_history IS '队伍改名、转让、解散的事实和快照。不代替成员终止行，也不回写已提交报名；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
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

-- D03: 账户建队与入队配额。一期没有已批准数值，服务不读不写
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
COMMENT ON TABLE asp_team_quota IS '账户建队与入队配额。一期没有已批准数值，服务不读不写；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
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

-- D04: 赛事容器。M1.3 的发布和举办状态分开，时间阶段按北京时间计算，不改这一列的旧生命周期取值
CREATE TABLE asp_event (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    organization_id bigint NOT NULL,
    name varchar(200),
    series_id bigint,
    starts_at timestamptz,
    ends_at timestamptz,
    registration_opens_at timestamptz,
    registration_closes_at timestamptz,
    location varchar(200),
    project_name varchar(200),
    fee_description varchar(1000),
    banner_file_id bigint,
    rules_text varchar(4000),
    rules_file_id bigint,
    notice_text varchar(4000),
    notice_file_id bigint,
    declaration_text varchar(4000),
    declaration_file_id bigint,
    declaration_ack_required boolean NOT NULL DEFAULT false,
    route_text varchar(4000),
    route_file_id bigint,
    cancel_reason varchar(1000),
    sport_code varchar(32) NOT NULL DEFAULT 'badminton',
    publication_status varchar(32) NOT NULL DEFAULT 'draft',
    holding_status varchar(32) NOT NULL DEFAULT 'normal',
    registration_review varchar(16) NOT NULL DEFAULT 'manual',
    registration_review_locked boolean NOT NULL DEFAULT false,
    status varchar(32) NOT NULL,
    registration_status varchar(32) NOT NULL,
    payment_status varchar(32) NOT NULL,
    visibility varchar(32) NOT NULL,
    published_revision integer NOT NULL,
    contact_snapshot jsonb NOT NULL,
    operations_materials jsonb NOT NULL DEFAULT '{}'::jsonb,
    closure_status varchar(32) NOT NULL DEFAULT 'open',
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
    CHECK (registration_closes_at IS NULL OR starts_at IS NULL OR registration_closes_at <= starts_at),
    CHECK (length(tenant_id) > 0),
    CHECK (sport_code = 'badminton'),
    CHECK (publication_status IN ('draft', 'published', 'offline')),
    CHECK (holding_status IN ('normal', 'cancelled')),
    CHECK (registration_review IN ('manual', 'none')),
    CHECK (status IN ('draft', 'pending', 'published', 'postponed', 'cancelled', 'completed', 'archived')),
    CHECK (registration_status IN ('closed', 'scheduled', 'open', 'suspended', 'ended')),
    CHECK (payment_status IN ('disabled', 'enabled', 'suspended')),
    CHECK (visibility IN ('private', 'public')),
    CHECK (published_revision >= 0),
    CHECK (jsonb_typeof(operations_materials) = 'object'),
    CHECK (closure_status IN ('open','wrap_up','closed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_event IS '赛事容器。M1.3 的发布和举办状态分开，时间阶段按北京时间计算，不改这一列的旧生命周期取值；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_event.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_event.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_event.organization_id IS '主责组织';
CREATE INDEX ix_asp_event_ba1502a512 ON asp_event (tenant_id, organization_id);
COMMENT ON COLUMN asp_event.name IS '赛事名称。草稿可空，发布时必填';
COMMENT ON COLUMN asp_event.series_id IS '系列/联赛业务关联；后续系列服务核验';
COMMENT ON COLUMN asp_event.starts_at IS '开赛时间。发布时必填；有时区业务时间';
COMMENT ON COLUMN asp_event.ends_at IS '结束时间。发布时必填；有时区业务时间';
COMMENT ON COLUMN asp_event.registration_opens_at IS '报名开始。报名是否接受以报名流程为准，时间记在赛事上；有时区业务时间';
COMMENT ON COLUMN asp_event.registration_closes_at IS '报名结束。报名是否接受以报名流程为准，时间记在赛事上；有时区业务时间';
COMMENT ON COLUMN asp_event.location IS '比赛地点。公开文字，不引用场馆';
COMMENT ON COLUMN asp_event.project_name IS '赛事项目。公开文字，不建竞赛单元';
COMMENT ON COLUMN asp_event.fee_description IS '收费方式或收费说明。公开文字，不产生付款';
COMMENT ON COLUMN asp_event.banner_file_id IS '宣传图文件编号。可空，不建外键';
COMMENT ON COLUMN asp_event.rules_text IS '竞赛规程文字。可与图片同时存在';
COMMENT ON COLUMN asp_event.rules_file_id IS '竞赛规程图片文件编号。可空，不建外键';
COMMENT ON COLUMN asp_event.notice_text IS '报名须知文字。可与图片同时存在';
COMMENT ON COLUMN asp_event.notice_file_id IS '报名须知图片文件编号。可空，不建外键';
COMMENT ON COLUMN asp_event.declaration_text IS '参赛声明文字。可与图片同时存在';
COMMENT ON COLUMN asp_event.declaration_file_id IS '参赛声明图片文件编号。可空，不建外键';
COMMENT ON COLUMN asp_event.declaration_ack_required IS '参赛声明是否必须由成员本人点击确认。不是证件核验，也不是电子签章';
COMMENT ON COLUMN asp_event.route_text IS '比赛地点或路线说明。地图嵌入不在本期';
COMMENT ON COLUMN asp_event.route_file_id IS '比赛地点或路线图片文件编号。可空，不建外键';
COMMENT ON COLUMN asp_event.cancel_reason IS '取消原因。可空，有内容时出现在公开详情';
COMMENT ON COLUMN asp_event.sport_code IS '运动编码。本期只能是 badminton';
COMMENT ON COLUMN asp_event.publication_status IS '发布状态：draft published offline。已发布不能直接改公开信息';
COMMENT ON COLUMN asp_event.holding_status IS '举办状态：normal cancelled。取消不等于下架，已结束不能取消';
COMMENT ON COLUMN asp_event.registration_review IS '报名资格审核：manual 人工审核，none 无需审核。与赛事发布审批无关';
COMMENT ON COLUMN asp_event.registration_review_locked IS '首笔正式提交后锁定审核方式。全部撤回也不解锁';
COMMENT ON COLUMN asp_event.status IS '后继生命周期。M1.3 不拿它判断公开：draft pending published postponed cancelled completed archived';
COMMENT ON COLUMN asp_event.registration_status IS '独立业务状态；合法值不等于业务已获批准：closed scheduled open suspended ended';
COMMENT ON COLUMN asp_event.payment_status IS '独立业务状态；合法值不等于业务已获批准：disabled enabled suspended';
COMMENT ON COLUMN asp_event.visibility IS '旧可见性列。M1.3 公开与否不看它：private public';
COMMENT ON COLUMN asp_event.published_revision IS '当前发布版本；0 为未发布';
COMMENT ON COLUMN asp_event.contact_snapshot IS '履约联系及退改承诺；state=draft为材料候选，明确发布确认后连同组织、联系渠道、退改原文和confirmedAt冻结；历史未标state快照保留原发布含义；必须按版本校验结构';
COMMENT ON COLUMN asp_event.operations_materials IS '主办方私有策划、脚本、公告和宣传草稿。每类独立版本、真实来源及最多10个历史版本；不自动发布';
COMMENT ON COLUMN asp_event.closure_status IS '赛后问题与资金收尾状态';
COMMENT ON COLUMN asp_event.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_event.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_event.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_event.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_event.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_event.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D04: 赛事写操作幂等。同一租户、同一动作、同一请求键只生效一次，重复提交不再次发布
CREATE TABLE asp_event_command (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    event_id bigint NOT NULL,
    action varchar(32) NOT NULL,
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
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_event_command IS '赛事写操作幂等。同一租户、同一动作、同一请求键只生效一次，重复提交不再次发布；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_event_command.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_event_command.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_event_command.event_id IS '已经处理过的赛事';
CREATE INDEX ix_asp_event_command_b779acfd64 ON asp_event_command (tenant_id, event_id);
COMMENT ON COLUMN asp_event_command.action IS '动作。本期只有 publish';
COMMENT ON COLUMN asp_event_command.request_key IS '客户端幂等键';
COMMENT ON COLUMN asp_event_command.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_event_command.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_event_command.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_event_command.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_event_command.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_event_command.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_event_command_7ec862025f ON asp_event_command (tenant_id, action, request_key);

-- D05: 成员本人对当时参赛声明的点击确认。队长不能代确认，确认不是电子签章
CREATE TABLE asp_declaration_ack (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    registration_member_id bigint NOT NULL,
    account_id bigint NOT NULL,
    event_id bigint NOT NULL,
    content_digest varchar(64) NOT NULL,
    acknowledged_at timestamptz NOT NULL,
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
COMMENT ON TABLE asp_declaration_ack IS '成员本人对当时参赛声明的点击确认。队长不能代确认，确认不是电子签章；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_declaration_ack.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_declaration_ack.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_declaration_ack.registration_member_id IS '确认的报名成员';
CREATE INDEX ix_asp_declaration_ack_e94e7e6d7a ON asp_declaration_ack (tenant_id, registration_member_id);
COMMENT ON COLUMN asp_declaration_ack.account_id IS '点击确认的平台账号，必须是该成员本人';
CREATE INDEX ix_asp_declaration_ack_8ba3d6287f ON asp_declaration_ack (account_id);
COMMENT ON COLUMN asp_declaration_ack.event_id IS '声明所属赛事';
CREATE INDEX ix_asp_declaration_ack_1c35a2201c ON asp_declaration_ack (tenant_id, event_id);
COMMENT ON COLUMN asp_declaration_ack.content_digest IS '确认时声明文字和文件的摘要。声明变化后需重新确认';
COMMENT ON COLUMN asp_declaration_ack.acknowledged_at IS '本人点击确认的时间；有时区业务时间';
COMMENT ON COLUMN asp_declaration_ack.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_declaration_ack.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_declaration_ack.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_declaration_ack.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_declaration_ack.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_declaration_ack.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_declaration_ack_e94e7e6d7a ON asp_declaration_ack (tenant_id, registration_member_id);

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

-- D04: 报名坐标。M1.4 按整单占用名额，报名窗口仍在赛事上
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
    competition_type_id bigint,
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
COMMENT ON TABLE asp_competition_unit IS '报名坐标。M1.4 按整单占用名额，报名窗口仍在赛事上；来源：母版 D04；同赛事有效项目名称去首尾空白并忽略大小写唯一；无正式提交可关闭删除，有历史只做名称一般更正。';
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
COMMENT ON COLUMN asp_competition_unit.competition_type_id IS '统一比赛类型；旧数据按明确人数匹配，不能猜测未支持类型';
CREATE INDEX ix_asp_competition_unit_4e7aad0a16 ON asp_competition_unit (competition_type_id);
COMMENT ON COLUMN asp_competition_unit.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_competition_unit.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_competition_unit.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_competition_unit.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_competition_unit.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_competition_unit.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_competition_unit_ecf519a917 ON asp_competition_unit (tenant_id, event_id, lower(btrim(name))) WHERE status = 'open';

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

-- D04: 某版规则要求报名时采集的属性；社区活动可以一条都不选
CREATE TABLE asp_attribute_requirement (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    rule_version_id bigint NOT NULL,
    attribute_id bigint NOT NULL,
    required boolean NOT NULL,
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
COMMENT ON TABLE asp_attribute_requirement IS '某版规则要求报名时采集的属性；社区活动可以一条都不选；来源：母版 D04；新项目通过增选目录属性扩展报名表；不为此修改 asp_person。提交时抄入名单快照。';
COMMENT ON COLUMN asp_attribute_requirement.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_attribute_requirement.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_attribute_requirement.rule_version_id IS '规则版本';
CREATE INDEX ix_asp_attribute_requirement_38802fd90c ON asp_attribute_requirement (tenant_id, rule_version_id);
COMMENT ON COLUMN asp_attribute_requirement.attribute_id IS '要采集的属性';
CREATE INDEX ix_asp_attribute_requirement_2ef8673468 ON asp_attribute_requirement (attribute_id);
COMMENT ON COLUMN asp_attribute_requirement.required IS 'true 为该版本报名必填';
COMMENT ON COLUMN asp_attribute_requirement.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_attribute_requirement.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_attribute_requirement.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_attribute_requirement.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_attribute_requirement.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_attribute_requirement.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_attribute_requirement_cb22f77d48 ON asp_attribute_requirement (tenant_id, rule_version_id, attribute_id);

-- D04: 组织自有的参赛采集字段。未选用可停用；选用后不改类型和选项含义
CREATE TABLE asp_org_field (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    organization_id bigint NOT NULL,
    code varchar(64) NOT NULL,
    label varchar(100) NOT NULL,
    value_type varchar(32) NOT NULL,
    options jsonb NOT NULL,
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
    CHECK (value_type IN ('text', 'number', 'date', 'enum')),
    CHECK (status IN ('active', 'stopped')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_org_field IS '组织自有的参赛采集字段。未选用可停用；选用后不改类型和选项含义；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_org_field.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_org_field.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_org_field.organization_id IS '维护这个目录的组织';
CREATE INDEX ix_asp_org_field_28200406a8 ON asp_org_field (tenant_id, organization_id);
COMMENT ON COLUMN asp_org_field.code IS '组织内稳定编码';
COMMENT ON COLUMN asp_org_field.label IS '显示名称';
COMMENT ON COLUMN asp_org_field.value_type IS '独立业务状态；合法值不等于业务已获批准：text number date enum';
COMMENT ON COLUMN asp_org_field.options IS '单选枚举的选项。其他类型为空数组；必须按版本校验结构';
COMMENT ON COLUMN asp_org_field.status IS '独立业务状态；合法值不等于业务已获批准：active stopped';
COMMENT ON COLUMN asp_org_field.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_org_field.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_org_field.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_org_field.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_org_field.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_org_field.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_org_field_9a30614e40 ON asp_org_field (tenant_id, organization_id, code);

-- D04: 一场赛事选用的组织字段。一期全赛事同一套，首笔正式提交后不再改
CREATE TABLE asp_event_field (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    event_id bigint NOT NULL,
    org_field_id bigint NOT NULL,
    required boolean NOT NULL DEFAULT false,
    sort_order integer NOT NULL,
    note varchar(500),
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (sort_order >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_event_field IS '一场赛事选用的组织字段。一期全赛事同一套，首笔正式提交后不再改；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_event_field.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_event_field.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_event_field.event_id IS '赛事';
CREATE INDEX ix_asp_event_field_e2b0754b6a ON asp_event_field (tenant_id, event_id);
COMMENT ON COLUMN asp_event_field.org_field_id IS '组织字段';
CREATE INDEX ix_asp_event_field_eca782102f ON asp_event_field (tenant_id, org_field_id);
COMMENT ON COLUMN asp_event_field.required IS 'true 为本人必须填写';
COMMENT ON COLUMN asp_event_field.sort_order IS '显示顺序';
COMMENT ON COLUMN asp_event_field.note IS '给参赛者的说明';
COMMENT ON COLUMN asp_event_field.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_event_field.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_event_field.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_event_field.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_event_field.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_event_field.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_event_field_97a0e34f0e ON asp_event_field (tenant_id, event_id, org_field_id);

-- D05: 报名成员对赛事字段的填写。提交时保留当时的名称、类型和选项
CREATE TABLE asp_entry_field_value (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    registration_member_id bigint NOT NULL,
    event_field_id bigint NOT NULL,
    value_text varchar(1000) NOT NULL,
    label_snapshot varchar(100) NOT NULL,
    type_snapshot varchar(16) NOT NULL,
    options_snapshot jsonb NOT NULL,
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
COMMENT ON TABLE asp_entry_field_value IS '报名成员对赛事字段的填写。提交时保留当时的名称、类型和选项；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_entry_field_value.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_entry_field_value.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_entry_field_value.registration_member_id IS '填写人';
CREATE INDEX ix_asp_entry_field_value_e0df94b724 ON asp_entry_field_value (tenant_id, registration_member_id);
COMMENT ON COLUMN asp_entry_field_value.event_field_id IS '当时选用的字段';
CREATE INDEX ix_asp_entry_field_value_89883310ed ON asp_entry_field_value (tenant_id, event_field_id);
COMMENT ON COLUMN asp_entry_field_value.value_text IS '填写值';
COMMENT ON COLUMN asp_entry_field_value.label_snapshot IS '提交时的字段名称';
COMMENT ON COLUMN asp_entry_field_value.type_snapshot IS '提交时的类型';
COMMENT ON COLUMN asp_entry_field_value.options_snapshot IS '提交时的枚举选项；必须按版本校验结构';
COMMENT ON COLUMN asp_entry_field_value.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_entry_field_value.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_entry_field_value.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_entry_field_value.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_entry_field_value.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_entry_field_value.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_entry_field_value_d662a7c909 ON asp_entry_field_value (tenant_id, registration_member_id, event_field_id);

-- D04: 赛事文件材料、用途与各阶段前置；体检、保险和责任书走这里
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
    CHECK (sensitivity IN ('ordinary', 'identity', 'health', 'finance')),
    CHECK (retention_days >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_material_requirement IS '赛事文件材料、用途与各阶段前置；体检、保险和责任书走这里；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_material_requirement.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_material_requirement.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_material_requirement.rule_version_id IS '规则版本';
CREATE INDEX ix_asp_material_requirement_e44238f2fd ON asp_material_requirement (tenant_id, rule_version_id);
COMMENT ON COLUMN asp_material_requirement.code IS '材料编码';
COMMENT ON COLUMN asp_material_requirement.purpose IS '资料使用用途';
COMMENT ON COLUMN asp_material_requirement.sensitivity IS '独立业务状态；合法值不等于业务已获批准：ordinary identity health finance';
COMMENT ON COLUMN asp_material_requirement.gates IS '占位/审核/检录/公开分别的前置及确认；必须按版本校验结构';
COMMENT ON COLUMN asp_material_requirement.retention_days IS '保留期限；0 须按政策明确解释';
COMMENT ON COLUMN asp_material_requirement.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_material_requirement.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_material_requirement.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_material_requirement.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_material_requirement.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_material_requirement.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_material_requirement_485f48e2db ON asp_material_requirement (tenant_id, rule_version_id, code);

-- D06: 赛事统一收款指引，承办方资金授权维护；首次正式提交后锁定。金额仍按项目，指引不是到账
CREATE TABLE asp_event_payment_config (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    event_id bigint NOT NULL,
    settings jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (jsonb_typeof(settings) = 'object' AND settings ? 'schemaVersion' AND settings->>'schemaVersion' = '1' AND settings ? 'channels' AND jsonb_typeof(settings->'channels') = 'array'),
    CHECK (length(tenant_id) > 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_event_payment_config IS '赛事统一收款指引，承办方资金授权维护；首次正式提交后锁定。金额仍按项目，指引不是到账；来源：母版 D06；资金授权、文件用途及租户校验、渠道结构及必填、与首笔正式提交串行；提交时指引及二维码文件编号复制到义务快照，旧版收费仍按原版本读取。';
COMMENT ON COLUMN asp_event_payment_config.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_event_payment_config.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_event_payment_config.event_id IS '所属赛事；同租户唯一，应用校验组织归属';
CREATE INDEX ix_asp_event_payment_config_fa5895b565 ON asp_event_payment_config (tenant_id, event_id);
COMMENT ON COLUMN asp_event_payment_config.settings IS 'v1含channels及instruction；wechat/alipay/custom_qr引用payment-qr文件，bank含受保护账户，offline含办理指引。不得公开或发送模型；必须按版本校验结构';
COMMENT ON COLUMN asp_event_payment_config.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_event_payment_config.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_event_payment_config.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_event_payment_config.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_event_payment_config.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_event_payment_config.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_event_payment_config_fa5895b565 ON asp_event_payment_config (tenant_id, event_id);

-- D06: 竞赛单元的收费版本。已生效的不改价，改价另起一版
CREATE TABLE asp_fee_policy (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    unit_id bigint NOT NULL,
    revision integer NOT NULL,
    pricing_unit varchar(32) NOT NULL,
    amount numeric(18,2),
    payment_mode varchar(32),
    pay_instruction varchar(1000),
    qr_file_id bigint,
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
    CHECK (status <> 'active' OR (amount IS NOT NULL AND payment_mode IS NOT NULL AND ((payment_mode = 'free' AND amount = 0) OR (payment_mode <> 'free' AND amount > 0)))),
    CHECK (length(tenant_id) > 0),
    CHECK (revision >= 0),
    CHECK (pricing_unit IN ('free', 'person', 'pair', 'team', 'project', 'combination', 'entry')),
    CHECK (amount IS NULL OR amount >= 0),
    CHECK (payment_mode IS NULL OR payment_mode IN ('free', 'offline', 'organizer_qr', 'event')),
    CHECK (status IN ('draft', 'active', 'retired')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_fee_policy IS '竞赛单元的收费版本。已生效的不改价，改价另起一版；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_fee_policy.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_fee_policy.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_fee_policy.unit_id IS '适用单元';
CREATE INDEX ix_asp_fee_policy_a1c8078315 ON asp_fee_policy (tenant_id, unit_id);
COMMENT ON COLUMN asp_fee_policy.revision IS '费用版本';
COMMENT ON COLUMN asp_fee_policy.pricing_unit IS '一期生效版本使用 entry，表示整单固定价：free person pair team project combination entry';
COMMENT ON COLUMN asp_fee_policy.amount IS '整单固定金额。免费为 0。草稿可空';
COMMENT ON COLUMN asp_fee_policy.payment_mode IS 'free免费；event赛事统一渠道；offline/organizer_qr保留旧收费及历史付款依据。草稿可空';
COMMENT ON COLUMN asp_fee_policy.pay_instruction IS '线下说明或收款二维码说明';
COMMENT ON COLUMN asp_fee_policy.qr_file_id IS '承办方收款二维码文件编号。可空，不建外键';
COMMENT ON COLUMN asp_fee_policy.pricing_rules IS '旧的计价结构。一期金额以 amount 为准；必须按版本校验结构';
COMMENT ON COLUMN asp_fee_policy.payer_modes IS '旧的承担方式。一期不使用；必须按版本校验结构';
COMMENT ON COLUMN asp_fee_policy.collection_paths IS '旧的收款路径。一期收款主体固定为承办方；必须按版本校验结构';
COMMENT ON COLUMN asp_fee_policy.refund_terms IS '旧的退款条款。一期不自动退款；必须按版本校验结构';
COMMENT ON COLUMN asp_fee_policy.status IS '独立业务状态；合法值不等于业务已获批准：draft active retired';
COMMENT ON COLUMN asp_fee_policy.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_fee_policy.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_fee_policy.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_fee_policy.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_fee_policy.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_fee_policy.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_fee_policy_1d97b077a1 ON asp_fee_policy (tenant_id, unit_id, revision);
CREATE UNIQUE INDEX uq_asp_fee_policy_8d57190dfe ON asp_fee_policy (tenant_id, unit_id) WHERE status = 'active';

-- D05: 一次提交的报名批次；不等于一笔订单，也不能借此创建他人账号
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
COMMENT ON TABLE asp_registration_batch IS '一次提交的报名批次；不等于一笔订单，也不能借此创建他人账号；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
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

-- D05: 竞赛单元报名。草稿不占名额；已提交和已通过占名额；撤回回到草稿
CREATE TABLE asp_registration (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    unit_id bigint NOT NULL,
    rule_version_id bigint,
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
    submitted_at timestamptz,
    manager_account_id bigint,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('draft', 'submitted', 'approved', 'rejected')),
    CHECK (roster_revision >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_registration IS '竞赛单元报名。草稿不占名额；已提交和已通过占名额；撤回回到草稿；来源：母版 D05；同一提交人在同一单元只有一条报名。代表队伍的报名按 team_id 识别当前可办理的那一条，不另加一队一单元的唯一约束。已经完成提交的请求键只重放该次事实，不第二次占名额，撤回后也不复活报名。名额排队使用通用锁，used_count 只做上限。';
COMMENT ON COLUMN asp_registration.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_registration.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_registration.unit_id IS '报名单元';
CREATE INDEX ix_asp_registration_217fd3d0fd ON asp_registration (tenant_id, unit_id);
COMMENT ON COLUMN asp_registration.rule_version_id IS '提交时规则。本期可空，不临时造规则版本';
CREATE INDEX ix_asp_registration_f8b0175b47 ON asp_registration (tenant_id, rule_version_id);
COMMENT ON COLUMN asp_registration.fee_policy_id IS '费用依据';
CREATE INDEX ix_asp_registration_a0d5d3804d ON asp_registration (tenant_id, fee_policy_id);
COMMENT ON COLUMN asp_registration.batch_id IS '操作批次';
CREATE INDEX ix_asp_registration_c3c2a32d6f ON asp_registration (tenant_id, batch_id);
COMMENT ON COLUMN asp_registration.team_id IS '可选长期代表队。空表示个人或临时双打';
CREATE INDEX ix_asp_registration_34a0daff97 ON asp_registration (team_id);
COMMENT ON COLUMN asp_registration.submitter_account_id IS '原提交人';
CREATE INDEX ix_asp_registration_ee864d6727 ON asp_registration (submitter_account_id);
COMMENT ON COLUMN asp_registration.operator_account_id IS '当前办理人';
CREATE INDEX ix_asp_registration_bddadcf747 ON asp_registration (operator_account_id);
COMMENT ON COLUMN asp_registration.request_key IS '当前办理请求键。尚未完成提交时沿用创建键；完成后的重放不再占用，主动重提更换新键';
COMMENT ON COLUMN asp_registration.status IS '独立业务状态；合法值不等于业务已获批准：draft submitted approved rejected';
COMMENT ON COLUMN asp_registration.hold_expires_at IS '旧的临时占位期限。本期不使用；有时区业务时间';
COMMENT ON COLUMN asp_registration.roster_revision IS '当前名单版本。草稿为 0';
COMMENT ON COLUMN asp_registration.team_name_snapshot IS '提交成功时的队名。之后队伍改名不回写';
COMMENT ON COLUMN asp_registration.submitted_at IS '实际提交时间。草稿可空；有时区业务时间';
COMMENT ON COLUMN asp_registration.manager_account_id IS '稳定报名管理人，独立于当前队长与组织审核经办人';
CREATE INDEX ix_asp_registration_4bed8fc1f9 ON asp_registration (manager_account_id);
COMMENT ON COLUMN asp_registration.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_registration.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_registration.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_registration.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_registration.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_registration.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_registration_5795931c89 ON asp_registration (tenant_id, submitter_account_id, request_key);
CREATE UNIQUE INDEX uq_asp_registration_f61f3032ee ON asp_registration (tenant_id, unit_id, submitter_account_id);

-- D05: 已经完成的报名提交请求键。撤回或拒绝后重放旧键不得再次占用
CREATE TABLE asp_registration_submit_key (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    registration_id bigint NOT NULL,
    submitter_account_id bigint NOT NULL,
    request_key varchar(128) NOT NULL,
    roster_revision integer NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (roster_revision > 0),
    CHECK (length(tenant_id) > 0),
    CHECK (roster_revision >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_registration_submit_key IS '已经完成的报名提交请求键。撤回或拒绝后重放旧键不得再次占用；来源：母版 D05；同一提交人的一个请求键只完成一次提交。主动重提使用新键并另记一行，对应这次的名单版本和独立付款义务。未完成提交的创建键不记入本表。';
COMMENT ON COLUMN asp_registration_submit_key.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_registration_submit_key.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_registration_submit_key.registration_id IS '报名';
CREATE INDEX ix_asp_registration_submit_key_48c5af2b13 ON asp_registration_submit_key (tenant_id, registration_id);
COMMENT ON COLUMN asp_registration_submit_key.submitter_account_id IS '提交人';
CREATE INDEX ix_asp_registration_submit_key_6abb4d96f7 ON asp_registration_submit_key (submitter_account_id);
COMMENT ON COLUMN asp_registration_submit_key.request_key IS '已经完成一次提交的请求键';
COMMENT ON COLUMN asp_registration_submit_key.roster_revision IS '这次提交冻结的名单版本';
COMMENT ON COLUMN asp_registration_submit_key.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_registration_submit_key.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_registration_submit_key.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_registration_submit_key.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_registration_submit_key.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_registration_submit_key.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_registration_submit_key_1f6ecc624c ON asp_registration_submit_key (tenant_id, submitter_account_id, request_key);
CREATE UNIQUE INDEX uq_asp_registration_submit_key_e7847965a9 ON asp_registration_submit_key (tenant_id, registration_id, roster_revision);

-- D05: 报名成员确认。按平台账号记录，提交成功后才抄入名单快照
CREATE TABLE asp_registration_member (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    registration_id bigint NOT NULL,
    unit_id bigint NOT NULL,
    account_id bigint NOT NULL,
    person_id bigint,
    status varchar(32) NOT NULL,
    self_member boolean NOT NULL DEFAULT false,
    invite_token varchar(64),
    person_snapshot jsonb,
    occupying boolean NOT NULL DEFAULT false,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (occupying = false OR status = 'confirmed'),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('pending_confirmation', 'confirmed', 'declined')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_registration_member IS '报名成员确认。按平台账号记录，提交成功后才抄入名单快照；来源：母版 D05；邀请确认不是长期队伍邀请。已提交或已通过的成员才把 occupying 设为 true。';
COMMENT ON COLUMN asp_registration_member.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_registration_member.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_registration_member.registration_id IS '报名';
CREATE INDEX ix_asp_registration_member_b8c5dafa6d ON asp_registration_member (tenant_id, registration_id);
COMMENT ON COLUMN asp_registration_member.unit_id IS '竞赛单元。冗余，用于同一人同一单元只有一条有效报名';
CREATE INDEX ix_asp_registration_member_367571c8b9 ON asp_registration_member (tenant_id, unit_id);
COMMENT ON COLUMN asp_registration_member.account_id IS '成员平台账号';
CREATE INDEX ix_asp_registration_member_c3cc982e77 ON asp_registration_member (account_id);
COMMENT ON COLUMN asp_registration_member.person_id IS '确认时的本人档案。待确认时可空';
CREATE INDEX ix_asp_registration_member_ffbd266d59 ON asp_registration_member (person_id);
COMMENT ON COLUMN asp_registration_member.status IS '独立业务状态；合法值不等于业务已获批准：pending_confirmation confirmed declined';
COMMENT ON COLUMN asp_registration_member.self_member IS 'true 表示报名提交人本人';
COMMENT ON COLUMN asp_registration_member.invite_token IS '邀请确认令牌。本人成员为空';
COMMENT ON COLUMN asp_registration_member.person_snapshot IS '确认时抄下的档案。提交名单时使用，之后改档案不回写；必须按版本校验结构';
COMMENT ON COLUMN asp_registration_member.occupying IS 'true 表示这条成员正在占用该单元的有效报名';
COMMENT ON COLUMN asp_registration_member.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_registration_member.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_registration_member.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_registration_member.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_registration_member.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_registration_member.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_registration_member_8696a1f9b7 ON asp_registration_member (tenant_id, registration_id, account_id);
CREATE UNIQUE INDEX uq_asp_registration_member_6da214a13c ON asp_registration_member (tenant_id, unit_id, account_id) WHERE occupying = true;
CREATE UNIQUE INDEX uq_asp_registration_member_95aaf903f1 ON asp_registration_member (tenant_id, invite_token) WHERE invite_token IS NOT NULL;

-- D05: 赛事报名名单版本；替补和冻结依据
CREATE TABLE asp_roster_version (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    registration_id bigint NOT NULL,
    revision integer NOT NULL,
    rule_version_id bigint,
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
COMMENT ON COLUMN asp_roster_version.rule_version_id IS '核验规则。本期报名可空';
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
COMMENT ON COLUMN asp_roster_member.person_snapshot IS '报名当时的身份列和本场选中属性；之后修改档案不回写；必须按版本校验结构';
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
    reviewer_id bigint,
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
COMMENT ON COLUMN asp_qualification_review.reviewer_id IS '审核后台账号。无需审核的自动通过为空，不伪造人工审核人';
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
    CHECK (capacity_unit IN ('person', 'pair', 'team', 'seat', 'lane', 'entry')),
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
COMMENT ON COLUMN asp_capacity_pool.capacity_unit IS '独立业务状态；合法值不等于业务已获批准：person pair team seat lane entry';
COMMENT ON COLUMN asp_capacity_pool.dedupe_scope IS '计数去重范围。M1.4 按 entry 整单计数';
COMMENT ON COLUMN asp_capacity_pool.limit_count IS '上限';
COMMENT ON COLUMN asp_capacity_pool.used_count IS '当前有效及临时占用数；同事务维护';
COMMENT ON COLUMN asp_capacity_pool.status IS '独立业务状态；合法值不等于业务已获批准：active suspended closed';
COMMENT ON COLUMN asp_capacity_pool.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_capacity_pool.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_capacity_pool.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_capacity_pool.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_capacity_pool.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_capacity_pool.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_capacity_pool_a5e7dacf0b ON asp_capacity_pool (tenant_id, unit_id) WHERE unit_id IS NOT NULL AND capacity_unit = 'entry';

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

-- D06: 一次正式提交产生的付款义务。免费也记一笔，但不产生付款
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
    declared_at timestamptz,
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
    CHECK (status IN ('not_required', 'open', 'settled', 'void')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_fee_obligation IS '一次正式提交产生的付款义务。免费也记一笔，但不产生付款；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_fee_obligation.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_fee_obligation.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_fee_obligation.registration_id IS '报名';
CREATE INDEX ix_asp_fee_obligation_a44fb80ed8 ON asp_fee_obligation (tenant_id, registration_id);
COMMENT ON COLUMN asp_fee_obligation.fee_policy_id IS '提交时的收费版本';
CREATE INDEX ix_asp_fee_obligation_381f50c2e6 ON asp_fee_obligation (tenant_id, fee_policy_id);
COMMENT ON COLUMN asp_fee_obligation.total_amount IS '当时解析出的整单金额。免费为 0；人民币元，不能用浮点';
COMMENT ON COLUMN asp_fee_obligation.currency IS '币种。一期固定 CNY';
COMMENT ON COLUMN asp_fee_obligation.status IS '独立业务状态；合法值不等于业务已获批准：not_required open settled void';
COMMENT ON COLUMN asp_fee_obligation.quote_snapshot IS '当次提交的整单金额、方式和说明；新快照rosterRevision记录当次实际冻结名单版本，历史缺值不回填或按顺序推定，展示原创建时间；统一收款含paymentSettings渠道及二维码文件编号快照，账户仅授权付款用途可见，不随配置改变；必须按版本校验结构';
COMMENT ON COLUMN asp_fee_obligation.request_key IS '义务幂等键。不复用报名请求键';
COMMENT ON COLUMN asp_fee_obligation.declared_at IS '参赛者点击模拟付款完成的时间。不是到账确认；有时区业务时间';
COMMENT ON COLUMN asp_fee_obligation.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_fee_obligation.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_fee_obligation.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_fee_obligation.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_fee_obligation.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_fee_obligation.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_fee_obligation_679d7db660 ON asp_fee_obligation (tenant_id, registration_id, request_key);
CREATE UNIQUE INDEX uq_asp_fee_obligation_73e66feac9 ON asp_fee_obligation (tenant_id, registration_id) WHERE status IN ('not_required', 'open');

-- D06: 报名管理人自愿上传的私有付款图片。只关联一次提交的义务，不代表到账，撤回重提不沿用
CREATE TABLE asp_registration_payment_proof (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    registration_id bigint NOT NULL,
    obligation_id bigint NOT NULL,
    uploaded_by_account_id bigint NOT NULL,
    file_id bigint NOT NULL,
    request_key varchar(128) NOT NULL,
    content_digest varchar(64) NOT NULL,
    uploaded_at timestamptz NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (length(content_digest) = 64),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_registration_payment_proof IS '报名管理人自愿上传的私有付款图片。只关联一次提交的义务，不代表到账，撤回重提不沿用；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_registration_payment_proof.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_registration_payment_proof.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_registration_payment_proof.registration_id IS '凭证所属报名';
CREATE INDEX ix_asp_registration_payment_proof_cfd6715645 ON asp_registration_payment_proof (tenant_id, registration_id);
COMMENT ON COLUMN asp_registration_payment_proof.obligation_id IS '本次提交的付款义务';
CREATE INDEX ix_asp_registration_payment_proof_a1c013aef4 ON asp_registration_payment_proof (tenant_id, obligation_id);
COMMENT ON COLUMN asp_registration_payment_proof.uploaded_by_account_id IS '本人或当前队长的上传账号';
CREATE INDEX ix_asp_registration_payment_proof_4be681417d ON asp_registration_payment_proof (uploaded_by_account_id);
COMMENT ON COLUMN asp_registration_payment_proof.file_id IS '私有 payment-proof 图片，金融敏感材料，不公开 URL';
CREATE INDEX ix_asp_registration_payment_proof_448352ff99 ON asp_registration_payment_proof (file_id);
COMMENT ON COLUMN asp_registration_payment_proof.request_key IS '上传幂等键，同键不能更换内容';
COMMENT ON COLUMN asp_registration_payment_proof.content_digest IS '图片 SHA-256，用于重复请求核验';
COMMENT ON COLUMN asp_registration_payment_proof.uploaded_at IS '上传完成时间，不是到账时间；有时区业务时间';
COMMENT ON COLUMN asp_registration_payment_proof.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_registration_payment_proof.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_registration_payment_proof.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_registration_payment_proof.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_registration_payment_proof.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_registration_payment_proof.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_registration_payment_proof_06f2d49b8e ON asp_registration_payment_proof (tenant_id, obligation_id, uploaded_by_account_id, request_key);
CREATE UNIQUE INDEX uq_asp_registration_payment_proof_448352ff99 ON asp_registration_payment_proof (tenant_id, file_id);

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

-- D06: 已经确认的到账事实。未付款时不插入。冲正不是退款
CREATE TABLE asp_payment (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    payer_account_id bigint,
    payer_name varchar(200),
    payer_presence varchar(32) NOT NULL,
    payment_mode varchar(32) NOT NULL,
    confirmation_source varchar(32) NOT NULL,
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
    CHECK (payer_presence IN ('known', 'external', 'unavailable')),
    CHECK (payment_mode IN ('free', 'offline', 'organizer_qr', 'event')),
    CHECK (confirmation_source IN ('manual', 'callback')),
    CHECK (amount >= 0),
    CHECK (status IN ('confirmed', 'reversed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_payment IS '已经确认的到账事实。未付款时不插入。冲正不是退款；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_payment.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_payment.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_payment.payer_account_id IS '付款人平台账号。不是平台账号时为空';
CREATE INDEX ix_asp_payment_4dcd39863b ON asp_payment (payer_account_id);
COMMENT ON COLUMN asp_payment.payer_name IS '实际付款人名称。外部付款人用它';
COMMENT ON COLUMN asp_payment.payer_presence IS '独立业务状态；合法值不等于业务已获批准：known external unavailable';
COMMENT ON COLUMN asp_payment.payment_mode IS '付款义务的收费路径，不表示实际渠道到账：free offline organizer_qr event';
COMMENT ON COLUMN asp_payment.confirmation_source IS '独立业务状态；合法值不等于业务已获批准：manual callback';
COMMENT ON COLUMN asp_payment.payee_subject IS '一期固定 organizer';
COMMENT ON COLUMN asp_payment.transaction_id IS '外部付款单号。人工确认可空';
COMMENT ON COLUMN asp_payment.amount IS '实际金额；人民币元，不能用浮点';
COMMENT ON COLUMN asp_payment.currency IS '币种。一期固定 CNY';
COMMENT ON COLUMN asp_payment.status IS '独立业务状态；合法值不等于业务已获批准：confirmed reversed';
COMMENT ON COLUMN asp_payment.evidence IS '确认依据。不保存支付密钥；必须按版本校验结构';
COMMENT ON COLUMN asp_payment.occurred_at IS '实际发生；有时区业务时间';
COMMENT ON COLUMN asp_payment.confirmed_at IS '确认时间；有时区业务时间';
COMMENT ON COLUMN asp_payment.request_key IS '确认幂等键';
COMMENT ON COLUMN asp_payment.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_payment.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_payment.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_payment.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_payment.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_payment.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_payment_63d8b067a7 ON asp_payment (tenant_id, request_key);
CREATE UNIQUE INDEX uq_asp_payment_46d600621b ON asp_payment (tenant_id, payee_subject, transaction_id) WHERE transaction_id IS NOT NULL;

-- D06: 付款到义务与分担的映射；支持多笔实收，超额需资金收尾，不新增资格
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
COMMENT ON TABLE asp_payment_allocation IS '付款到义务与分担的映射；支持多笔实收，超额需资金收尾，不新增资格；来源：母版 D06；事务锁定付款和义务，累计有效分配不能超过确认收款；实际超额保留原款并人工收尾，分担须属于义务。';
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

-- D06: 金额不符或第二笔真实付款。不自动结清义务
CREATE TABLE asp_payment_exception (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    payment_id bigint,
    obligation_id bigint,
    exception_type varchar(100) NOT NULL,
    external_reference varchar(200),
    reported_amount numeric(18,2),
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
    CHECK (payment_id IS NOT NULL OR obligation_id IS NOT NULL),
    CHECK (length(tenant_id) > 0),
    CHECK (reported_amount IS NULL OR reported_amount >= 0),
    CHECK (status IN ('open', 'investigating', 'resolved', 'disputed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_payment_exception IS '金额不符或第二笔真实付款。不自动结清义务；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_payment_exception.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_payment_exception.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_payment_exception.payment_id IS '已有付款。金额不符时为空';
CREATE INDEX ix_asp_payment_exception_b2f12c109c ON asp_payment_exception (tenant_id, payment_id);
COMMENT ON COLUMN asp_payment_exception.obligation_id IS '相关义务';
CREATE INDEX ix_asp_payment_exception_792aaaf7cc ON asp_payment_exception (tenant_id, obligation_id);
COMMENT ON COLUMN asp_payment_exception.exception_type IS 'amount_mismatch 或 duplicate_payment';
COMMENT ON COLUMN asp_payment_exception.external_reference IS '外部单号';
COMMENT ON COLUMN asp_payment_exception.reported_amount IS '申报金额';
COMMENT ON COLUMN asp_payment_exception.status IS '独立业务状态；合法值不等于业务已获批准：open investigating resolved disputed';
COMMENT ON COLUMN asp_payment_exception.owner_id IS '实际处理责任人';
COMMENT ON COLUMN asp_payment_exception.resolution IS '核对和处置证据；必须按版本校验结构';
COMMENT ON COLUMN asp_payment_exception.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_payment_exception.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_payment_exception.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_payment_exception.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_payment_exception.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_payment_exception.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D06: 已付款报名失效后的资金后续。平台不发起退款
CREATE TABLE asp_payment_action (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    payment_id bigint NOT NULL,
    obligation_id bigint NOT NULL,
    status varchar(32) NOT NULL,
    note varchar(1000),
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('pending', 'closed_no_refund', 'refunded')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_payment_action IS '已付款报名失效后的资金后续。平台不发起退款；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_payment_action.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_payment_action.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_payment_action.payment_id IS '已确认的付款';
CREATE INDEX ix_asp_payment_action_4ccbe23792 ON asp_payment_action (tenant_id, payment_id);
COMMENT ON COLUMN asp_payment_action.obligation_id IS '当时的义务';
CREATE INDEX ix_asp_payment_action_ffac68febf ON asp_payment_action (tenant_id, obligation_id);
COMMENT ON COLUMN asp_payment_action.status IS '独立业务状态；合法值不等于业务已获批准：pending closed_no_refund refunded';
COMMENT ON COLUMN asp_payment_action.note IS '承办方说明';
COMMENT ON COLUMN asp_payment_action.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_payment_action.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_payment_action.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_payment_action.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_payment_action.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_payment_action.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_payment_action_88dcbe3096 ON asp_payment_action (tenant_id, payment_id) WHERE status = 'pending';

-- D06: 已经发生的退款事实。不是平台发起的退款申请
CREATE TABLE asp_refund (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    payment_id bigint NOT NULL,
    allocation_id bigint,
    withdrawal_id bigint,
    applicant_account_id bigint,
    requested_amount numeric(18,2) NOT NULL,
    approved_amount numeric(18,2),
    completed_amount numeric(18,2),
    status varchar(32) NOT NULL,
    channel_reference varchar(200),
    reason varchar(1000) NOT NULL,
    request_key varchar(128) NOT NULL,
    completed_at timestamptz,
    recipient_name varchar(200),
    recipient_basis varchar(1000),
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
COMMENT ON TABLE asp_refund IS '已经发生的退款事实。不是平台发起的退款申请；来源：母版 D06；累计退款在锁定原确认付款后核对可退余额，原付款人不随队长变更；执行失败保留待办。';
COMMENT ON COLUMN asp_refund.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_refund.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_refund.payment_id IS '原实际付款';
CREATE INDEX ix_asp_refund_6c91a131df ON asp_refund (tenant_id, payment_id);
COMMENT ON COLUMN asp_refund.allocation_id IS '被退服务分配';
CREATE INDEX ix_asp_refund_4119153df3 ON asp_refund (tenant_id, allocation_id);
COMMENT ON COLUMN asp_refund.withdrawal_id IS '相关退赛';
CREATE INDEX ix_asp_refund_0889c78c72 ON asp_refund (tenant_id, withdrawal_id);
COMMENT ON COLUMN asp_refund.applicant_account_id IS '申请者。一期可空';
CREATE INDEX ix_asp_refund_9796403cc4 ON asp_refund (applicant_account_id);
COMMENT ON COLUMN asp_refund.requested_amount IS '申请金额；人民币元，不能用浮点';
COMMENT ON COLUMN asp_refund.approved_amount IS '批准金额；人民币元，不能用浮点';
COMMENT ON COLUMN asp_refund.completed_amount IS '已核实退款金额；人民币元，不能用浮点';
COMMENT ON COLUMN asp_refund.status IS '独立业务状态；合法值不等于业务已获批准：requested approved rejected executing completed failed';
COMMENT ON COLUMN asp_refund.channel_reference IS '渠道退款唯一号';
COMMENT ON COLUMN asp_refund.reason IS '规则和退款责任依据';
COMMENT ON COLUMN asp_refund.request_key IS '幂等键';
COMMENT ON COLUMN asp_refund.completed_at IS '实际退款发生时间；北京时间输入，存时区时间；有时区业务时间';
COMMENT ON COLUMN asp_refund.recipient_name IS '实际退款接收人；旧记录未采集可空';
COMMENT ON COLUMN asp_refund.recipient_basis IS '接收人变更的核验授权依据；用途受控';
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
    rule_version_id bigint,
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
COMMENT ON COLUMN asp_stage.rule_version_id IS '适用规则。手工场次的内部阶段可空，不制造虚假规则';
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
    court_name varchar(80),
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
COMMENT ON COLUMN asp_match.court_name IS '本场比赛球场名称，不表示资源预订交易';
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

-- D09: 逐现实选手按项目报到/检录；队长到场不代表全队
CREATE TABLE asp_checkin (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    event_id bigint NOT NULL,
    unit_id bigint,
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
    CHECK (check_type <> 'unit' OR (unit_id IS NOT NULL AND match_id IS NULL)),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('confirmed', 'corrected', 'rejected')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_checkin IS '逐现实选手按项目报到/检录；队长到场不代表全队；来源：母版 D09；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_checkin.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_checkin.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_checkin.event_id IS '赛事';
CREATE INDEX ix_asp_checkin_3cc20a9a3e ON asp_checkin (tenant_id, event_id);
COMMENT ON COLUMN asp_checkin.unit_id IS '赛事项目；旧赛事级记录项目未知，保留为空待核对';
CREATE INDEX ix_asp_checkin_598a27ddf1 ON asp_checkin (tenant_id, unit_id);
COMMENT ON COLUMN asp_checkin.person_id IS '实际到场人';
CREATE INDEX ix_asp_checkin_446f2cc796 ON asp_checkin (person_id);
COMMENT ON COLUMN asp_checkin.match_id IS '单场检录；项目报到为空';
CREATE INDEX ix_asp_checkin_3e9e71d86e ON asp_checkin (tenant_id, match_id);
COMMENT ON COLUMN asp_checkin.check_type IS 'unit 项目报到、event 历史赛事级报到、match 单场检录';
COMMENT ON COLUMN asp_checkin.status IS '独立业务状态；合法值不等于业务已获批准：confirmed corrected rejected';
COMMENT ON COLUMN asp_checkin.verification IS '授权核查方式及必要证据；必须按版本校验结构';
COMMENT ON COLUMN asp_checkin.occurred_at IS '现场发生时间；有时区业务时间';
COMMENT ON COLUMN asp_checkin.request_key IS '扫码/离线补录幂等键';
COMMENT ON COLUMN asp_checkin.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_checkin.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_checkin.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_checkin.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_checkin.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_checkin.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_checkin_711722409b ON asp_checkin (tenant_id, request_key);
CREATE UNIQUE INDEX uq_asp_checkin_42d54f007e ON asp_checkin (tenant_id, event_id, person_id) WHERE unit_id IS NULL AND match_id IS NULL AND status = 'confirmed';
CREATE UNIQUE INDEX uq_asp_checkin_0262f0772f ON asp_checkin (tenant_id, event_id, unit_id, person_id) WHERE unit_id IS NOT NULL AND match_id IS NULL AND status = 'confirmed';

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
    registration_id bigint,
    person_id bigint,
    team_id bigint,
    award_key varchar(64),
    category varchar(32) NOT NULL,
    title varchar(200) NOT NULL,
    source jsonb NOT NULL,
    status varchar(32) NOT NULL,
    awarded_at timestamptz NOT NULL,
    display_until timestamptz,
    applicant_account_id bigint,
    certification_status varchar(32),
    certification_details jsonb NOT NULL DEFAULT '{}'::jsonb,
    verified_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    certification_history jsonb NOT NULL DEFAULT '[]'::jsonb,
    certification_public boolean NOT NULL DEFAULT false,
    certification_worn boolean NOT NULL DEFAULT false,
    sport_id bigint,
    title_code varchar(64),
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK ((person_id IS NOT NULL) <> (team_id IS NOT NULL)),
    CHECK (jsonb_typeof(certification_details) = 'object' AND jsonb_typeof(verified_snapshot) = 'object' AND jsonb_typeof(certification_history) = 'array'),
    CHECK (certification_status IS NULL OR (certification_status IN ('draft','submitted','correction','approved','rejected','revoked') AND applicant_account_id IS NOT NULL AND person_id IS NOT NULL AND team_id IS NULL AND category = 'self_reported' AND sport_id IS NOT NULL AND ((certification_status = 'approved' AND status = 'verified' AND verified_snapshot <> '{}'::jsonb) OR (certification_status = 'revoked' AND status = 'revoked') OR (certification_status IN ('draft','submitted','correction','rejected') AND status = 'pending')))),
    CHECK (NOT certification_worn OR (certification_status = 'approved' AND status = 'verified')),
    CHECK (NOT certification_public OR (certification_status = 'approved' AND status = 'verified')),
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
COMMENT ON COLUMN asp_honor.registration_id IS '获奖报名。同一 award_key 的个人证明行属于这一条报名获奖事实';
CREATE INDEX ix_asp_honor_847eba6f19 ON asp_honor (tenant_id, registration_id);
COMMENT ON COLUMN asp_honor.person_id IS '个人获得者';
CREATE INDEX ix_asp_honor_619408751b ON asp_honor (person_id);
COMMENT ON COLUMN asp_honor.team_id IS '队伍获得者';
CREATE INDEX ix_asp_honor_8b978dd3d7 ON asp_honor (team_id);
COMMENT ON COLUMN asp_honor.award_key IS '同一条报名获奖事实的编号。双打和团体的多行个人证明共用';
COMMENT ON COLUMN asp_honor.category IS '独立业务状态；合法值不等于业务已获批准：official event achievement self_reported';
COMMENT ON COLUMN asp_honor.title IS '含项目、届次、层级和范围的名称';
COMMENT ON COLUMN asp_honor.source IS '授予或公布主体、证据和实际获奖成员快照；必须按版本校验结构';
COMMENT ON COLUMN asp_honor.status IS '独立业务状态；合法值不等于业务已获批准：pending verified suspended revised revoked';
COMMENT ON COLUMN asp_honor.awarded_at IS '获得时间；有时区业务时间';
COMMENT ON COLUMN asp_honor.display_until IS '当前展示期限；有时区业务时间';
COMMENT ON COLUMN asp_honor.applicant_account_id IS '外部荣誉申请本人账号；旧赛事及成长荣誉为空';
CREATE INDEX ix_asp_honor_8c34d5dfec ON asp_honor (applicant_account_id);
COMMENT ON COLUMN asp_honor.certification_status IS '外部荣誉认证流程 draft submitted correction approved rejected revoked；历史荣誉为空';
COMMENT ON COLUMN asp_honor.certification_details IS '本人申请事实与私有honor-proof编号；只限本人及平台审核人';
COMMENT ON COLUMN asp_honor.verified_snapshot IS '审核人独立确认的真实年份赛事项目名次及公布依据；公开投影不含证明及审核隐私';
COMMENT ON COLUMN asp_honor.certification_history IS '追加的提交与审核快照，不覆写既有历史；只限本人及平台审核人';
COMMENT ON COLUMN asp_honor.certification_public IS '本人公开同意；仅审核通过且运动名片也公开时生效';
COMMENT ON COLUMN asp_honor.certification_worn IS '本人选择佩戴的已通过认证荣誉；每人每运动最多一项';
COMMENT ON COLUMN asp_honor.sport_id IS '所属运动；历史奖项可空';
CREATE INDEX ix_asp_honor_6d1ffe4f28 ON asp_honor (sport_id);
COMMENT ON COLUMN asp_honor.title_code IS '成长称号规则编码；正式奖项可空';
COMMENT ON COLUMN asp_honor.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_honor.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_honor.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_honor.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_honor.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_honor.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_honor_c414b7dd7e ON asp_honor (tenant_id, award_key, person_id) WHERE award_key IS NOT NULL;
CREATE UNIQUE INDEX uq_asp_honor_f998040b15 ON asp_honor (tenant_id, registration_id, person_id, title) WHERE registration_id IS NOT NULL AND status = 'verified';
CREATE UNIQUE INDEX uq_asp_honor_30d9512ede ON asp_honor (tenant_id, person_id, sport_id) WHERE certification_status = 'approved' AND certification_worn;

-- D09: 报到、录分和发奖的请求幂等。不替代赛事一个人一次报到，也不替代一场一条结果
CREATE TABLE asp_execution_command (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    action varchar(32) NOT NULL,
    request_key varchar(128) NOT NULL,
    payload_hash varchar(64) NOT NULL,
    subject_type varchar(32) NOT NULL,
    subject_id bigint NOT NULL,
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
COMMENT ON TABLE asp_execution_command IS '报到、录分和发奖的请求幂等。不替代赛事一个人一次报到，也不替代一场一条结果；来源：母版 D09；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_execution_command.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_execution_command.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_execution_command.action IS '动作。checkin match result result_finalize result_import award';
COMMENT ON COLUMN asp_execution_command.request_key IS '客户端幂等键';
COMMENT ON COLUMN asp_execution_command.payload_hash IS '请求内容摘要。相同键不同摘要视为冲突';
COMMENT ON COLUMN asp_execution_command.subject_type IS '指向的事实类型';
COMMENT ON COLUMN asp_execution_command.subject_id IS '已经生效的业务事实编号';
COMMENT ON COLUMN asp_execution_command.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_execution_command.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_execution_command.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_execution_command.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_execution_command.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_execution_command.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_execution_command_5063f48fca ON asp_execution_command (tenant_id, action, request_key);

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
    sport_id bigint,
    event_id bigint,
    milestone varchar(64),
    points_delta integer NOT NULL DEFAULT 0,
    source_key varchar(160),
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
COMMENT ON COLUMN asp_growth_record.sport_id IS '成长所属运动';
CREATE INDEX ix_asp_growth_record_bd58aef41d ON asp_growth_record (sport_id);
COMMENT ON COLUMN asp_growth_record.event_id IS '来源赛事';
CREATE INDEX ix_asp_growth_record_9327126adb ON asp_growth_record (tenant_id, event_id);
COMMENT ON COLUMN asp_growth_record.milestone IS 'checkin finish team_finish 或 correction；由业务事实确定';
COMMENT ON COLUMN asp_growth_record.points_delta IS '追加的成长分变化；负值为事实纠正补偿';
COMMENT ON COLUMN asp_growth_record.source_key IS '事实唯一来源，包含被纠正原记录编号';
COMMENT ON COLUMN asp_growth_record.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_growth_record.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_growth_record.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_growth_record.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_growth_record.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_growth_record.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_growth_record_9bd557b0c8 ON asp_growth_record (tenant_id, source_key) WHERE source_key IS NOT NULL;

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

-- D04: 通用 AI 任务。按场景和业务对象记录资料、候选方案和最终业务对象，模型不直接写业务表
CREATE TABLE asp_ai_task (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    scene varchar(64) NOT NULL,
    business_object varchar(32) NOT NULL,
    organization_id bigint NOT NULL,
    initiator_account_id bigint NOT NULL,
    status varchar(32) NOT NULL,
    bailian_consent boolean NOT NULL,
    extraction jsonb,
    proposal jsonb,
    error_code varchar(64),
    error_message varchar(500),
    attempt_count integer NOT NULL DEFAULT 0,
    result_object_id bigint,
    confirm_key varchar(128),
    provider_consent boolean NOT NULL DEFAULT false,
    provider_name varchar(64) NOT NULL DEFAULT 'legacy-bailian',
    consent_version varchar(64) NOT NULL DEFAULT 'legacy',
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (bailian_consent = true OR (provider_consent = true AND provider_name = 'deepseek')),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('UPLOADED', 'PROCESSING', 'PENDING_CONFIRMATION', 'CREATED', 'FAILED', 'ABANDONED')),
    CHECK (attempt_count >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_ai_task IS '通用 AI 任务。按场景和业务对象记录资料、候选方案和最终业务对象，模型不直接写业务表；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_ai_task.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_ai_task.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_ai_task.scene IS '场景编码。首个为 event.create_from_document';
COMMENT ON COLUMN asp_ai_task.business_object IS '业务对象类型。首个为 event';
COMMENT ON COLUMN asp_ai_task.organization_id IS '发起任务的组织';
CREATE INDEX ix_asp_ai_task_bbd1b2b033 ON asp_ai_task (tenant_id, organization_id);
COMMENT ON COLUMN asp_ai_task.initiator_account_id IS '发起人平台账号。账号表无租户列，这里不建外键';
COMMENT ON COLUMN asp_ai_task.status IS '独立业务状态；合法值不等于业务已获批准：UPLOADED PROCESSING PENDING_CONFIRMATION CREATED FAILED ABANDONED';
COMMENT ON COLUMN asp_ai_task.bailian_consent IS '已同意把本次资料发给阿里云百炼';
COMMENT ON COLUMN asp_ai_task.extraction IS '本地解析出的原文块和位置。放弃任务后清空；必须按版本校验结构';
COMMENT ON COLUMN asp_ai_task.proposal IS '候选方案、来源、缺失、冲突和建议。放弃任务后清空；必须按版本校验结构';
COMMENT ON COLUMN asp_ai_task.error_code IS '失败代码。可空';
COMMENT ON COLUMN asp_ai_task.error_message IS '给操作者看的失败说明。不含密钥和堆栈';
COMMENT ON COLUMN asp_ai_task.attempt_count IS '已经执行的识别次数';
COMMENT ON COLUMN asp_ai_task.result_object_id IS '确认后写入的业务对象编号。可空，不建跨模块外键';
COMMENT ON COLUMN asp_ai_task.confirm_key IS '确认幂等键。同一任务成功后重复确认不再创建';
COMMENT ON COLUMN asp_ai_task.provider_consent IS '对当前资料任务的实际模型供应商告知确认';
COMMENT ON COLUMN asp_ai_task.provider_name IS '实际获授权供应商；旧百炼授权保留原含义';
COMMENT ON COLUMN asp_ai_task.consent_version IS '实际告知版本';
COMMENT ON COLUMN asp_ai_task.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_ai_task.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_ai_task.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_ai_task.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_ai_task.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_ai_task.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_ai_task_1e20763a6c ON asp_ai_task (tenant_id, confirm_key) WHERE confirm_key IS NOT NULL;

-- D04: AI 任务附件引用。文件本体在对象存储，用途必须是 ai-source，不能借用收款码
CREATE TABLE asp_ai_task_file (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    task_id bigint NOT NULL,
    file_id bigint NOT NULL,
    sort_order integer NOT NULL,
    media_kind varchar(32) NOT NULL,
    original_name varchar(200),
    page_count integer,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (media_kind IN ('docx', 'xlsx', 'pdf-text', 'pdf-scan', 'jpeg', 'png', 'webp')),
    CHECK (length(tenant_id) > 0),
    CHECK (sort_order >= 0),
    CHECK (page_count >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_ai_task_file IS 'AI 任务附件引用。文件本体在对象存储，用途必须是 ai-source，不能借用收款码；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_ai_task_file.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_ai_task_file.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_ai_task_file.task_id IS '所属任务';
CREATE INDEX ix_asp_ai_task_file_ae615e316c ON asp_ai_task_file (tenant_id, task_id);
COMMENT ON COLUMN asp_ai_task_file.file_id IS 'asp_file 编号。文件表无租户列，这里不建外键';
COMMENT ON COLUMN asp_ai_task_file.sort_order IS '同一任务内从 0 开始的顺序';
COMMENT ON COLUMN asp_ai_task_file.media_kind IS '嗅探后的类型：docx xlsx pdf-text pdf-scan jpeg png webp';
COMMENT ON COLUMN asp_ai_task_file.original_name IS '上传时的文件名，只用于展示';
COMMENT ON COLUMN asp_ai_task_file.page_count IS 'PDF 页数。其他类型为空';
COMMENT ON COLUMN asp_ai_task_file.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_ai_task_file.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_ai_task_file.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_ai_task_file.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_ai_task_file.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_ai_task_file.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_ai_task_file_11e0c240d1 ON asp_ai_task_file (tenant_id, task_id, sort_order);

-- D04: 模型或工具的一次调用。不保存密钥、登录令牌、资料正文和完整模型响应
CREATE TABLE asp_ai_invocation (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    task_id bigint NOT NULL,
    kind varchar(16) NOT NULL,
    tool_name varchar(64),
    model_name varchar(80),
    status varchar(32) NOT NULL,
    attempt_no integer NOT NULL DEFAULT 0,
    error_code varchar(64),
    summary jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (kind IN ('model', 'tool')),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('started', 'succeeded', 'failed', 'refused')),
    CHECK (attempt_no >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_ai_invocation IS '模型或工具的一次调用。不保存密钥、登录令牌、资料正文和完整模型响应；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_ai_invocation.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_ai_invocation.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_ai_invocation.task_id IS '所属任务';
CREATE INDEX ix_asp_ai_invocation_465b59edc7 ON asp_ai_invocation (tenant_id, task_id);
COMMENT ON COLUMN asp_ai_invocation.kind IS 'model 或 tool';
COMMENT ON COLUMN asp_ai_invocation.tool_name IS '工具名。模型调用可空';
COMMENT ON COLUMN asp_ai_invocation.model_name IS '实际请求的模型名。工具调用可空';
COMMENT ON COLUMN asp_ai_invocation.status IS '独立业务状态；合法值不等于业务已获批准：started succeeded failed refused';
COMMENT ON COLUMN asp_ai_invocation.attempt_no IS '对应任务上的第几次识别';
COMMENT ON COLUMN asp_ai_invocation.error_code IS '失败或拒绝代码';
COMMENT ON COLUMN asp_ai_invocation.summary IS '耗时毫秒和是否降级。不存资料正文；必须按版本校验结构';
COMMENT ON COLUMN asp_ai_invocation.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_ai_invocation.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_ai_invocation.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_ai_invocation.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_ai_invocation.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_ai_invocation.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D04: 赛事宣传材料，来源V021/V024；来源编号仅汇总打开次数，不关联账号
CREATE TABLE asp_event_poster (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    event_id bigint NOT NULL,
    channel_name varchar(40) NOT NULL,
    format varchar(32) NOT NULL,
    source_code varchar(16) NOT NULL,
    copy_headline varchar(80) NOT NULL DEFAULT '',
    copy_invitation varchar(300) NOT NULL DEFAULT '',
    copy_body varchar(2000) NOT NULL DEFAULT '',
    fact_digest varchar(64) NOT NULL DEFAULT '',
    link_path varchar(240) NOT NULL DEFAULT '',
    visual_file_id bigint,
    visual_subject_digest varchar(64) NOT NULL DEFAULT '',
    visual_request_digest varchar(64) NOT NULL DEFAULT '',
    visual_style varchar(24) NOT NULL DEFAULT '',
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (format IN ('wechat_group', 'moments', 'a4')),
    CHECK (visual_style IN ('', 'competitive', 'junior', 'community')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_event_poster IS '赛事宣传材料，来源V021/V024；来源编号仅汇总打开次数，不关联账号；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_event_poster.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_event_poster.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_event_poster.event_id IS '所属赛事';
CREATE INDEX ix_asp_event_poster_2f80715835 ON asp_event_poster (tenant_id, event_id);
COMMENT ON COLUMN asp_event_poster.channel_name IS '承办方渠道名称';
COMMENT ON COLUMN asp_event_poster.format IS '资料版式：wechat_group moments a4';
COMMENT ON COLUMN asp_event_poster.source_code IS '公开链接来源编号，不含个人信息';
COMMENT ON COLUMN asp_event_poster.copy_headline IS '模型生成标题，金额日期由赛事事实填入';
COMMENT ON COLUMN asp_event_poster.copy_invitation IS '模型生成邀请句';
COMMENT ON COLUMN asp_event_poster.copy_body IS '群消息或朋友圈正文，海报可为空';
COMMENT ON COLUMN asp_event_poster.fact_digest IS '生成时事实摘要，与当前赛事不符则过期';
COMMENT ON COLUMN asp_event_poster.link_path IS '已发布的公开路径含来源编号，未发布为空';
COMMENT ON COLUMN asp_event_poster.visual_file_id IS '模型生成的无字宣传主视觉，复用event-banner图片用途及组织隔离，不替换赛事封面；来源V025';
CREATE INDEX ix_asp_event_poster_6f2e5cadbd ON asp_event_poster (visual_file_id);
COMMENT ON COLUMN asp_event_poster.visual_subject_digest IS '生成时名称与运动项目摘要，变化后主视觉不可复用；来源V025';
COMMENT ON COLUMN asp_event_poster.visual_request_digest IS '名称项目受众关键词风格摘要，相同请求复用不重复生图；来源V025';
COMMENT ON COLUMN asp_event_poster.visual_style IS '主视觉风格competitive junior community，未生成为空；来源V025';
COMMENT ON COLUMN asp_event_poster.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_event_poster.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_event_poster.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_event_poster.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_event_poster.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_event_poster.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_event_poster_6804b38f56 ON asp_event_poster (tenant_id, source_code);
CREATE UNIQUE INDEX uq_asp_event_poster_c9f68599d0 ON asp_event_poster (tenant_id, event_id, channel_name);

-- D04: 宣传材料按上海日期汇总打开次数；来源V021；不记录账号、地址或浏览器标识
CREATE TABLE asp_event_poster_stat (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    poster_id bigint NOT NULL,
    stat_date date NOT NULL,
    hit_count integer NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (hit_count >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_event_poster_stat IS '宣传材料按上海日期汇总打开次数；来源V021；不记录账号、地址或浏览器标识；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_event_poster_stat.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_event_poster_stat.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_event_poster_stat.poster_id IS '所属宣传材料';
CREATE INDEX ix_asp_event_poster_stat_34cbfeb820 ON asp_event_poster_stat (tenant_id, poster_id);
COMMENT ON COLUMN asp_event_poster_stat.stat_date IS '上海时区统计日';
COMMENT ON COLUMN asp_event_poster_stat.hit_count IS '当日打开次数';
COMMENT ON COLUMN asp_event_poster_stat.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_event_poster_stat.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_event_poster_stat.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_event_poster_stat.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_event_poster_stat.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_event_poster_stat.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_event_poster_stat_d5e92612f6 ON asp_event_poster_stat (tenant_id, poster_id, stat_date);

-- D04: 历史AI网关提案账本，来源V023；不等于当前ai_task实现，不保存原文或密钥
CREATE TABLE asp_ai_gateway_task (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    organization_id bigint NOT NULL,
    domain_code varchar(64) NOT NULL,
    status varchar(32) NOT NULL,
    source_name varchar(200) NOT NULL,
    source_media_type varchar(100) NOT NULL,
    source_sha256 varchar(64) NOT NULL,
    proposal jsonb NOT NULL,
    apply_request_key varchar(128),
    event_id bigint,
    confirmed_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK ((status <> 'confirmed') OR (event_id IS NOT NULL AND confirmed_at IS NOT NULL AND apply_request_key IS NOT NULL)),
    CHECK ((status <> 'applying') OR (apply_request_key IS NOT NULL)),
    CHECK (length(tenant_id) > 0),
    CHECK (domain_code ~ '^[a-z][a-z0-9-]{0,63}$'),
    CHECK (status IN ('extracted', 'applying', 'confirmed', 'discarded')),
    CHECK (source_sha256 ~ '^[0-9a-f]{64}$'),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_ai_gateway_task IS '历史AI网关提案账本，来源V023；不等于当前ai_task实现，不保存原文或密钥；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_ai_gateway_task.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_ai_gateway_task.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_ai_gateway_task.organization_id IS '提出提案的组织';
CREATE INDEX ix_asp_ai_gateway_task_4046cbd2ed ON asp_ai_gateway_task (tenant_id, organization_id);
COMMENT ON COLUMN asp_ai_gateway_task.domain_code IS '业务域编码，域内语义由服务定义';
COMMENT ON COLUMN asp_ai_gateway_task.status IS '提案状态：extracted applying confirmed discarded';
COMMENT ON COLUMN asp_ai_gateway_task.source_name IS '上传文件名，不保存正文';
COMMENT ON COLUMN asp_ai_gateway_task.source_media_type IS '上传媒体类型';
COMMENT ON COLUMN asp_ai_gateway_task.source_sha256 IS '文件内容SHA-256摘要';
COMMENT ON COLUMN asp_ai_gateway_task.proposal IS '结构化候选、缺失项及短引用，必须校验结构';
COMMENT ON COLUMN asp_ai_gateway_task.apply_request_key IS '生成草稿的幂等键';
COMMENT ON COLUMN asp_ai_gateway_task.event_id IS '生成的赛事草稿，确认前为空';
CREATE INDEX ix_asp_ai_gateway_task_c8d07e9cef ON asp_ai_gateway_task (tenant_id, event_id);
COMMENT ON COLUMN asp_ai_gateway_task.confirmed_at IS '办赛人员确认的有时区时间；有时区业务时间';
COMMENT ON COLUMN asp_ai_gateway_task.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_ai_gateway_task.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_ai_gateway_task.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_ai_gateway_task.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_ai_gateway_task.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_ai_gateway_task.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_ai_gateway_task_91f15273e8 ON asp_ai_gateway_task (tenant_id, event_id) WHERE event_id IS NOT NULL;

-- D04: 历史网关工具调用摘要，来源V023；不记录参数、响应或原文，不表示当前路径启用
CREATE TABLE asp_ai_gateway_call (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    task_id bigint NOT NULL,
    tool_name varchar(80) NOT NULL,
    phase varchar(32) NOT NULL,
    outcome varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (phase IN ('read', 'apply')),
    CHECK (outcome IN ('ok', 'rejected')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_ai_gateway_call IS '历史网关工具调用摘要，来源V023；不记录参数、响应或原文，不表示当前路径启用；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_ai_gateway_call.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_ai_gateway_call.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_ai_gateway_call.task_id IS '所属历史提案';
CREATE INDEX ix_asp_ai_gateway_call_9695a1aaa1 ON asp_ai_gateway_call (tenant_id, task_id);
COMMENT ON COLUMN asp_ai_gateway_call.tool_name IS '业务域工具名称';
COMMENT ON COLUMN asp_ai_gateway_call.phase IS '读取或用户确认后的应用阶段：read apply';
COMMENT ON COLUMN asp_ai_gateway_call.outcome IS '工具调用结果：ok rejected';
COMMENT ON COLUMN asp_ai_gateway_call.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_ai_gateway_call.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_ai_gateway_call.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_ai_gateway_call.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_ai_gateway_call.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_ai_gateway_call.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D04: 运动下的比赛类型；人数和报名形式用于办赛、房间和报名的共同约束
CREATE TABLE asp_competition_type (
    id bigint NOT NULL,
    sport_id bigint NOT NULL,
    code varchar(64) NOT NULL,
    name varchar(100) NOT NULL,
    entry_type varchar(32) NOT NULL,
    min_members integer NOT NULL,
    max_members integer NOT NULL,
    capability_status varchar(32) NOT NULL,
    status varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (min_members > 0),
    CHECK (max_members >= min_members),
    CHECK (entry_type IN ('individual', 'pair', 'team')),
    CHECK (min_members >= 0),
    CHECK (max_members >= 0),
    CHECK (capability_status IN ('catalog', 'registration', 'manual', 'automatic', 'verified')),
    CHECK (status IN ('active', 'disabled')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_competition_type IS '运动下的比赛类型；人数和报名形式用于办赛、房间和报名的共同约束；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_competition_type.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_competition_type.sport_id IS '所属运动';
CREATE INDEX ix_asp_competition_type_171c7d41bc ON asp_competition_type (sport_id);
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
CREATE UNIQUE INDEX uq_asp_competition_type_2539bdab90 ON asp_competition_type (sport_id, code);

-- D02: 公开运动名片与真实参赛档案分开；未选择公开时只向本人及必要队友展示
CREATE TABLE asp_profile_display (
    id bigint NOT NULL,
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
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_profile_display IS '公开运动名片与真实参赛档案分开；未选择公开时只向本人及必要队友展示；来源：母版 D02；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_profile_display.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_profile_display.account_id IS '本人账号';
CREATE INDEX ix_asp_profile_display_4004d8b172 ON asp_profile_display (account_id);
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
CREATE UNIQUE INDEX uq_asp_profile_display_4004d8b172 ON asp_profile_display (account_id);

-- D03: 本场参赛房间，与长期队伍及已提交名单分开；房主计入成员人数
CREATE TABLE asp_team_room (
    id bigint NOT NULL,
    unit_id bigint NOT NULL,
    competition_type_id bigint NOT NULL,
    host_account_id bigint NOT NULL,
    team_id bigint,
    name varchar(100) NOT NULL,
    status varchar(32) NOT NULL,
    registration_id bigint,
    announcement varchar(1000),
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (status IN ('forming', 'ready', 'submitted', 'closed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_team_room IS '本场参赛房间，与长期队伍及已提交名单分开；房主计入成员人数；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_team_room.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_team_room.unit_id IS '赛事报名单元';
CREATE INDEX ix_asp_team_room_9bb197d38e ON asp_team_room (unit_id);
COMMENT ON COLUMN asp_team_room.competition_type_id IS '比赛类型';
CREATE INDEX ix_asp_team_room_78abb6d8fa ON asp_team_room (competition_type_id);
COMMENT ON COLUMN asp_team_room.host_account_id IS '当前房主';
CREATE INDEX ix_asp_team_room_41cce5f02e ON asp_team_room (host_account_id);
COMMENT ON COLUMN asp_team_room.team_id IS '可选长期代表队';
CREATE INDEX ix_asp_team_room_97d2595381 ON asp_team_room (team_id);
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

-- D03: 参赛房间成员；加入不等于本人报名声明确认
CREATE TABLE asp_team_room_member (
    id bigint NOT NULL,
    room_id bigint NOT NULL,
    unit_id bigint NOT NULL,
    account_id bigint NOT NULL,
    person_id bigint NOT NULL,
    status varchar(32) NOT NULL,
    ready boolean NOT NULL DEFAULT false,
    joined_at timestamptz NOT NULL,
    left_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (status IN ('active', 'left')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_team_room_member IS '参赛房间成员；加入不等于本人报名声明确认；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_team_room_member.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_team_room_member.room_id IS '房间';
CREATE INDEX ix_asp_team_room_member_67b5f29a62 ON asp_team_room_member (room_id);
COMMENT ON COLUMN asp_team_room_member.unit_id IS '同项目防重复参赛房间占位';
CREATE INDEX ix_asp_team_room_member_c364cb6efa ON asp_team_room_member (unit_id);
COMMENT ON COLUMN asp_team_room_member.account_id IS '成员';
CREATE INDEX ix_asp_team_room_member_5e409a13b7 ON asp_team_room_member (account_id);
COMMENT ON COLUMN asp_team_room_member.person_id IS '本人档案';
CREATE INDEX ix_asp_team_room_member_4e4cf6dc92 ON asp_team_room_member (person_id);
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
CREATE UNIQUE INDEX uq_asp_team_room_member_1a12882189 ON asp_team_room_member (room_id, account_id) WHERE status='active';
CREATE UNIQUE INDEX uq_asp_team_room_member_d047d12992 ON asp_team_room_member (unit_id, account_id) WHERE status='active';

-- D03: 缺员招募；只展示受控运动名片，不公开私有联系与材料
CREATE TABLE asp_recruitment (
    id bigint NOT NULL,
    room_id bigint NOT NULL,
    creator_account_id bigint NOT NULL,
    message varchar(500) NOT NULL,
    status varchar(32) NOT NULL,
    expires_at timestamptz NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (status IN ('open', 'filled', 'closed')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_recruitment IS '缺员招募；只展示受控运动名片，不公开私有联系与材料；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_recruitment.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_recruitment.room_id IS '招募房间';
CREATE INDEX ix_asp_recruitment_ead6f77273 ON asp_recruitment (room_id);
COMMENT ON COLUMN asp_recruitment.creator_account_id IS '发布人';
CREATE INDEX ix_asp_recruitment_753c464296 ON asp_recruitment (creator_account_id);
COMMENT ON COLUMN asp_recruitment.message IS '招募介绍';
COMMENT ON COLUMN asp_recruitment.status IS '独立业务状态；合法值不等于业务已获批准：open filled closed';
COMMENT ON COLUMN asp_recruitment.expires_at IS '招募截止；有时区业务时间';
COMMENT ON COLUMN asp_recruitment.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_recruitment.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_recruitment.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_recruitment.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_recruitment.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_recruitment.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_recruitment_bda6dcc92e ON asp_recruitment (room_id) WHERE status='open';

-- D03: 自动匹配排队意向；不占赛事正式报名名额
CREATE TABLE asp_matching_request (
    id bigint NOT NULL,
    unit_id bigint NOT NULL,
    account_id bigint NOT NULL,
    room_id bigint,
    preferences jsonb NOT NULL,
    status varchar(32) NOT NULL,
    expires_at timestamptz NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (status IN ('waiting', 'offered', 'accepted', 'cancelled', 'expired')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_matching_request IS '自动匹配排队意向；不占赛事正式报名名额；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_matching_request.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_matching_request.unit_id IS '同一报名项目';
CREATE INDEX ix_asp_matching_request_600dd02184 ON asp_matching_request (unit_id);
COMMENT ON COLUMN asp_matching_request.account_id IS '排队本人';
CREATE INDEX ix_asp_matching_request_00493307af ON asp_matching_request (account_id);
COMMENT ON COLUMN asp_matching_request.room_id IS '补充现有房间；个人匹配可空';
CREATE INDEX ix_asp_matching_request_9742c3d66f ON asp_matching_request (room_id);
COMMENT ON COLUMN asp_matching_request.preferences IS '本人选择的时间等偏好；必须按版本校验结构';
COMMENT ON COLUMN asp_matching_request.status IS '独立业务状态；合法值不等于业务已获批准：waiting offered accepted cancelled expired';
COMMENT ON COLUMN asp_matching_request.expires_at IS '意向截止；有时区业务时间';
COMMENT ON COLUMN asp_matching_request.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_matching_request.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_matching_request.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_matching_request.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_matching_request.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_matching_request.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_matching_request_6932163c00 ON asp_matching_request (unit_id, account_id) WHERE status IN ('waiting','offered');

-- D03: 匹配确认邀请；每名成员本人接受，120秒确认席位与正式报名名额分开
CREATE TABLE asp_matching_offer (
    id bigint NOT NULL,
    unit_id bigint NOT NULL,
    room_id bigint,
    status varchar(32) NOT NULL,
    expires_at timestamptz NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (status IN ('pending', 'accepted', 'declined', 'expired')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_matching_offer IS '匹配确认邀请；每名成员本人接受，120秒确认席位与正式报名名额分开；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_matching_offer.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_matching_offer.unit_id IS '报名项目';
CREATE INDEX ix_asp_matching_offer_77aae21b6b ON asp_matching_offer (unit_id);
COMMENT ON COLUMN asp_matching_offer.room_id IS '现有或接受后创建的房间';
CREATE INDEX ix_asp_matching_offer_7c52f06e1c ON asp_matching_offer (room_id);
COMMENT ON COLUMN asp_matching_offer.status IS '独立业务状态；合法值不等于业务已获批准：pending accepted declined expired';
COMMENT ON COLUMN asp_matching_offer.expires_at IS '确认期限；有时区业务时间';
COMMENT ON COLUMN asp_matching_offer.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_matching_offer.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_matching_offer.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_matching_offer.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_matching_offer.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_matching_offer.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D03: 匹配邀请的一名接收者；全部接受后才加入房间
CREATE TABLE asp_matching_offer_member (
    id bigint NOT NULL,
    offer_id bigint NOT NULL,
    account_id bigint NOT NULL,
    request_id bigint,
    status varchar(32) NOT NULL,
    answered_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (status IN ('pending', 'accepted', 'declined')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_matching_offer_member IS '匹配邀请的一名接收者；全部接受后才加入房间；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_matching_offer_member.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_matching_offer_member.offer_id IS '邀请';
CREATE INDEX ix_asp_matching_offer_member_db8fdcae2e ON asp_matching_offer_member (offer_id);
COMMENT ON COLUMN asp_matching_offer_member.account_id IS '接收人';
CREATE INDEX ix_asp_matching_offer_member_302eb57a1b ON asp_matching_offer_member (account_id);
COMMENT ON COLUMN asp_matching_offer_member.request_id IS '来源排队';
CREATE INDEX ix_asp_matching_offer_member_f86541945e ON asp_matching_offer_member (request_id);
COMMENT ON COLUMN asp_matching_offer_member.status IS '独立业务状态；合法值不等于业务已获批准：pending accepted declined';
COMMENT ON COLUMN asp_matching_offer_member.answered_at IS '本人回答时间；有时区业务时间';
COMMENT ON COLUMN asp_matching_offer_member.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_matching_offer_member.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_matching_offer_member.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_matching_offer_member.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_matching_offer_member.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_matching_offer_member.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_matching_offer_member_ce321fae43 ON asp_matching_offer_member (offer_id, account_id);

-- D03: 房间内可见欢迎与鼓励；不是社区或私聊平台
CREATE TABLE asp_room_interaction (
    id bigint NOT NULL,
    room_id bigint NOT NULL,
    account_id bigint NOT NULL,
    kind varchar(32) NOT NULL,
    text varchar(500) NOT NULL,
    request_key varchar(128) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (kind IN ('welcome', 'encourage', 'ready', 'announcement')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_room_interaction IS '房间内可见欢迎与鼓励；不是社区或私聊平台；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_room_interaction.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_room_interaction.room_id IS '房间';
CREATE INDEX ix_asp_room_interaction_5bd69eddfc ON asp_room_interaction (room_id);
COMMENT ON COLUMN asp_room_interaction.account_id IS '发送人';
CREATE INDEX ix_asp_room_interaction_a43601fbcb ON asp_room_interaction (account_id);
COMMENT ON COLUMN asp_room_interaction.kind IS '独立业务状态；合法值不等于业务已获批准：welcome encourage ready announcement';
COMMENT ON COLUMN asp_room_interaction.text IS '可见消息';
COMMENT ON COLUMN asp_room_interaction.request_key IS '防重键';
COMMENT ON COLUMN asp_room_interaction.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_room_interaction.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_room_interaction.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_room_interaction.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_room_interaction.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_room_interaction.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_room_interaction_49044ce0f8 ON asp_room_interaction (account_id, request_key);

-- D01: 政府后台账号对指定主办方的管理范围；不能由模型或普通经办人自授
CREATE TABLE asp_governance_grant (
    id bigint NOT NULL,
    sys_user_id bigint NOT NULL,
    organization_id bigint NOT NULL,
    permissions jsonb NOT NULL,
    status varchar(32) NOT NULL,
    valid_until timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (status IN ('active', 'revoked')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_governance_grant IS '政府后台账号对指定主办方的管理范围；不能由模型或普通经办人自授；来源：母版 D01；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_governance_grant.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_governance_grant.sys_user_id IS '政府若依用户编号';
COMMENT ON COLUMN asp_governance_grant.organization_id IS '指定主办方';
CREATE INDEX ix_asp_governance_grant_9046659b25 ON asp_governance_grant (organization_id);
COMMENT ON COLUMN asp_governance_grant.permissions IS '准入、资格管理、汇总和投诉权限；必须按版本校验结构';
COMMENT ON COLUMN asp_governance_grant.status IS '独立业务状态；合法值不等于业务已获批准：active revoked';
COMMENT ON COLUMN asp_governance_grant.valid_until IS '授权截止；有时区业务时间';
COMMENT ON COLUMN asp_governance_grant.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_governance_grant.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_governance_grant.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_governance_grant.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_governance_grant.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_governance_grant.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_governance_grant_b3879d9337 ON asp_governance_grant (sys_user_id, organization_id) WHERE status='active';

-- D10: 版本化成长规则；段位不是官方竞技实力评级
CREATE TABLE asp_growth_policy (
    id bigint NOT NULL,
    sport_id bigint NOT NULL,
    code varchar(64) NOT NULL,
    revision integer NOT NULL,
    rules jsonb NOT NULL,
    status varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (revision > 0),
    CHECK (revision >= 0),
    CHECK (status IN ('draft', 'active', 'superseded')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_growth_policy IS '版本化成长规则；段位不是官方竞技实力评级；来源：母版 D10；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_growth_policy.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_growth_policy.sport_id IS '所属运动';
CREATE INDEX ix_asp_growth_policy_72dce142e4 ON asp_growth_policy (sport_id);
COMMENT ON COLUMN asp_growth_policy.code IS '规则编码';
COMMENT ON COLUMN asp_growth_policy.revision IS '规则版本';
COMMENT ON COLUMN asp_growth_policy.rules IS '版本化段位门槛、奖励及称号阈值；兼容历史七、八级及当前九级；新星基础级，王者9600、传奇19200为默认门槛，可另发版本调整；必须按版本校验结构';
COMMENT ON COLUMN asp_growth_policy.status IS '独立业务状态；合法值不等于业务已获批准：draft active superseded';
COMMENT ON COLUMN asp_growth_policy.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_growth_policy.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_growth_policy.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_growth_policy.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_growth_policy.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_growth_policy.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_growth_policy_54670af7b3 ON asp_growth_policy (sport_id, code, revision);

-- D10: 由可追溯成长事实汇总的个人或队伍运动成长；可重建，不是原始事实
CREATE TABLE asp_growth_profile (
    id bigint NOT NULL,
    owner_type varchar(32) NOT NULL,
    owner_id bigint NOT NULL,
    sport_id bigint NOT NULL,
    points integer NOT NULL,
    checkin_count integer NOT NULL,
    finish_count integer NOT NULL,
    policy_version varchar(64) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (owner_type IN ('person', 'team')),
    CHECK (points >= 0),
    CHECK (checkin_count >= 0),
    CHECK (finish_count >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_growth_profile IS '由可追溯成长事实汇总的个人或队伍运动成长；可重建，不是原始事实；来源：母版 D10；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_growth_profile.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_growth_profile.owner_type IS '独立业务状态；合法值不等于业务已获批准：person team';
COMMENT ON COLUMN asp_growth_profile.owner_id IS '本人档案或长期队伍编号';
COMMENT ON COLUMN asp_growth_profile.sport_id IS '运动';
CREATE INDEX ix_asp_growth_profile_5431d8e0c8 ON asp_growth_profile (sport_id);
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
CREATE UNIQUE INDEX uq_asp_growth_profile_09683c1fb1 ON asp_growth_profile (owner_type, owner_id, sport_id);

-- D10: 本人或队长选择当前佩戴的成长称号；授予来源由荣誉事实保留
CREATE TABLE asp_title_equipment (
    id bigint NOT NULL,
    owner_type varchar(32) NOT NULL,
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
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (owner_type IN ('person', 'team')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_title_equipment IS '本人或队长选择当前佩戴的成长称号；授予来源由荣誉事实保留；来源：母版 D10；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_title_equipment.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_title_equipment.owner_type IS '独立业务状态；合法值不等于业务已获批准：person team';
COMMENT ON COLUMN asp_title_equipment.owner_id IS '本人或队伍编号';
COMMENT ON COLUMN asp_title_equipment.sport_id IS '运动';
CREATE INDEX ix_asp_title_equipment_75184f7b12 ON asp_title_equipment (sport_id);
COMMENT ON COLUMN asp_title_equipment.title_code IS '规则目录中的称号编码';
COMMENT ON COLUMN asp_title_equipment.honor_id IS '获授荣誉事实；欢迎样式可空';
CREATE INDEX ix_asp_title_equipment_ba878710fb ON asp_title_equipment (honor_id);
COMMENT ON COLUMN asp_title_equipment.frame_style IS '允许的头像边框样式';
COMMENT ON COLUMN asp_title_equipment.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_title_equipment.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_title_equipment.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_title_equipment.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_title_equipment.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_title_equipment.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_title_equipment_32b7cc75d3 ON asp_title_equipment (owner_type, owner_id, sport_id);

-- D13: 经过实现与测试的能力版本；描述不是授权
CREATE TABLE asp_capability_version (
    id bigint NOT NULL,
    code varchar(160) NOT NULL,
    revision integer NOT NULL,
    definition jsonb NOT NULL,
    source_hash varchar(64) NOT NULL,
    status varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (revision > 0),
    CHECK (revision >= 0),
    CHECK (status IN ('draft', 'tested', 'published', 'retired')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_capability_version IS '经过实现与测试的能力版本；描述不是授权；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
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
CREATE UNIQUE INDEX uq_asp_capability_version_283dedea1b ON asp_capability_version (code, revision);

-- D13: 能力在人工、Agent和系统渠道的明确开放指针
CREATE TABLE asp_capability_activation (
    id bigint NOT NULL,
    code varchar(160) NOT NULL,
    capability_version_id bigint NOT NULL,
    channel varchar(32) NOT NULL,
    enabled boolean NOT NULL DEFAULT false,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (channel IN ('ui', 'agent', 'system')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_capability_activation IS '能力在人工、Agent和系统渠道的明确开放指针；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_capability_activation.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_capability_activation.code IS '能力编码';
COMMENT ON COLUMN asp_capability_activation.capability_version_id IS '已发布版本';
CREATE INDEX ix_asp_capability_activation_907a689487 ON asp_capability_activation (capability_version_id);
COMMENT ON COLUMN asp_capability_activation.channel IS '独立业务状态；合法值不等于业务已获批准：ui agent system';
COMMENT ON COLUMN asp_capability_activation.enabled IS '允许新调用';
COMMENT ON COLUMN asp_capability_activation.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_capability_activation.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_capability_activation.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_capability_activation.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_capability_activation.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_capability_activation.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_capability_activation_43a359f141 ON asp_capability_activation (code, channel);

-- D13: 统一动作终态回执；成功与业务同事务，失败独立留痕，不存私有完整响应
CREATE TABLE asp_action_execution (
    id bigint NOT NULL,
    action_code varchar(160) NOT NULL,
    actor_type varchar(32) NOT NULL,
    actor_id bigint NOT NULL,
    tenant_scope varchar(20),
    channel varchar(16) NOT NULL,
    request_key varchar(128) NOT NULL,
    payload_hash varchar(64) NOT NULL,
    status varchar(32) NOT NULL,
    result_reference jsonb NOT NULL,
    error_code varchar(64),
    run_id bigint,
    occurred_at timestamptz NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (status IN ('succeeded', 'failed', 'denied')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_action_execution IS '统一动作终态回执；成功与业务同事务，失败独立留痕，不存私有完整响应；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
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
CREATE UNIQUE INDEX uq_asp_action_execution_c73089f01d ON asp_action_execution (actor_type, actor_id, action_code, request_key) WHERE status='succeeded';

-- D13: 智能体定义，按平台、业务域和职能分层；没有原始SQL能力
CREATE TABLE asp_agent (
    id bigint NOT NULL,
    code varchar(64) NOT NULL,
    name varchar(100) NOT NULL,
    layer varchar(32) NOT NULL,
    domain_scope varchar(32),
    status varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (layer IN ('global', 'domain', 'function')),
    CHECK (status IN ('active', 'disabled')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_agent IS '智能体定义，按平台、业务域和职能分层；没有原始SQL能力；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
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
CREATE UNIQUE INDEX uq_asp_agent_db65b3d20b ON asp_agent (code);

-- D13: 智能体提示词与模型的可追溯版本；只记录可见业务指引
CREATE TABLE asp_agent_version (
    id bigint NOT NULL,
    agent_id bigint NOT NULL,
    revision integer NOT NULL,
    model_name varchar(80) NOT NULL,
    instruction text NOT NULL,
    budget jsonb NOT NULL,
    status varchar(32) NOT NULL,
    tool_catalog jsonb NOT NULL DEFAULT '{}'::jsonb,
    skill_catalog jsonb NOT NULL DEFAULT '{}'::jsonb,
    business_map jsonb NOT NULL DEFAULT '{}'::jsonb,
    playbook_hash varchar(64) NOT NULL DEFAULT '',
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (revision > 0),
    CHECK (jsonb_typeof(tool_catalog) = 'object'),
    CHECK (jsonb_typeof(skill_catalog) = 'object'),
    CHECK (jsonb_typeof(business_map) = 'object'),
    CHECK (revision >= 0),
    CHECK (status IN ('draft', 'active', 'retired')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_agent_version IS '智能体提示词与模型的可追溯版本；只记录可见业务指引；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_agent_version.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_agent_version.agent_id IS '智能体';
CREATE INDEX ix_asp_agent_version_bc45a3950a ON asp_agent_version (agent_id);
COMMENT ON COLUMN asp_agent_version.revision IS '版本';
COMMENT ON COLUMN asp_agent_version.model_name IS '固定接口模型名';
COMMENT ON COLUMN asp_agent_version.instruction IS '可信平台提示词，不能由上传材料改写';
COMMENT ON COLUMN asp_agent_version.budget IS '深度、调用和时间预算；必须按版本校验结构';
COMMENT ON COLUMN asp_agent_version.status IS '独立业务状态；合法值不等于业务已获批准：draft active retired';
COMMENT ON COLUMN asp_agent_version.tool_catalog IS '受控MCP工具名、参数与调用方式；不能注册原始SQL、Shell或任意网络';
COMMENT ON COLUMN asp_agent_version.skill_catalog IS '可信平台技能目录与办理指引，版本化且不存模型正文或隐藏思考';
COMMENT ON COLUMN asp_agent_version.business_map IS '按角色和依赖组织的业务地图；动作可用性须实时核对注册表';
COMMENT ON COLUMN asp_agent_version.playbook_hash IS '三个目录的规范JSON摘要；与锁定智能体版本共同溯源';
COMMENT ON COLUMN asp_agent_version.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_agent_version.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_agent_version.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_agent_version.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_agent_version.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_agent_version.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_agent_version_766dffb6fe ON asp_agent_version (agent_id, revision);

-- D13: 智能体能力及委派上限；与委托人实时权限取交集
CREATE TABLE asp_agent_grant (
    id bigint NOT NULL,
    agent_id bigint NOT NULL,
    capability_code varchar(160) NOT NULL,
    scope jsonb NOT NULL,
    status varchar(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (status IN ('active', 'revoked')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_agent_grant IS '智能体能力及委派上限；与委托人实时权限取交集；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_agent_grant.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_agent_grant.agent_id IS '智能体';
CREATE INDEX ix_asp_agent_grant_d058814e58 ON asp_agent_grant (agent_id);
COMMENT ON COLUMN asp_agent_grant.capability_code IS '允许能力或delegate目标';
COMMENT ON COLUMN asp_agent_grant.scope IS '能力、组织和对象上限；必须按版本校验结构';
COMMENT ON COLUMN asp_agent_grant.status IS '独立业务状态；合法值不等于业务已获批准：active revoked';
COMMENT ON COLUMN asp_agent_grant.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_agent_grant.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_agent_grant.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_agent_grant.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_agent_grant.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_agent_grant.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE UNIQUE INDEX uq_asp_agent_grant_88d5e3d9c3 ON asp_agent_grant (agent_id, capability_code) WHERE status='active';

-- D13: 服务端签发的运行身份与进度；不保存密钥或隐藏思考
CREATE TABLE asp_agent_run (
    id bigint NOT NULL,
    agent_version_id bigint NOT NULL,
    actor_type varchar(32) NOT NULL,
    actor_id bigint NOT NULL,
    parent_run_id bigint,
    root_run_id bigint,
    scope jsonb NOT NULL,
    goal varchar(2000) NOT NULL,
    status varchar(32) NOT NULL,
    depth integer NOT NULL,
    tool_count integer NOT NULL,
    tokens_used integer NOT NULL,
    tokens_reserved integer NOT NULL,
    round_key varchar(64) NOT NULL DEFAULT '',
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
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (status IN ('running', 'waiting_children', 'waiting_input', 'waiting_confirmation', 'completed', 'failed', 'stopped')),
    CHECK (depth >= 0),
    CHECK (tool_count >= 0),
    CHECK (tokens_used >= 0),
    CHECK (tokens_reserved >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_agent_run IS '服务端签发的运行身份与进度；不保存密钥或隐藏思考；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_agent_run.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_agent_run.agent_version_id IS '锁定版本';
CREATE INDEX ix_asp_agent_run_c34bdeca1e ON asp_agent_run (agent_version_id);
COMMENT ON COLUMN asp_agent_run.actor_type IS '委托人主体类型';
COMMENT ON COLUMN asp_agent_run.actor_id IS '委托人编号';
COMMENT ON COLUMN asp_agent_run.parent_run_id IS '父运行';
COMMENT ON COLUMN asp_agent_run.root_run_id IS '根运行';
COMMENT ON COLUMN asp_agent_run.scope IS '服务器确定的对象和权限范围；必须按版本校验结构';
COMMENT ON COLUMN asp_agent_run.goal IS '用户可见目标';
COMMENT ON COLUMN asp_agent_run.status IS '独立业务状态；合法值不等于业务已获批准：running waiting_children waiting_input waiting_confirmation completed failed stopped';
COMMENT ON COLUMN asp_agent_run.depth IS '绝对委派深度';
COMMENT ON COLUMN asp_agent_run.tool_count IS '本轮已调用工具数';
COMMENT ON COLUMN asp_agent_run.tokens_used IS '供应商报告的累计用量';
COMMENT ON COLUMN asp_agent_run.tokens_reserved IS '正在执行轮次预留用量；根任务统一核对，已观察结算释放，未知超时保守计费';
COMMENT ON COLUMN asp_agent_run.round_key IS '当前预算结算轮次的单向摘要；不是身份凭据，防止旧线程释放新轮次预算';
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

-- D13: 可见模型、工具和委派步骤摘要，不包含材料正文和隐藏思考
CREATE TABLE asp_agent_step (
    id bigint NOT NULL,
    run_id bigint NOT NULL,
    sequence integer NOT NULL,
    kind varchar(32) NOT NULL,
    name varchar(160) NOT NULL,
    status varchar(32) NOT NULL,
    summary jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (sequence >= 0),
    CHECK (kind IN ('model', 'tool', 'delegate', 'confirmation', 'control')),
    CHECK (status IN ('started', 'succeeded', 'failed', 'denied')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_agent_step IS '可见模型、工具和委派步骤摘要，不包含材料正文和隐藏思考；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_agent_step.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_agent_step.run_id IS '运行';
CREATE INDEX ix_asp_agent_step_800194d51b ON asp_agent_step (run_id);
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
CREATE UNIQUE INDEX uq_asp_agent_step_410c5b62e9 ON asp_agent_step (run_id, sequence);

-- D13: 本人可恢复的可见对话；用途受控，不向其他人共享
CREATE TABLE asp_agent_message (
    id bigint NOT NULL,
    run_id bigint NOT NULL,
    role varchar(32) NOT NULL,
    content text NOT NULL,
    blocks jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (role IN ('user', 'assistant')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_agent_message IS '本人可恢复的可见对话；用途受控，不向其他人共享；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_agent_message.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_agent_message.run_id IS '运行';
CREATE INDEX ix_asp_agent_message_3a55415c04 ON asp_agent_message (run_id);
COMMENT ON COLUMN asp_agent_message.role IS '独立业务状态；合法值不等于业务已获批准：user assistant';
COMMENT ON COLUMN asp_agent_message.content IS '用户可见文本；不存密钥或隐藏思考';
COMMENT ON COLUMN asp_agent_message.blocks IS '经过校验的表单、确认、回执和跳转块；必须按版本校验结构';
COMMENT ON COLUMN asp_agent_message.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_agent_message.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_agent_message.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_agent_message.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_agent_message.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_agent_message.version IS '乐观并发版本；不替代业务规则/名单版本';

-- D13: 登录本人对特定能力、输入摘要和对象版本的一次确认
CREATE TABLE asp_action_confirmation (
    id bigint NOT NULL,
    run_id bigint,
    actor_type varchar(32) NOT NULL,
    actor_id bigint NOT NULL,
    action_code varchar(160) NOT NULL,
    payload_hash varchar(64) NOT NULL,
    object_versions jsonb NOT NULL,
    status varchar(32) NOT NULL,
    expires_at timestamptz NOT NULL,
    confirmed_at timestamptz,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (status IN ('pending', 'confirmed', 'consumed', 'expired')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_action_confirmation IS '登录本人对特定能力、输入摘要和对象版本的一次确认；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_action_confirmation.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_action_confirmation.run_id IS '关联运行';
CREATE INDEX ix_asp_action_confirmation_c3695ffd29 ON asp_action_confirmation (run_id);
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

-- D13: 投诉回复、处理与重新打开的追加记录；只向获授权当事方展示
CREATE TABLE asp_complaint_message (
    id bigint NOT NULL,
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
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_complaint_message IS '投诉回复、处理与重新打开的追加记录；只向获授权当事方展示；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_complaint_message.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_complaint_message.complaint_id IS '投诉';
CREATE INDEX ix_asp_complaint_message_df2b4cf5af ON asp_complaint_message (complaint_id);
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

-- Add foreign keys after all tables exist, including forward references.
ALTER TABLE asp_account ADD CONSTRAINT fk_asp_account_39cbbedbdb FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_login_identity ADD CONSTRAINT fk_asp_login_identity_77f45262fd FOREIGN KEY (account_id) REFERENCES asp_account (id);
ALTER TABLE asp_person ADD CONSTRAINT fk_asp_person_ef99cce6fe FOREIGN KEY (merged_into_id) REFERENCES asp_person (id);
ALTER TABLE asp_attribute_definition ADD CONSTRAINT fk_asp_attribute_definition_914b0984d9 FOREIGN KEY (sport_id) REFERENCES asp_sport (id);
ALTER TABLE asp_person_attribute ADD CONSTRAINT fk_asp_person_attribute_ba773cd5eb FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_person_attribute ADD CONSTRAINT fk_asp_person_attribute_e66e4d63bd FOREIGN KEY (attribute_id) REFERENCES asp_attribute_definition (id);
ALTER TABLE asp_consent ADD CONSTRAINT fk_asp_consent_e38cc432c1 FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_consent ADD CONSTRAINT fk_asp_consent_68623c10a7 FOREIGN KEY (actor_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_organization_application ADD CONSTRAINT fk_asp_organization_application_9b40cddf36 FOREIGN KEY (applicant_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_organization_application_version ADD CONSTRAINT fk_asp_organization_application_version_56a5b63ed9 FOREIGN KEY (application_id) REFERENCES asp_organization_application (id);
ALTER TABLE asp_account_tenant_principal ADD CONSTRAINT fk_asp_account_tenant_principal_9b72fe7744 FOREIGN KEY (account_id) REFERENCES asp_account (id);
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
ALTER TABLE asp_team_invitation ADD CONSTRAINT fk_asp_team_invitation_ff2af7a6fe FOREIGN KEY (inviter_person_id) REFERENCES asp_person (id);
ALTER TABLE asp_team_invitation ADD CONSTRAINT fk_asp_team_invitation_7d44d535b7 FOREIGN KEY (target_person_id) REFERENCES asp_person (id);
ALTER TABLE asp_team_invitation ADD CONSTRAINT fk_asp_team_invitation_e3672ea44b FOREIGN KEY (share_invitation_id) REFERENCES asp_team_invitation (id);
ALTER TABLE asp_team_history ADD CONSTRAINT fk_asp_team_history_912eca6b66 FOREIGN KEY (team_id) REFERENCES asp_team (id);
ALTER TABLE asp_team_quota ADD CONSTRAINT fk_asp_team_quota_3a6859e632 FOREIGN KEY (account_id) REFERENCES asp_account (id);
ALTER TABLE asp_event ADD CONSTRAINT fk_asp_event_ba1502a512 FOREIGN KEY (tenant_id, organization_id) REFERENCES asp_organization (tenant_id, id);
ALTER TABLE asp_event_command ADD CONSTRAINT fk_asp_event_command_b779acfd64 FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
ALTER TABLE asp_declaration_ack ADD CONSTRAINT fk_asp_declaration_ack_e94e7e6d7a FOREIGN KEY (tenant_id, registration_member_id) REFERENCES asp_registration_member (tenant_id, id);
ALTER TABLE asp_declaration_ack ADD CONSTRAINT fk_asp_declaration_ack_8ba3d6287f FOREIGN KEY (account_id) REFERENCES asp_account (id);
ALTER TABLE asp_declaration_ack ADD CONSTRAINT fk_asp_declaration_ack_1c35a2201c FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
ALTER TABLE asp_event_revision ADD CONSTRAINT fk_asp_event_revision_f1ffb3e031 FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
ALTER TABLE asp_competition_unit ADD CONSTRAINT fk_asp_competition_unit_8535df1119 FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
ALTER TABLE asp_competition_unit ADD CONSTRAINT fk_asp_competition_unit_aa7f9ddb3b FOREIGN KEY (sport_id) REFERENCES asp_sport (id);
ALTER TABLE asp_competition_unit ADD CONSTRAINT fk_asp_competition_unit_4e7aad0a16 FOREIGN KEY (competition_type_id) REFERENCES asp_competition_type (id);
ALTER TABLE asp_rule_version ADD CONSTRAINT fk_asp_rule_version_47a590e281 FOREIGN KEY (tenant_id, unit_id) REFERENCES asp_competition_unit (tenant_id, id);
ALTER TABLE asp_attribute_requirement ADD CONSTRAINT fk_asp_attribute_requirement_38802fd90c FOREIGN KEY (tenant_id, rule_version_id) REFERENCES asp_rule_version (tenant_id, id);
ALTER TABLE asp_attribute_requirement ADD CONSTRAINT fk_asp_attribute_requirement_2ef8673468 FOREIGN KEY (attribute_id) REFERENCES asp_attribute_definition (id);
ALTER TABLE asp_org_field ADD CONSTRAINT fk_asp_org_field_28200406a8 FOREIGN KEY (tenant_id, organization_id) REFERENCES asp_organization (tenant_id, id);
ALTER TABLE asp_event_field ADD CONSTRAINT fk_asp_event_field_e2b0754b6a FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
ALTER TABLE asp_event_field ADD CONSTRAINT fk_asp_event_field_eca782102f FOREIGN KEY (tenant_id, org_field_id) REFERENCES asp_org_field (tenant_id, id);
ALTER TABLE asp_entry_field_value ADD CONSTRAINT fk_asp_entry_field_value_e0df94b724 FOREIGN KEY (tenant_id, registration_member_id) REFERENCES asp_registration_member (tenant_id, id);
ALTER TABLE asp_entry_field_value ADD CONSTRAINT fk_asp_entry_field_value_89883310ed FOREIGN KEY (tenant_id, event_field_id) REFERENCES asp_event_field (tenant_id, id);
ALTER TABLE asp_material_requirement ADD CONSTRAINT fk_asp_material_requirement_e44238f2fd FOREIGN KEY (tenant_id, rule_version_id) REFERENCES asp_rule_version (tenant_id, id);
ALTER TABLE asp_event_payment_config ADD CONSTRAINT fk_asp_event_payment_config_fa5895b565 FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
ALTER TABLE asp_fee_policy ADD CONSTRAINT fk_asp_fee_policy_a1c8078315 FOREIGN KEY (tenant_id, unit_id) REFERENCES asp_competition_unit (tenant_id, id);
ALTER TABLE asp_registration_batch ADD CONSTRAINT fk_asp_registration_batch_6523f9e051 FOREIGN KEY (submitter_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_registration ADD CONSTRAINT fk_asp_registration_217fd3d0fd FOREIGN KEY (tenant_id, unit_id) REFERENCES asp_competition_unit (tenant_id, id);
ALTER TABLE asp_registration ADD CONSTRAINT fk_asp_registration_f8b0175b47 FOREIGN KEY (tenant_id, rule_version_id) REFERENCES asp_rule_version (tenant_id, id);
ALTER TABLE asp_registration ADD CONSTRAINT fk_asp_registration_a0d5d3804d FOREIGN KEY (tenant_id, fee_policy_id) REFERENCES asp_fee_policy (tenant_id, id);
ALTER TABLE asp_registration ADD CONSTRAINT fk_asp_registration_c3c2a32d6f FOREIGN KEY (tenant_id, batch_id) REFERENCES asp_registration_batch (tenant_id, id);
ALTER TABLE asp_registration ADD CONSTRAINT fk_asp_registration_34a0daff97 FOREIGN KEY (team_id) REFERENCES asp_team (id);
ALTER TABLE asp_registration ADD CONSTRAINT fk_asp_registration_ee864d6727 FOREIGN KEY (submitter_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_registration ADD CONSTRAINT fk_asp_registration_bddadcf747 FOREIGN KEY (operator_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_registration ADD CONSTRAINT fk_asp_registration_4bed8fc1f9 FOREIGN KEY (manager_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_registration_submit_key ADD CONSTRAINT fk_asp_registration_submit_key_48c5af2b13 FOREIGN KEY (tenant_id, registration_id) REFERENCES asp_registration (tenant_id, id);
ALTER TABLE asp_registration_submit_key ADD CONSTRAINT fk_asp_registration_submit_key_6abb4d96f7 FOREIGN KEY (submitter_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_registration_member ADD CONSTRAINT fk_asp_registration_member_b8c5dafa6d FOREIGN KEY (tenant_id, registration_id) REFERENCES asp_registration (tenant_id, id);
ALTER TABLE asp_registration_member ADD CONSTRAINT fk_asp_registration_member_367571c8b9 FOREIGN KEY (tenant_id, unit_id) REFERENCES asp_competition_unit (tenant_id, id);
ALTER TABLE asp_registration_member ADD CONSTRAINT fk_asp_registration_member_c3cc982e77 FOREIGN KEY (account_id) REFERENCES asp_account (id);
ALTER TABLE asp_registration_member ADD CONSTRAINT fk_asp_registration_member_ffbd266d59 FOREIGN KEY (person_id) REFERENCES asp_person (id);
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
ALTER TABLE asp_registration_payment_proof ADD CONSTRAINT fk_asp_registration_payment_proof_cfd6715645 FOREIGN KEY (tenant_id, registration_id) REFERENCES asp_registration (tenant_id, id);
ALTER TABLE asp_registration_payment_proof ADD CONSTRAINT fk_asp_registration_payment_proof_a1c013aef4 FOREIGN KEY (tenant_id, obligation_id) REFERENCES asp_fee_obligation (tenant_id, id);
ALTER TABLE asp_registration_payment_proof ADD CONSTRAINT fk_asp_registration_payment_proof_4be681417d FOREIGN KEY (uploaded_by_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_registration_payment_proof ADD CONSTRAINT fk_asp_registration_payment_proof_448352ff99 FOREIGN KEY (file_id) REFERENCES asp_file (id);
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
ALTER TABLE asp_payment_exception ADD CONSTRAINT fk_asp_payment_exception_792aaaf7cc FOREIGN KEY (tenant_id, obligation_id) REFERENCES asp_fee_obligation (tenant_id, id);
ALTER TABLE asp_payment_action ADD CONSTRAINT fk_asp_payment_action_4ccbe23792 FOREIGN KEY (tenant_id, payment_id) REFERENCES asp_payment (tenant_id, id);
ALTER TABLE asp_payment_action ADD CONSTRAINT fk_asp_payment_action_ffac68febf FOREIGN KEY (tenant_id, obligation_id) REFERENCES asp_fee_obligation (tenant_id, id);
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
ALTER TABLE asp_checkin ADD CONSTRAINT fk_asp_checkin_598a27ddf1 FOREIGN KEY (tenant_id, unit_id) REFERENCES asp_competition_unit (tenant_id, id);
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
ALTER TABLE asp_honor ADD CONSTRAINT fk_asp_honor_847eba6f19 FOREIGN KEY (tenant_id, registration_id) REFERENCES asp_registration (tenant_id, id);
ALTER TABLE asp_honor ADD CONSTRAINT fk_asp_honor_619408751b FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_honor ADD CONSTRAINT fk_asp_honor_8b978dd3d7 FOREIGN KEY (team_id) REFERENCES asp_team (id);
ALTER TABLE asp_honor ADD CONSTRAINT fk_asp_honor_8c34d5dfec FOREIGN KEY (applicant_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_honor ADD CONSTRAINT fk_asp_honor_6d1ffe4f28 FOREIGN KEY (sport_id) REFERENCES asp_sport (id);
ALTER TABLE asp_growth_record ADD CONSTRAINT fk_asp_growth_record_b8e456a801 FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_growth_record ADD CONSTRAINT fk_asp_growth_record_8fb8a219a7 FOREIGN KEY (team_id) REFERENCES asp_team (id);
ALTER TABLE asp_growth_record ADD CONSTRAINT fk_asp_growth_record_bd58aef41d FOREIGN KEY (sport_id) REFERENCES asp_sport (id);
ALTER TABLE asp_growth_record ADD CONSTRAINT fk_asp_growth_record_9327126adb FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
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
ALTER TABLE asp_ai_task ADD CONSTRAINT fk_asp_ai_task_bbd1b2b033 FOREIGN KEY (tenant_id, organization_id) REFERENCES asp_organization (tenant_id, id);
ALTER TABLE asp_ai_task_file ADD CONSTRAINT fk_asp_ai_task_file_ae615e316c FOREIGN KEY (tenant_id, task_id) REFERENCES asp_ai_task (tenant_id, id);
ALTER TABLE asp_ai_invocation ADD CONSTRAINT fk_asp_ai_invocation_465b59edc7 FOREIGN KEY (tenant_id, task_id) REFERENCES asp_ai_task (tenant_id, id);
ALTER TABLE asp_event_poster ADD CONSTRAINT fk_asp_event_poster_2f80715835 FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
ALTER TABLE asp_event_poster ADD CONSTRAINT fk_asp_event_poster_6f2e5cadbd FOREIGN KEY (visual_file_id) REFERENCES asp_file (id);
ALTER TABLE asp_event_poster_stat ADD CONSTRAINT fk_asp_event_poster_stat_34cbfeb820 FOREIGN KEY (tenant_id, poster_id) REFERENCES asp_event_poster (tenant_id, id);
ALTER TABLE asp_ai_gateway_task ADD CONSTRAINT fk_asp_ai_gateway_task_4046cbd2ed FOREIGN KEY (tenant_id, organization_id) REFERENCES asp_organization (tenant_id, id);
ALTER TABLE asp_ai_gateway_task ADD CONSTRAINT fk_asp_ai_gateway_task_c8d07e9cef FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
ALTER TABLE asp_ai_gateway_call ADD CONSTRAINT fk_asp_ai_gateway_call_9695a1aaa1 FOREIGN KEY (tenant_id, task_id) REFERENCES asp_ai_gateway_task (tenant_id, id);
ALTER TABLE asp_competition_type ADD CONSTRAINT fk_asp_competition_type_171c7d41bc FOREIGN KEY (sport_id) REFERENCES asp_sport (id);
ALTER TABLE asp_profile_display ADD CONSTRAINT fk_asp_profile_display_4004d8b172 FOREIGN KEY (account_id) REFERENCES asp_account (id);
ALTER TABLE asp_team_room ADD CONSTRAINT fk_asp_team_room_9bb197d38e FOREIGN KEY (unit_id) REFERENCES asp_competition_unit (id);
ALTER TABLE asp_team_room ADD CONSTRAINT fk_asp_team_room_78abb6d8fa FOREIGN KEY (competition_type_id) REFERENCES asp_competition_type (id);
ALTER TABLE asp_team_room ADD CONSTRAINT fk_asp_team_room_41cce5f02e FOREIGN KEY (host_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_team_room ADD CONSTRAINT fk_asp_team_room_97d2595381 FOREIGN KEY (team_id) REFERENCES asp_team (id);
ALTER TABLE asp_team_room_member ADD CONSTRAINT fk_asp_team_room_member_67b5f29a62 FOREIGN KEY (room_id) REFERENCES asp_team_room (id);
ALTER TABLE asp_team_room_member ADD CONSTRAINT fk_asp_team_room_member_c364cb6efa FOREIGN KEY (unit_id) REFERENCES asp_competition_unit (id);
ALTER TABLE asp_team_room_member ADD CONSTRAINT fk_asp_team_room_member_5e409a13b7 FOREIGN KEY (account_id) REFERENCES asp_account (id);
ALTER TABLE asp_team_room_member ADD CONSTRAINT fk_asp_team_room_member_4e4cf6dc92 FOREIGN KEY (person_id) REFERENCES asp_person (id);
ALTER TABLE asp_recruitment ADD CONSTRAINT fk_asp_recruitment_ead6f77273 FOREIGN KEY (room_id) REFERENCES asp_team_room (id);
ALTER TABLE asp_recruitment ADD CONSTRAINT fk_asp_recruitment_753c464296 FOREIGN KEY (creator_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_matching_request ADD CONSTRAINT fk_asp_matching_request_600dd02184 FOREIGN KEY (unit_id) REFERENCES asp_competition_unit (id);
ALTER TABLE asp_matching_request ADD CONSTRAINT fk_asp_matching_request_00493307af FOREIGN KEY (account_id) REFERENCES asp_account (id);
ALTER TABLE asp_matching_request ADD CONSTRAINT fk_asp_matching_request_9742c3d66f FOREIGN KEY (room_id) REFERENCES asp_team_room (id);
ALTER TABLE asp_matching_offer ADD CONSTRAINT fk_asp_matching_offer_77aae21b6b FOREIGN KEY (unit_id) REFERENCES asp_competition_unit (id);
ALTER TABLE asp_matching_offer ADD CONSTRAINT fk_asp_matching_offer_7c52f06e1c FOREIGN KEY (room_id) REFERENCES asp_team_room (id);
ALTER TABLE asp_matching_offer_member ADD CONSTRAINT fk_asp_matching_offer_member_db8fdcae2e FOREIGN KEY (offer_id) REFERENCES asp_matching_offer (id);
ALTER TABLE asp_matching_offer_member ADD CONSTRAINT fk_asp_matching_offer_member_302eb57a1b FOREIGN KEY (account_id) REFERENCES asp_account (id);
ALTER TABLE asp_matching_offer_member ADD CONSTRAINT fk_asp_matching_offer_member_f86541945e FOREIGN KEY (request_id) REFERENCES asp_matching_request (id);
ALTER TABLE asp_room_interaction ADD CONSTRAINT fk_asp_room_interaction_5bd69eddfc FOREIGN KEY (room_id) REFERENCES asp_team_room (id);
ALTER TABLE asp_room_interaction ADD CONSTRAINT fk_asp_room_interaction_a43601fbcb FOREIGN KEY (account_id) REFERENCES asp_account (id);
ALTER TABLE asp_governance_grant ADD CONSTRAINT fk_asp_governance_grant_9046659b25 FOREIGN KEY (organization_id) REFERENCES asp_organization (id);
ALTER TABLE asp_growth_policy ADD CONSTRAINT fk_asp_growth_policy_72dce142e4 FOREIGN KEY (sport_id) REFERENCES asp_sport (id);
ALTER TABLE asp_growth_profile ADD CONSTRAINT fk_asp_growth_profile_5431d8e0c8 FOREIGN KEY (sport_id) REFERENCES asp_sport (id);
ALTER TABLE asp_title_equipment ADD CONSTRAINT fk_asp_title_equipment_75184f7b12 FOREIGN KEY (sport_id) REFERENCES asp_sport (id);
ALTER TABLE asp_title_equipment ADD CONSTRAINT fk_asp_title_equipment_ba878710fb FOREIGN KEY (honor_id) REFERENCES asp_honor (id);
ALTER TABLE asp_capability_activation ADD CONSTRAINT fk_asp_capability_activation_907a689487 FOREIGN KEY (capability_version_id) REFERENCES asp_capability_version (id);
ALTER TABLE asp_agent_version ADD CONSTRAINT fk_asp_agent_version_bc45a3950a FOREIGN KEY (agent_id) REFERENCES asp_agent (id);
ALTER TABLE asp_agent_grant ADD CONSTRAINT fk_asp_agent_grant_d058814e58 FOREIGN KEY (agent_id) REFERENCES asp_agent (id);
ALTER TABLE asp_agent_run ADD CONSTRAINT fk_asp_agent_run_c34bdeca1e FOREIGN KEY (agent_version_id) REFERENCES asp_agent_version (id);
ALTER TABLE asp_agent_step ADD CONSTRAINT fk_asp_agent_step_800194d51b FOREIGN KEY (run_id) REFERENCES asp_agent_run (id);
ALTER TABLE asp_agent_message ADD CONSTRAINT fk_asp_agent_message_3a55415c04 FOREIGN KEY (run_id) REFERENCES asp_agent_run (id);
ALTER TABLE asp_action_confirmation ADD CONSTRAINT fk_asp_action_confirmation_c3695ffd29 FOREIGN KEY (run_id) REFERENCES asp_agent_run (id);
ALTER TABLE asp_complaint_message ADD CONSTRAINT fk_asp_complaint_message_df2b4cf5af FOREIGN KEY (complaint_id) REFERENCES asp_complaint (id);

COMMIT;
