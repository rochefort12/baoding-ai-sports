-- 组织字段目录、赛事选用和报名填写。不迁移旧的平台属性三表。
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
ALTER TABLE asp_org_field ADD CONSTRAINT fk_asp_org_field_28200406a8 FOREIGN KEY (tenant_id, organization_id) REFERENCES asp_organization (tenant_id, id);
ALTER TABLE asp_event_field ADD CONSTRAINT fk_asp_event_field_e2b0754b6a FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
ALTER TABLE asp_event_field ADD CONSTRAINT fk_asp_event_field_eca782102f FOREIGN KEY (tenant_id, org_field_id) REFERENCES asp_org_field (tenant_id, id);
ALTER TABLE asp_entry_field_value ADD CONSTRAINT fk_asp_entry_field_value_e0df94b724 FOREIGN KEY (tenant_id, registration_member_id) REFERENCES asp_registration_member (tenant_id, id);
ALTER TABLE asp_entry_field_value ADD CONSTRAINT fk_asp_entry_field_value_89883310ed FOREIGN KEY (tenant_id, event_field_id) REFERENCES asp_event_field (tenant_id, id);
