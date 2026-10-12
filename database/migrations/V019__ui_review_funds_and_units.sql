-- 用户 2026-10-08 确认：该测试赛事的既有重名项目按序号区分，保留所有关联。
-- 仅处理已确认的测试赛事/项目，不改其他组织名称；唯一索引失败时整个迁移回滚。
DO $$
DECLARE item record; suffix integer := 2; proposed text;
BEGIN
  FOR item IN SELECT id FROM asp_competition_unit
    WHERE tenant_id = '001493' AND event_id = 2107839247288483841 AND name = '测试双打-1' AND status = 'open'
    ORDER BY id OFFSET 1
  LOOP
    LOOP
      proposed := '测试双打-1（' || suffix || '）';
      suffix := suffix + 1;
      EXIT WHEN NOT EXISTS (SELECT 1 FROM asp_competition_unit WHERE tenant_id = '001493' AND event_id = 2107839247288483841 AND lower(btrim(name)) = lower(proposed) AND status = 'open');
    END LOOP;
    UPDATE asp_competition_unit SET name = proposed, version = version + 1 WHERE id = item.id;
  END LOOP;
END $$;
-- 同赛事有效项目唯一；已应用迁移保持原样。重复名称若已存在须先人工一般更正，不自动改名。
CREATE UNIQUE INDEX uq_unit_event_display_name ON asp_competition_unit (tenant_id, event_id, lower(btrim(name))) WHERE status = 'open';
ALTER TABLE asp_refund ADD COLUMN recipient_name varchar(200);
ALTER TABLE asp_refund ADD COLUMN recipient_basis varchar(1000);
COMMENT ON COLUMN asp_refund.recipient_name IS '实际退款接收人；旧事实未采集可空，不推断补造';
COMMENT ON COLUMN asp_refund.recipient_basis IS '与原付款人不同的核验授权依据，限资金用途访问';
