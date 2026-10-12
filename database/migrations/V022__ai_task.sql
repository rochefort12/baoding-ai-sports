-- 通用 AI 任务、附件引用和调用记录。不改 V001-V020。
-- 外键只连同租户的组织和任务。文件编号不建外键，避免把共享文件表当成业务授权。

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
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (bailian_consent = true),
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

ALTER TABLE asp_ai_task ADD CONSTRAINT fk_asp_ai_task_bbd1b2b033 FOREIGN KEY (tenant_id, organization_id) REFERENCES asp_organization (tenant_id, id);
ALTER TABLE asp_ai_task_file ADD CONSTRAINT fk_asp_ai_task_file_ae615e316c FOREIGN KEY (tenant_id, task_id) REFERENCES asp_ai_task (tenant_id, id);
ALTER TABLE asp_ai_invocation ADD CONSTRAINT fk_asp_ai_invocation_465b59edc7 FOREIGN KEY (tenant_id, task_id) REFERENCES asp_ai_task (tenant_id, id);

