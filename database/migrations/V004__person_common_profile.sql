-- 通用档案列落到 asp_person。必填：真实姓名、出生日期、性别、手机号。
-- 证件、城市、地址、血型、衣服尺码、紧急联系人可空。这些列不是赛事属性目录。
-- 旧测试档案没有手机号，且部分性别为 unknown，无法填进必填列，只清档案关系，不删登录账号。

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM asp_team)
       OR EXISTS (SELECT 1 FROM asp_roster_member)
       OR EXISTS (SELECT 1 FROM asp_registration) THEN
        RAISE EXCEPTION 'refuse person profile migration while team, roster, or registration rows exist';
    END IF;
END $$;

DELETE FROM asp_consent;
DELETE FROM asp_delegation;
DELETE FROM asp_guardianship;
DELETE FROM asp_account_person;
DELETE FROM asp_person;

ALTER TABLE asp_person
    ADD COLUMN legal_name varchar(100),
    ADD COLUMN id_doc_type varchar(32),
    ADD COLUMN mobile varchar(20),
    ADD COLUMN city varchar(100),
    ADD COLUMN address_detail varchar(200),
    ADD COLUMN blood_type varchar(32),
    ADD COLUMN clothing_size varchar(32),
    ADD COLUMN emergency_contact_name varchar(100),
    ADD COLUMN emergency_contact_phone varchar(20);

ALTER TABLE asp_person ALTER COLUMN display_name DROP NOT NULL;
ALTER TABLE asp_person ALTER COLUMN birth_date SET NOT NULL;
ALTER TABLE asp_person ALTER COLUMN legal_name SET NOT NULL;
ALTER TABLE asp_person ALTER COLUMN mobile SET NOT NULL;

DO $$
DECLARE
    constraint_name text;
BEGIN
    FOR constraint_name IN
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = 'asp_person'::regclass
          AND contype = 'c'
          AND pg_get_constraintdef(oid) ILIKE '%gender%'
    LOOP
        EXECUTE format('ALTER TABLE asp_person DROP CONSTRAINT %I', constraint_name);
    END LOOP;
END $$;

ALTER TABLE asp_person ADD CONSTRAINT asp_person_gender_check CHECK (gender IN ('male', 'female', 'other'));
ALTER TABLE asp_person ADD CONSTRAINT asp_person_mobile_check CHECK (mobile ~ '^1[3-9][0-9]{9}$');
ALTER TABLE asp_person ADD CONSTRAINT asp_person_id_doc_type_check CHECK (id_doc_type IS NULL OR id_doc_type IN ('id_card', 'passport', 'hmt_pass', 'other'));
ALTER TABLE asp_person ADD CONSTRAINT asp_person_id_pair_check CHECK ((id_doc_type IS NULL) = (identity_hash IS NULL) AND (identity_hash IS NULL) = (identity_cipher IS NULL));
ALTER TABLE asp_person ADD CONSTRAINT asp_person_blood_type_check CHECK (blood_type IS NULL OR blood_type IN ('A', 'B', 'AB', 'O', 'unknown'));
ALTER TABLE asp_person ADD CONSTRAINT asp_person_clothing_size_check CHECK (clothing_size IS NULL OR clothing_size IN ('XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'));
ALTER TABLE asp_person ADD CONSTRAINT asp_person_emergency_phone_check CHECK (emergency_contact_phone IS NULL OR emergency_contact_phone ~ '^1[3-9][0-9]{9}$');

COMMENT ON COLUMN asp_person.legal_name IS '真实姓名；必填';
COMMENT ON COLUMN asp_person.display_name IS '活动展示名；空则对外使用真实姓名';
COMMENT ON COLUMN asp_person.birth_date IS '出生日期；必填。年龄按赛事自己的基准日判断';
COMMENT ON COLUMN asp_person.gender IS '分组用性别；必填：male female other';
COMMENT ON COLUMN asp_person.mobile IS '联系手机；必填。现在手工填写，以后可从已验证登录号带入。公开页不展示';
COMMENT ON COLUMN asp_person.id_doc_type IS '证件类型：id_card passport hmt_pass other；可空';
COMMENT ON COLUMN asp_person.identity_hash IS '证件号码带密钥摘要；未填证件时为空';
COMMENT ON COLUMN asp_person.identity_cipher IS '证件号码加密值；未填证件时为空';
COMMENT ON COLUMN asp_person.city IS '所在城市；通用资料，可空';
COMMENT ON COLUMN asp_person.address_detail IS '详细地址；通用资料，可空';
COMMENT ON COLUMN asp_person.blood_type IS '血型：A B AB O unknown；通用资料，可空，不公开';
COMMENT ON COLUMN asp_person.clothing_size IS '衣服尺码：XS S M L XL XXL XXXL；通用资料，可空';
COMMENT ON COLUMN asp_person.emergency_contact_name IS '紧急联系人；通用资料，可空';
COMMENT ON COLUMN asp_person.emergency_contact_phone IS '紧急联系号码；通用资料，可空，不公开';
