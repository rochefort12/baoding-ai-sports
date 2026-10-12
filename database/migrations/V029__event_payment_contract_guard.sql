-- V028已应用不可重写：JSON必需字段显式存在，避免CHECK的NULL结果放过缺少schemaVersion或channels的对象。
DO $$
DECLARE item record;
BEGIN
    FOR item IN
      SELECT c.conname FROM pg_constraint c JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=ANY(c.conkey)
      WHERE c.conrelid='asp_event_payment_config'::regclass AND c.contype='c' AND cardinality(c.conkey)=1 AND a.attname='settings'
    LOOP
      EXECUTE format('ALTER TABLE asp_event_payment_config DROP CONSTRAINT %I', item.conname);
    END LOOP;
END $$;
ALTER TABLE asp_event_payment_config ADD CONSTRAINT asp_event_payment_settings_contract_check CHECK (jsonb_typeof(settings) = 'object' AND settings ? 'schemaVersion' AND settings->>'schemaVersion' = '1' AND settings ? 'channels' AND jsonb_typeof(settings->'channels') = 'array');
COMMENT ON COLUMN asp_fee_obligation.quote_snapshot IS '当次提交的整单金额、方式和说明；统一收款含paymentSettings渠道及二维码文件编号快照，账户仅授权付款用途可见，不随配置改变；必须按版本校验结构';
