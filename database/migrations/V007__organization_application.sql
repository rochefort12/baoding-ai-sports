-- 办赛申请、申请版本和租户主体映射。组织的主体类型、主体摘要改为可空。
-- 办赛套餐只含工作台菜单，不包含系统管理。

ALTER TABLE asp_organization ALTER COLUMN subject_type DROP NOT NULL;
ALTER TABLE asp_organization ALTER COLUMN subject_hash DROP NOT NULL;
COMMENT ON TABLE asp_organization IS '承办责任主体与租户映射。本期只在办赛申请通过后创建；来源：母版 D01；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_organization.subject_type IS '企业/学校/协会/俱乐部等。本期办赛申请不采集，可空';
COMMENT ON COLUMN asp_organization.subject_hash IS '主体标识受控摘要。空摘要不互相占用';
DROP INDEX uq_asp_organization_3bf7fb149d;
CREATE UNIQUE INDEX uq_asp_organization_8a2fba9ad2 ON asp_organization (tenant_id, subject_hash) WHERE subject_hash IS NOT NULL;

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
COMMENT ON TABLE asp_organization_application IS '办赛申请。平台级数据，没有业务租户。审核只决定是否开放办赛，不表示主体已验真';
COMMENT ON COLUMN asp_organization_application.applicant_account_id IS '申请人。本期一人一份';
COMMENT ON COLUMN asp_organization_application.status IS 'draft pending approved rejected';
COMMENT ON COLUMN asp_organization_application.name IS '组织名称。草稿可空，提交必填';
COMMENT ON COLUMN asp_organization_application.contact_name IS '联系人。可以和登录用户不同。草稿可空，提交必填';
COMMENT ON COLUMN asp_organization_application.contact_cipher IS '联系方式加密值。不要求是手机号，不发送短信';
COMMENT ON COLUMN asp_organization_application.statement IS '申请说明';
COMMENT ON COLUMN asp_organization_application.file_ids IS '当前稿附件编号。结构为 fileIds 数组';
COMMENT ON COLUMN asp_organization_application.organization_id IS '通过后写入的组织编号。组织属于租户，这里不建外键';
COMMENT ON COLUMN asp_organization_application.organization_tenant_id IS '通过后的组织租户编号';
CREATE INDEX ix_asp_organization_application_9b40cddf36 ON asp_organization_application (applicant_account_id);
CREATE UNIQUE INDEX uq_asp_organization_application_9b40cddf36 ON asp_organization_application (applicant_account_id);

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
    CHECK (status IN ('pending', 'approved', 'rejected')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_organization_application_version IS '办赛申请每次提交时冻结的内容和附件。拒绝后的旧版不改';
COMMENT ON COLUMN asp_organization_application_version.application_id IS '申请';
COMMENT ON COLUMN asp_organization_application_version.revision IS '从 1 开始的提交版本';
COMMENT ON COLUMN asp_organization_application_version.file_ids IS '该版附件编号。结构为 fileIds 数组';
COMMENT ON COLUMN asp_organization_application_version.reviewer_id IS '审核人后台用户编号。只有超级管理员';
COMMENT ON COLUMN asp_organization_application_version.review_reason IS '拒绝理由。通过时可空';
CREATE INDEX ix_asp_organization_application_version_56a5b63ed9 ON asp_organization_application_version (application_id);
CREATE UNIQUE INDEX uq_asp_organization_application_version_5c7aaefaa6 ON asp_organization_application_version (application_id, revision);

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
COMMENT ON TABLE asp_account_tenant_principal IS '平台账号在一个租户里的若依用户映射。映射存在不等于可以进入组织';
COMMENT ON COLUMN asp_account_tenant_principal.account_id IS '平台账号';
COMMENT ON COLUMN asp_account_tenant_principal.tenant_id IS '组织租户编号。由服务写入和查询，不作为租户拦截条件';
COMMENT ON COLUMN asp_account_tenant_principal.sys_user_id IS '该租户内的若依用户。不是平台自然人';
CREATE INDEX ix_asp_account_tenant_principal_9b72fe7744 ON asp_account_tenant_principal (account_id);
CREATE UNIQUE INDEX uq_asp_account_tenant_principal_a7d31f54f9 ON asp_account_tenant_principal (account_id, tenant_id);
CREATE UNIQUE INDEX uq_asp_account_tenant_principal_dc518270da ON asp_account_tenant_principal (sys_user_id);

ALTER TABLE asp_organization_application ADD CONSTRAINT fk_asp_organization_application_9b40cddf36 FOREIGN KEY (applicant_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_organization_application_version ADD CONSTRAINT fk_asp_organization_application_version_56a5b63ed9 FOREIGN KEY (application_id) REFERENCES asp_organization_application (id);
ALTER TABLE asp_account_tenant_principal ADD CONSTRAINT fk_asp_account_tenant_principal_9b72fe7744 FOREIGN KEY (account_id) REFERENCES asp_account (id);

INSERT INTO sys_menu
    (menu_id, menu_name, parent_id, order_num, path, component, is_frame, is_cache,
     menu_type, visible, status, perms, icon, create_time, remark)
VALUES
    (2106100000000000013, '组织工作台', 0, 9, 'org-desk', NULL, '1', '0',
     'M', '0', '0', NULL, 'form', CURRENT_TIMESTAMP,
     '进入组织后的工作台。不是系统管理菜单。'),
    (2106100000000000014, '办赛概览', 2106100000000000013, 1, 'home', 'sports/organization/desk', '1', '0',
     'C', '0', '0', 'sports:organization:desk', 'form', CURRENT_TIMESTAMP,
     '已开放办赛。本期不能发布赛事。'),
    (2106100000000000015, '办赛审核', 0, 10, 'organization-review', NULL, '1', '0',
     'M', '0', '0', NULL, 'form', CURRENT_TIMESTAMP,
     '只有超级管理员使用。不放进办赛组织套餐。'),
    (2106100000000000016, '待审申请', 2106100000000000015, 1, 'index', 'sports/organization/review', '1', '0',
     'C', '0', '0', 'sports:organization:review', 'form', CURRENT_TIMESTAMP,
     '通过或拒绝办赛申请。');

INSERT INTO sys_tenant_package
    (package_id, package_name, menu_ids, remark, status, del_flag, create_time)
VALUES
    (2106100000000000012, '办赛组织', '2106100000000000013,2106100000000000014',
     '只含办赛概览。不是系统管理套餐。一期所有者角色仍投影为租户管理员。',
     '0', '0', CURRENT_TIMESTAMP);
