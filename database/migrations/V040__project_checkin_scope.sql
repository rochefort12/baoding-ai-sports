-- User decision 2026-10-12: each competition project records its own actual attendance.
-- Do not infer the project of existing event-level rows or copy them into every project.
ALTER TABLE asp_checkin ADD COLUMN unit_id bigint;
COMMENT ON COLUMN asp_checkin.unit_id IS '赛事项目；旧赛事级记录项目未知，保留为空待核对';
COMMENT ON COLUMN asp_checkin.check_type IS 'unit 项目报到、event 历史赛事级报到、match 单场检录';
ALTER TABLE asp_checkin ADD CONSTRAINT fk_asp_checkin_598a27ddf1
    FOREIGN KEY (tenant_id, unit_id) REFERENCES asp_competition_unit (tenant_id, id);
ALTER TABLE asp_checkin ADD CONSTRAINT ck_asp_checkin_unit_scope
    CHECK (check_type <> 'unit' OR (unit_id IS NOT NULL AND match_id IS NULL));
CREATE INDEX ix_asp_checkin_598a27ddf1 ON asp_checkin (tenant_id, unit_id);
DROP INDEX uq_asp_checkin_85f7cea2f6;
CREATE UNIQUE INDEX uq_asp_checkin_42d54f007e ON asp_checkin (tenant_id, event_id, person_id)
    WHERE unit_id IS NULL AND match_id IS NULL AND status = 'confirmed';
CREATE UNIQUE INDEX uq_asp_checkin_0262f0772f ON asp_checkin (tenant_id, event_id, unit_id, person_id)
    WHERE unit_id IS NOT NULL AND match_id IS NULL AND status = 'confirmed';
