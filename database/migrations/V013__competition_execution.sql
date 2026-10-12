-- M1.7 报到、手工场次、录分和获奖证明。不制造虚假竞赛规则。个人证明行用 award_key 追溯同一条报名获奖事实。

ALTER TABLE asp_stage ALTER COLUMN rule_version_id DROP NOT NULL;
COMMENT ON COLUMN asp_stage.rule_version_id IS '适用规则。手工场次的内部阶段可空，不制造虚假规则';

CREATE UNIQUE INDEX uq_asp_checkin_85f7cea2f6 ON asp_checkin (tenant_id, event_id, person_id) WHERE match_id IS NULL AND status = 'confirmed';

ALTER TABLE asp_honor ADD COLUMN registration_id bigint;
ALTER TABLE asp_honor ADD COLUMN award_key varchar(64);
COMMENT ON COLUMN asp_honor.registration_id IS '获奖报名。同一 award_key 的个人证明行属于这一条报名获奖事实';
COMMENT ON COLUMN asp_honor.award_key IS '同一条报名获奖事实的编号。双打和团体的多行个人证明共用';
CREATE INDEX ix_asp_honor_847eba6f19 ON asp_honor (tenant_id, registration_id);
ALTER TABLE asp_honor ADD CONSTRAINT fk_asp_honor_847eba6f19 FOREIGN KEY (tenant_id, registration_id) REFERENCES asp_registration (tenant_id, id);
CREATE UNIQUE INDEX uq_asp_honor_c414b7dd7e ON asp_honor (tenant_id, award_key, person_id) WHERE award_key IS NOT NULL;
CREATE UNIQUE INDEX uq_asp_honor_f998040b15 ON asp_honor (tenant_id, registration_id, person_id, title) WHERE registration_id IS NOT NULL AND status = 'verified';

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
COMMENT ON TABLE asp_execution_command IS '报到、录分和发奖的请求幂等。不替代赛事一个人一次报到，也不替代一场一条结果';
COMMENT ON COLUMN asp_execution_command.payload_hash IS '请求内容摘要。相同键不同摘要视为冲突';
CREATE UNIQUE INDEX uq_asp_execution_command_5063f48fca ON asp_execution_command (tenant_id, action, request_key);

INSERT INTO sys_menu
    (menu_id, menu_name, parent_id, order_num, path, component, is_frame, is_cache,
     menu_type, visible, status, perms, icon, create_time, remark)
VALUES
    (2106100000000000021, '报到录分', 2106100000000000013, 5, 'competition', 'sports/competition/index', '1', '0',
     'C', '0', '0', 'sports:competition:manage', 'form', CURRENT_TIMESTAMP,
     '赛事报到、手工场次、录分和获奖。不抽签，不改正式结果。');

UPDATE sys_tenant_package
SET menu_ids = menu_ids || ',2106100000000000021'
WHERE package_id = 2106100000000000012
  AND position('2106100000000000021' in menu_ids) = 0;

INSERT INTO sys_role_menu (role_id, menu_id)
SELECT DISTINCT rm.role_id, 2106100000000000021
FROM sys_role_menu rm
WHERE rm.menu_id = 2106100000000000014
  AND NOT EXISTS (
      SELECT 1 FROM sys_role_menu existing
      WHERE existing.role_id = rm.role_id AND existing.menu_id = 2106100000000000021
  );
