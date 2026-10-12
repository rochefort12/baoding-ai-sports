-- 赛事统一静态收款渠道；不重写既有收费版本和义务快照，无真实支付网关。
-- 金额仍在项目，旧 offline/organizer_qr 供历史记录兼容。新提交有赛事配置时复制统一指引。
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
    CHECK (jsonb_typeof(settings) = 'object' AND settings->>'schemaVersion' = '1' AND jsonb_typeof(settings->'channels') = 'array'),
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
ALTER TABLE asp_event_payment_config ADD CONSTRAINT fk_asp_event_payment_config_fa5895b565 FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
DO $$
DECLARE item record;
BEGIN
    FOR item IN
      SELECT c.conrelid::regclass AS table_name, c.conname
      FROM pg_constraint c JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=ANY(c.conkey)
      WHERE c.conrelid IN ('asp_fee_policy'::regclass, 'asp_payment'::regclass)
        AND c.contype='c' AND cardinality(c.conkey)=1 AND a.attname='payment_mode'
    LOOP
      EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', item.table_name, item.conname);
    END LOOP;
END $$;
ALTER TABLE asp_fee_policy ADD CONSTRAINT asp_fee_policy_payment_mode_allowed_check CHECK (payment_mode IS NULL OR payment_mode IN ('free','offline','organizer_qr','event'));
ALTER TABLE asp_payment ADD CONSTRAINT asp_payment_payment_mode_allowed_check CHECK (payment_mode IN ('free','offline','organizer_qr','event'));
COMMENT ON COLUMN asp_fee_policy.payment_mode IS 'free免费；event赛事统一渠道；offline/organizer_qr保留旧收费及历史付款依据。草稿可空';
COMMENT ON COLUMN asp_payment.payment_mode IS '付款义务的收费路径，不表示实际到账：free offline organizer_qr event';
