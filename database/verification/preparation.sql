-- Synthetic structural checks only. No production business acceptance is claimed.
-- All fixtures roll back. Execute with ON_ERROR_STOP=1 against the prepared database.
BEGIN;
DO $verify$
DECLARE table_count integer;
DECLARE column_count integer;
BEGIN
    -- 这里核对已经应用的基线，不是 catalog.py 的目标模型。
    -- 目标模型可以多出尚未迁移的表；那些表不能写进下面两个数字。
    SELECT count(*) INTO table_count FROM pg_tables WHERE schemaname='public' AND tablename LIKE 'asp_%';
    -- 结构基线等于原先 V001–V041 的最终业务表。属性目录三表仍只在模型里。
    IF table_count <> 118 THEN RAISE EXCEPTION 'Expected 118 applied ASP tables, got %', table_count; END IF;
    SELECT count(*) INTO column_count FROM information_schema.columns WHERE table_schema='public' AND table_name LIKE 'asp_%';
    IF column_count <> 1805 THEN RAISE EXCEPTION 'Expected 1805 applied ASP columns, got %', column_count; END IF;
    IF EXISTS (SELECT 1 FROM pg_attribute a JOIN pg_class t ON t.oid=a.attrelid
        WHERE t.relname LIKE 'asp_%' AND t.relkind='r' AND a.attnum>0 AND NOT a.attisdropped AND col_description(t.oid,a.attnum) IS NULL) THEN
        RAISE EXCEPTION 'Missing column documentation';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_class WHERE relname LIKE 'asp_%' AND relkind='r' AND obj_description(oid,'pg_class') IS NULL) THEN
        RAISE EXCEPTION 'Missing table documentation';
    END IF;
END $verify$;

INSERT INTO asp_organization(id,tenant_id,name,subject_type,subject_hash,status)
VALUES (-91001,'test-a','Synthetic organization','test','test-a-hash','certified');
-- Same-tenant FK succeeds.
INSERT INTO asp_qualification(id,tenant_id,organization_id,revision,proof_snapshot,business_scope,status)
VALUES (-91002,'test-a',-91001,1,'{}','{}','pending');
DO $verify$
BEGIN
    BEGIN
        INSERT INTO asp_qualification(id,tenant_id,organization_id,revision,proof_snapshot,business_scope,status)
        VALUES (-91003,'test-b',-91001,1,'{}','{}','pending');
        RAISE EXCEPTION 'Cross-tenant FK unexpectedly accepted';
    EXCEPTION WHEN foreign_key_violation THEN NULL;
    END;
    BEGIN
        INSERT INTO asp_qualification(id,tenant_id,organization_id,revision,proof_snapshot,business_scope,status)
        VALUES (-91004,'test-a',-91001,0,'{}','{}','pending');
        RAISE EXCEPTION 'Invalid revision unexpectedly accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    BEGIN
        INSERT INTO asp_qualification(id,tenant_id,organization_id,revision,proof_snapshot,business_scope,status)
        VALUES (-91005,'test-a',-91001,2,'{}','{}','invented');
        RAISE EXCEPTION 'Unknown status unexpectedly accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    BEGIN
        INSERT INTO asp_organization(id,tenant_id,name,subject_type,subject_hash,status)
        VALUES (-91006,'test-a','Duplicate','test','test-a-hash','certified');
        RAISE EXCEPTION 'Duplicate organization identity unexpectedly accepted';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
END $verify$;

INSERT INTO asp_account(id,display_name,status) VALUES (-91101,'Synthetic account','active');
DO $verify$
BEGIN
    BEGIN
        INSERT INTO asp_team_quota(id,account_id,create_limit,join_limit,policy_version)
        VALUES (-91102,-91101,-1,10,'synthetic');
        RAISE EXCEPTION 'Negative quota unexpectedly accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
END $verify$;
ROLLBACK;
SELECT 'PASS: schema, comments, tenant FK, revision, status, uniqueness and quota checks; fixtures rolled back' AS evidence;
