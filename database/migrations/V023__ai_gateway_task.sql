-- 已应用的 AI 办赛提案表。原文件在后续编辑中被覆盖，本文件按当时已经落库的结构回写。
-- 不重新执行这两张表。账本校验和按回写文件更正。

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
    CHECK (domain_code ~ '^[a-z][a-z0-9-]{0,63}$'),
    CHECK (source_sha256 ~ '^[0-9a-f]{64}$'),
    CHECK (status IN ('extracted', 'applying', 'confirmed', 'discarded')),
    CHECK (length(tenant_id) > 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_ai_gateway_task IS 'AI 办赛提案。确认前不是赛事。确认后只引用赛事服务已经创建的草稿。不保存上传原文、证件号和模型密钥';
COMMENT ON COLUMN asp_ai_gateway_task.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_ai_gateway_task.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_ai_gateway_task.organization_id IS '提出提案的办赛组织';
COMMENT ON COLUMN asp_ai_gateway_task.domain_code IS '业务域编码。各域自带提示词和工具说明，账本不解释域内含义';
COMMENT ON COLUMN asp_ai_gateway_task.status IS '提案状态。applying 表示正在生成草稿，同一请求键可以重试：extracted applying confirmed discarded';
COMMENT ON COLUMN asp_ai_gateway_task.source_name IS '上传文件名。不保存文件正文';
COMMENT ON COLUMN asp_ai_gateway_task.source_media_type IS '上传文件媒体类型';
COMMENT ON COLUMN asp_ai_gateway_task.source_sha256 IS '文件内容 SHA-256。用于识别同一份资料，不保存原文';
COMMENT ON COLUMN asp_ai_gateway_task.proposal IS '待确认提案。只含赛事字段、竞赛项目、缺失项和短引用；必须按版本校验结构';
COMMENT ON COLUMN asp_ai_gateway_task.apply_request_key IS '生成草稿的幂等键。同一键重复提交不新建赛事';
COMMENT ON COLUMN asp_ai_gateway_task.event_id IS '已经生成的赛事草稿。确认前为空';
COMMENT ON COLUMN asp_ai_gateway_task.confirmed_at IS '办赛人员确认时间；有时区业务时间';
COMMENT ON COLUMN asp_ai_gateway_task.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_ai_gateway_task.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_ai_gateway_task.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_ai_gateway_task.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_ai_gateway_task.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_ai_gateway_task.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE INDEX ix_asp_ai_gateway_task_4046cbd2ed ON asp_ai_gateway_task (tenant_id, organization_id);
CREATE INDEX ix_asp_ai_gateway_task_c8d07e9cef ON asp_ai_gateway_task (tenant_id, event_id);
CREATE UNIQUE INDEX uq_asp_ai_gateway_task_91f15273e8 ON asp_ai_gateway_task (tenant_id, event_id) WHERE event_id IS NOT NULL;

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
    CHECK (outcome IN ('ok', 'rejected')),
    CHECK (phase IN ('read', 'apply')),
    CHECK (length(tenant_id) > 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_ai_gateway_call IS 'AI 工具调用留痕。只记录工具名、阶段和成败，不记录参数、响应和原文';
COMMENT ON COLUMN asp_ai_gateway_call.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_ai_gateway_call.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_ai_gateway_call.task_id IS '所属提案';
COMMENT ON COLUMN asp_ai_gateway_call.tool_name IS '工具名，与业务域工具说明一致';
COMMENT ON COLUMN asp_ai_gateway_call.phase IS 'read 只发生在确认前；apply 只发生在用户确认之后：read apply';
COMMENT ON COLUMN asp_ai_gateway_call.outcome IS '工具是否按允许的方式完成：ok rejected';
COMMENT ON COLUMN asp_ai_gateway_call.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_ai_gateway_call.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_ai_gateway_call.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_ai_gateway_call.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_ai_gateway_call.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_ai_gateway_call.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE INDEX ix_asp_ai_gateway_call_9695a1aaa1 ON asp_ai_gateway_call (tenant_id, task_id);

ALTER TABLE asp_ai_gateway_task ADD CONSTRAINT fk_asp_ai_gateway_task_4046cbd2ed FOREIGN KEY (tenant_id, organization_id) REFERENCES asp_organization (tenant_id, id);
ALTER TABLE asp_ai_gateway_task ADD CONSTRAINT fk_asp_ai_gateway_task_c8d07e9cef FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
ALTER TABLE asp_ai_gateway_call ADD CONSTRAINT fk_asp_ai_gateway_call_9695a1aaa1 FOREIGN KEY (tenant_id, task_id) REFERENCES asp_ai_gateway_task (tenant_id, id);
