-- M1.6 收费记账。不改写已应用迁移。义务和到账分开，付款人可以不是平台账号。

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM asp_fee_policy)
        OR EXISTS (SELECT 1 FROM asp_fee_obligation)
        OR EXISTS (SELECT 1 FROM asp_payment) THEN
        RAISE EXCEPTION 'V011 requires asp_fee_policy, asp_fee_obligation and asp_payment to be empty';
    END IF;
END $$;

DO $$
DECLARE
    constraint_name text;
BEGIN
    FOR constraint_name IN
        SELECT con.conname
        FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        WHERE rel.relname = 'asp_fee_policy'
          AND con.contype = 'c'
          AND (
              pg_get_constraintdef(con.oid) LIKE '%pricing_unit%'
              OR pg_get_constraintdef(con.oid) LIKE '%status%'
          )
          AND pg_get_constraintdef(con.oid) NOT LIKE '%version%'
    LOOP
        EXECUTE format('ALTER TABLE asp_fee_policy DROP CONSTRAINT %I', constraint_name);
    END LOOP;

    FOR constraint_name IN
        SELECT con.conname
        FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        WHERE rel.relname = 'asp_fee_obligation'
          AND con.contype = 'c'
          AND pg_get_constraintdef(con.oid) LIKE '%status%'
          AND pg_get_constraintdef(con.oid) NOT LIKE '%version%'
    LOOP
        EXECUTE format('ALTER TABLE asp_fee_obligation DROP CONSTRAINT %I', constraint_name);
    END LOOP;

    FOR constraint_name IN
        SELECT con.conname
        FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        WHERE rel.relname = 'asp_payment'
          AND con.contype = 'c'
          AND pg_get_constraintdef(con.oid) LIKE '%status%'
          AND pg_get_constraintdef(con.oid) NOT LIKE '%version%'
    LOOP
        EXECUTE format('ALTER TABLE asp_payment DROP CONSTRAINT %I', constraint_name);
    END LOOP;
END $$;

ALTER TABLE asp_fee_policy ADD COLUMN amount numeric(18,2);
ALTER TABLE asp_fee_policy ADD COLUMN payment_mode varchar(32);
ALTER TABLE asp_fee_policy ADD COLUMN pay_instruction varchar(1000);
ALTER TABLE asp_fee_policy ADD COLUMN qr_file_id bigint;
ALTER TABLE asp_fee_policy ADD CONSTRAINT ck_asp_fee_policy_pricing_unit
    CHECK (pricing_unit IN ('free', 'person', 'pair', 'team', 'project', 'combination', 'entry'));
ALTER TABLE asp_fee_policy ADD CONSTRAINT ck_asp_fee_policy_amount
    CHECK (amount IS NULL OR amount >= 0);
ALTER TABLE asp_fee_policy ADD CONSTRAINT ck_asp_fee_policy_payment_mode
    CHECK (payment_mode IS NULL OR payment_mode IN ('free', 'offline', 'organizer_qr'));
ALTER TABLE asp_fee_policy ADD CONSTRAINT ck_asp_fee_policy_status
    CHECK (status IN ('draft', 'active', 'retired'));
ALTER TABLE asp_fee_policy ADD CONSTRAINT ck_asp_fee_policy_active
    CHECK (status <> 'active' OR (amount IS NOT NULL AND payment_mode IS NOT NULL AND ((payment_mode = 'free' AND amount = 0) OR (payment_mode <> 'free' AND amount > 0))));
CREATE UNIQUE INDEX uq_asp_fee_policy_8d57190dfe ON asp_fee_policy (tenant_id, unit_id) WHERE status = 'active';

ALTER TABLE asp_fee_obligation ADD CONSTRAINT ck_asp_fee_obligation_status
    CHECK (status IN ('not_required', 'open', 'settled', 'void'));
CREATE UNIQUE INDEX uq_asp_fee_obligation_73e66feac9
    ON asp_fee_obligation (tenant_id, registration_id) WHERE status IN ('not_required', 'open');

DO $$
DECLARE
    index_name text;
BEGIN
    FOR index_name IN
        SELECT indexrel.relname
        FROM pg_index idx
        JOIN pg_class tbl ON tbl.oid = idx.indrelid
        JOIN pg_class indexrel ON indexrel.oid = idx.indexrelid
        WHERE tbl.relname = 'asp_payment'
          AND (
              pg_get_indexdef(idx.indexrelid) LIKE '%channel%'
              OR (
                  pg_get_indexdef(idx.indexrelid) LIKE '%payer_account_id%'
                  AND pg_get_indexdef(idx.indexrelid) LIKE '%request_key%'
              )
          )
    LOOP
        EXECUTE format('DROP INDEX %I', index_name);
    END LOOP;
END $$;

ALTER TABLE asp_payment DROP COLUMN channel;
ALTER TABLE asp_payment ALTER COLUMN payer_account_id DROP NOT NULL;
ALTER TABLE asp_payment ADD COLUMN payer_name varchar(200);
ALTER TABLE asp_payment ADD COLUMN payer_presence varchar(32);
ALTER TABLE asp_payment ADD COLUMN payment_mode varchar(32);
ALTER TABLE asp_payment ADD COLUMN confirmation_source varchar(32);
UPDATE asp_payment SET payer_presence = 'known', payment_mode = 'offline', confirmation_source = 'manual'
WHERE payer_presence IS NULL;
ALTER TABLE asp_payment ALTER COLUMN payer_presence SET NOT NULL;
ALTER TABLE asp_payment ALTER COLUMN payment_mode SET NOT NULL;
ALTER TABLE asp_payment ALTER COLUMN confirmation_source SET NOT NULL;
ALTER TABLE asp_payment ADD CONSTRAINT ck_asp_payment_payer_presence
    CHECK (payer_presence IN ('known', 'external', 'unavailable'));
ALTER TABLE asp_payment ADD CONSTRAINT ck_asp_payment_mode
    CHECK (payment_mode IN ('free', 'offline', 'organizer_qr'));
ALTER TABLE asp_payment ADD CONSTRAINT ck_asp_payment_source
    CHECK (confirmation_source IN ('manual', 'callback'));
ALTER TABLE asp_payment ADD CONSTRAINT ck_asp_payment_status
    CHECK (status IN ('confirmed', 'reversed'));
CREATE UNIQUE INDEX uq_asp_payment_63d8b067a7 ON asp_payment (tenant_id, request_key);
CREATE UNIQUE INDEX uq_asp_payment_46d600621b ON asp_payment (tenant_id, payee_subject, transaction_id) WHERE transaction_id IS NOT NULL;

ALTER TABLE asp_payment_exception ALTER COLUMN payment_id DROP NOT NULL;
ALTER TABLE asp_payment_exception ADD COLUMN obligation_id bigint;
ALTER TABLE asp_payment_exception ADD COLUMN external_reference varchar(200);
ALTER TABLE asp_payment_exception ADD COLUMN reported_amount numeric(18,2);
ALTER TABLE asp_payment_exception ADD CONSTRAINT ck_asp_payment_exception_target
    CHECK (payment_id IS NOT NULL OR obligation_id IS NOT NULL);
ALTER TABLE asp_payment_exception ADD CONSTRAINT ck_asp_payment_exception_amount
    CHECK (reported_amount IS NULL OR reported_amount >= 0);
CREATE INDEX ix_asp_payment_exception_792aaaf7cc ON asp_payment_exception (tenant_id, obligation_id);
ALTER TABLE asp_payment_exception ADD CONSTRAINT fk_asp_payment_exception_792aaaf7cc
    FOREIGN KEY (tenant_id, obligation_id) REFERENCES asp_fee_obligation (tenant_id, id);

ALTER TABLE asp_refund ALTER COLUMN applicant_account_id DROP NOT NULL;

CREATE TABLE asp_payment_action (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    payment_id bigint NOT NULL,
    obligation_id bigint NOT NULL,
    status varchar(32) NOT NULL,
    note varchar(1000),
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (status IN ('pending', 'closed_no_refund', 'refunded')),
    CHECK (version >= 0)
);
CREATE INDEX ix_asp_payment_action_4ccbe23792 ON asp_payment_action (tenant_id, payment_id);
CREATE INDEX ix_asp_payment_action_ffac68febf ON asp_payment_action (tenant_id, obligation_id);
CREATE UNIQUE INDEX uq_asp_payment_action_88dcbe3096 ON asp_payment_action (tenant_id, payment_id) WHERE status = 'pending';
ALTER TABLE asp_payment_action ADD CONSTRAINT fk_asp_payment_action_4ccbe23792
    FOREIGN KEY (tenant_id, payment_id) REFERENCES asp_payment (tenant_id, id);
ALTER TABLE asp_payment_action ADD CONSTRAINT fk_asp_payment_action_ffac68febf
    FOREIGN KEY (tenant_id, obligation_id) REFERENCES asp_fee_obligation (tenant_id, id);
COMMENT ON TABLE asp_payment_action IS '已付款报名失效后的资金后续。平台不发起退款';

COMMENT ON COLUMN asp_fee_policy.amount IS '整单固定金额。免费为 0。草稿可空';
COMMENT ON COLUMN asp_fee_policy.payment_mode IS '收款方式：free offline organizer_qr。草稿可空';
COMMENT ON COLUMN asp_fee_policy.status IS 'draft active retired';
COMMENT ON COLUMN asp_fee_obligation.status IS 'not_required open settled void';
COMMENT ON COLUMN asp_fee_obligation.request_key IS '义务幂等键。不复用报名请求键';
COMMENT ON COLUMN asp_payment.payer_account_id IS '付款人平台账号。不是平台账号时为空';
COMMENT ON COLUMN asp_payment.payer_name IS '实际付款人名称。外部付款人用它';
COMMENT ON COLUMN asp_payment.status IS 'confirmed reversed。冲正不是退款';
COMMENT ON TABLE asp_payment IS '已经确认的到账事实。未付款时不插入。冲正不是退款';
COMMENT ON TABLE asp_refund IS '已经发生的退款事实。不是平台发起的退款申请';

UPDATE asp_staff_grant
SET permissions = jsonb_set(permissions, '{actions}', (permissions->'actions') || '["payment"]'::jsonb)
WHERE permissions->'actions' ? 'organize'
  AND NOT (permissions->'actions' ? 'payment');

INSERT INTO sys_menu
    (menu_id, menu_name, parent_id, order_num, path, component, is_frame, is_cache,
     menu_type, visible, status, perms, icon, create_time, remark)
VALUES
    (2106100000000000019, '收费记账', 2106100000000000013, 4, 'fees', 'sports/finance/index', '1', '0',
     'C', '0', '0', 'sports:fee:manage', 'money', CURRENT_TIMESTAMP,
     '竞赛单元收费版本和到账确认。不代替报名审核。');

UPDATE sys_tenant_package
SET menu_ids = menu_ids || ',2106100000000000019'
WHERE package_id = 2106100000000000012
  AND position('2106100000000000019' in menu_ids) = 0;

INSERT INTO sys_role_menu (role_id, menu_id)
SELECT DISTINCT rm.role_id, 2106100000000000019
FROM sys_role_menu rm
WHERE rm.menu_id = 2106100000000000014
  AND NOT EXISTS (
      SELECT 1 FROM sys_role_menu existing
      WHERE existing.role_id = rm.role_id AND existing.menu_id = 2106100000000000019
  );
