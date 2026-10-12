-- V027 可选付款凭证，金融私有材料；模型源 catalog.py。
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
ALTER TABLE asp_registration_payment_proof ADD CONSTRAINT fk_asp_registration_payment_proof_cfd6715645 FOREIGN KEY (tenant_id, registration_id) REFERENCES asp_registration (tenant_id, id);
ALTER TABLE asp_registration_payment_proof ADD CONSTRAINT fk_asp_registration_payment_proof_a1c013aef4 FOREIGN KEY (tenant_id, obligation_id) REFERENCES asp_fee_obligation (tenant_id, id);
ALTER TABLE asp_registration_payment_proof ADD CONSTRAINT fk_asp_registration_payment_proof_4be681417d FOREIGN KEY (uploaded_by_account_id) REFERENCES asp_account (id);
ALTER TABLE asp_registration_payment_proof ADD CONSTRAINT fk_asp_registration_payment_proof_448352ff99 FOREIGN KEY (file_id) REFERENCES asp_file (id);
