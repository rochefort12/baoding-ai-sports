-- 清空本机业务测试数据。由 scripts/Reset-TestData.ps1 包在事务里执行，本文件不要写 BEGIN/COMMIT。
-- 保留：表结构、迁移记录、框架租户 000000、技术租户 900001、参赛者租户 100001 的角色和部门、
-- 运动项目目录、框架自带账号，以及《环境运行》中的试用登录。
-- 试用登录只保留账号和手机号绑定，档案、赛事、组织、报名和资金全部去掉。

DO $$
DECLARE
    kept_tenants text[] := ARRAY['000000', '100001', '900001'];
    kept_account bigint;
    kept_users bigint[];
    business text;
    account_count bigint;
    event_count bigint;
    organization_count bigint;
    tenant_count bigint;
    user_count bigint;
    sport_count bigint;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM sys_user
        WHERE user_name = 'admin' AND tenant_id = '000000' AND del_flag = '0'
    ) THEN
        RAISE EXCEPTION 'framework admin is missing';
    END IF;

    SELECT a.id INTO kept_account
    FROM asp_account a
    JOIN sys_user u ON u.user_id = a.backend_user_id
    WHERE u.user_name = '13000000000'
      AND u.tenant_id = '100001'
      AND u.del_flag = '0'
    ORDER BY a.id
    LIMIT 1;

    SELECT coalesce(array_agg(user_id), ARRAY[]::bigint[]) INTO kept_users
    FROM sys_user
    WHERE tenant_id = '000000'
       OR user_id = (SELECT backend_user_id FROM asp_account WHERE id = kept_account);

    IF cardinality(kept_users) = 0 THEN
        RAISE EXCEPTION 'no framework users to keep';
    END IF;

    SELECT string_agg(format('%I', table_name), ', ' ORDER BY table_name) INTO business
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_type = 'BASE TABLE'
      AND table_name LIKE 'asp\_%' ESCAPE '\'
      AND table_name NOT IN ('asp_sport', 'asp_account', 'asp_login_identity', 'asp_person', 'asp_consent');

    IF business IS NULL THEN
        RAISE EXCEPTION 'business tables were not found';
    END IF;

    EXECUTE 'TRUNCATE TABLE ' || business || ' RESTART IDENTITY';

    UPDATE asp_account SET person_id = NULL;
    UPDATE asp_person SET merged_into_id = NULL;
    DELETE FROM asp_consent;
    DELETE FROM asp_login_identity
    WHERE kept_account IS NULL OR account_id <> kept_account;
    DELETE FROM asp_account
    WHERE kept_account IS NULL OR id <> kept_account;
    DELETE FROM asp_person;

    IF kept_account IS NOT NULL THEN
        UPDATE asp_account
        SET display_name = '试用账号',
            status = 'active',
            closed_at = NULL
        WHERE id = kept_account;
    END IF;

    DELETE FROM sys_user_role WHERE NOT (user_id = ANY (kept_users));
    DELETE FROM sys_user_post WHERE NOT (user_id = ANY (kept_users));
    DELETE FROM sys_user WHERE NOT (user_id = ANY (kept_users));

    DELETE FROM sys_role_menu
    WHERE role_id IN (SELECT role_id FROM sys_role WHERE NOT (tenant_id = ANY (kept_tenants)));
    DELETE FROM sys_role_dept
    WHERE role_id IN (SELECT role_id FROM sys_role WHERE NOT (tenant_id = ANY (kept_tenants)))
       OR dept_id IN (SELECT dept_id FROM sys_dept WHERE NOT (tenant_id = ANY (kept_tenants)));
    DELETE FROM sys_role WHERE NOT (tenant_id = ANY (kept_tenants));
    DELETE FROM sys_post WHERE NOT (tenant_id = ANY (kept_tenants));
    DELETE FROM sys_dept WHERE NOT (tenant_id = ANY (kept_tenants));
    DELETE FROM sys_tenant WHERE NOT (tenant_id = ANY (kept_tenants));

    TRUNCATE TABLE sys_logininfor, sys_oper_log, test_demo, test_tree RESTART IDENTITY;

    SELECT count(*) INTO account_count FROM asp_account;
    SELECT count(*) INTO event_count FROM asp_event;
    SELECT count(*) INTO organization_count FROM asp_organization;
    SELECT count(*) INTO tenant_count FROM sys_tenant;
    SELECT count(*) INTO user_count FROM sys_user;
    SELECT count(*) INTO sport_count FROM asp_sport;

    IF event_count <> 0 OR organization_count <> 0 OR tenant_count <> 3 OR sport_count <> 1 THEN
        RAISE EXCEPTION 'reset verification failed';
    END IF;
    IF kept_account IS NULL AND account_count <> 0 THEN
        RAISE EXCEPTION 'accounts remain without the trial login';
    END IF;
    IF kept_account IS NOT NULL AND account_count <> 1 THEN
        RAISE EXCEPTION 'trial account was not kept alone';
    END IF;

    RAISE NOTICE 'reset accounts % events % organizations % tenants % users % sports %',
        account_count, event_count, organization_count, tenant_count, user_count, sport_count;
END $$;
