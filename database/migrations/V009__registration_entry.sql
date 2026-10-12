-- M1.4 报名。不改写已应用迁移。名额按整单，成员确认单独成行。

DO $$
DECLARE
    constraint_name text;
BEGIN
    SELECT con.conname INTO constraint_name
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    WHERE rel.relname = 'asp_registration'
      AND con.contype = 'c'
      AND pg_get_constraintdef(con.oid) LIKE '%pre_registered%';
    IF constraint_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE asp_registration DROP CONSTRAINT %I', constraint_name);
    END IF;

    SELECT con.conname INTO constraint_name
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    WHERE rel.relname = 'asp_capacity_pool'
      AND con.contype = 'c'
      AND pg_get_constraintdef(con.oid) LIKE '%capacity_unit%';
    IF constraint_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE asp_capacity_pool DROP CONSTRAINT %I', constraint_name);
    END IF;
END $$;

ALTER TABLE asp_registration ALTER COLUMN rule_version_id DROP NOT NULL;
ALTER TABLE asp_registration ALTER COLUMN submitted_at DROP NOT NULL;
ALTER TABLE asp_registration ADD CONSTRAINT ck_asp_registration_status
    CHECK (status IN ('draft', 'submitted', 'approved', 'rejected'));
COMMENT ON TABLE asp_registration IS '竞赛单元报名。草稿不占名额；已提交和已通过占名额；撤回回到草稿';
COMMENT ON COLUMN asp_registration.rule_version_id IS '提交时规则。本期可空，不临时造规则版本';
COMMENT ON COLUMN asp_registration.status IS 'draft submitted approved rejected。撤回回到草稿';
COMMENT ON COLUMN asp_registration.hold_expires_at IS '旧的临时占位期限。本期不使用';
COMMENT ON COLUMN asp_registration.submitted_at IS '实际提交时间。草稿可空';

CREATE UNIQUE INDEX uq_asp_registration_f61f3032ee
    ON asp_registration (tenant_id, unit_id, submitter_account_id);

ALTER TABLE asp_roster_version ALTER COLUMN rule_version_id DROP NOT NULL;
COMMENT ON COLUMN asp_roster_version.rule_version_id IS '核验规则。本期报名可空';

ALTER TABLE asp_capacity_pool ADD CONSTRAINT ck_asp_capacity_pool_unit
    CHECK (capacity_unit IN ('person', 'pair', 'team', 'seat', 'lane', 'entry'));
CREATE UNIQUE INDEX uq_asp_capacity_pool_a5e7dacf0b
    ON asp_capacity_pool (tenant_id, unit_id)
    WHERE unit_id IS NOT NULL AND capacity_unit = 'entry';
COMMENT ON COLUMN asp_capacity_pool.capacity_unit IS '容量单位。M1.4 报名使用 entry';
COMMENT ON COLUMN asp_capacity_pool.dedupe_scope IS '计数去重范围。M1.4 按 entry 整单计数';

COMMENT ON COLUMN asp_event.registration_opens_at IS '报名开始。报名是否接受以报名流程为准，时间记在赛事上';
COMMENT ON COLUMN asp_event.registration_closes_at IS '报名结束。报名是否接受以报名流程为准，时间记在赛事上';

CREATE TABLE asp_registration_member (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    registration_id bigint NOT NULL,
    unit_id bigint NOT NULL,
    account_id bigint NOT NULL,
    person_id bigint,
    status varchar(32) NOT NULL,
    self_member boolean NOT NULL DEFAULT false,
    invite_token varchar(64),
    person_snapshot jsonb,
    occupying boolean NOT NULL DEFAULT false,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (occupying = false OR status = 'confirmed'),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('pending_confirmation', 'confirmed', 'declined')),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_registration_member IS '报名成员确认。按平台账号记录，提交成功后才抄入名单快照';
COMMENT ON COLUMN asp_registration_member.registration_id IS '报名';
COMMENT ON COLUMN asp_registration_member.unit_id IS '竞赛单元。冗余，用于同一人同一单元只有一条有效报名';
COMMENT ON COLUMN asp_registration_member.account_id IS '成员平台账号';
COMMENT ON COLUMN asp_registration_member.person_id IS '确认时的本人档案。待确认时可空';
COMMENT ON COLUMN asp_registration_member.status IS 'pending_confirmation confirmed declined';
COMMENT ON COLUMN asp_registration_member.self_member IS 'true 表示报名提交人本人';
COMMENT ON COLUMN asp_registration_member.invite_token IS '邀请确认令牌。本人成员为空';
COMMENT ON COLUMN asp_registration_member.person_snapshot IS '确认时抄下的档案。提交名单时使用，之后改档案不回写';
COMMENT ON COLUMN asp_registration_member.occupying IS 'true 表示这条成员正在占用该单元的有效报名';
CREATE INDEX ix_asp_registration_member_b8c5dafa6d ON asp_registration_member (tenant_id, registration_id);
CREATE INDEX ix_asp_registration_member_367571c8b9 ON asp_registration_member (tenant_id, unit_id);
CREATE INDEX ix_asp_registration_member_c3cc982e77 ON asp_registration_member (account_id);
CREATE INDEX ix_asp_registration_member_ffbd266d59 ON asp_registration_member (person_id);
CREATE UNIQUE INDEX uq_asp_registration_member_8696a1f9b7 ON asp_registration_member (tenant_id, registration_id, account_id);
CREATE UNIQUE INDEX uq_asp_registration_member_6da214a13c ON asp_registration_member (tenant_id, unit_id, account_id) WHERE occupying = true;
CREATE UNIQUE INDEX uq_asp_registration_member_95aaf903f1 ON asp_registration_member (tenant_id, invite_token) WHERE invite_token IS NOT NULL;
ALTER TABLE asp_registration_member ADD CONSTRAINT fk_asp_registration_member_b8c5dafa6d FOREIGN KEY (tenant_id, registration_id) REFERENCES asp_registration (tenant_id, id);
ALTER TABLE asp_registration_member ADD CONSTRAINT fk_asp_registration_member_367571c8b9 FOREIGN KEY (tenant_id, unit_id) REFERENCES asp_competition_unit (tenant_id, id);
ALTER TABLE asp_registration_member ADD CONSTRAINT fk_asp_registration_member_c3cc982e77 FOREIGN KEY (account_id) REFERENCES asp_account (id);
ALTER TABLE asp_registration_member ADD CONSTRAINT fk_asp_registration_member_ffbd266d59 FOREIGN KEY (person_id) REFERENCES asp_person (id);

INSERT INTO asp_sport (id, code, name, rule_family, capability_status, status, create_time, update_time, version)
SELECT 2106100000000000020, 'badminton', '羽毛球', '对抗', 'registration', 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0
WHERE NOT EXISTS (SELECT 1 FROM asp_sport WHERE code = 'badminton');

INSERT INTO sys_menu
    (menu_id, menu_name, parent_id, order_num, path, component, is_frame, is_cache,
     menu_type, visible, status, perms, icon, create_time, remark)
VALUES
    (2106100000000000018, '报名审核', 2106100000000000013, 3, 'registrations', 'sports/registration/review', '1', '0',
     'C', '0', '0', 'sports:registration:review', 'peoples', CURRENT_TIMESTAMP,
     '组织内的竞赛单元和整单报名审核。不看付款。');

UPDATE sys_tenant_package
SET menu_ids = menu_ids || ',2106100000000000018'
WHERE package_id = 2106100000000000012
  AND position('2106100000000000018' in menu_ids) = 0;

INSERT INTO sys_role_menu (role_id, menu_id)
SELECT DISTINCT rm.role_id, 2106100000000000018
FROM sys_role_menu rm
WHERE rm.menu_id = 2106100000000000014
  AND NOT EXISTS (
      SELECT 1 FROM sys_role_menu existing
      WHERE existing.role_id = rm.role_id AND existing.menu_id = 2106100000000000018
  );
