-- M1.1 当前运行数据。保证参赛者登录边界和一个初始化登录，并可重复执行。
-- 只补齐这个初始化登录本身。不删除后来注册的账号、档案、报名或队伍。
-- 不给初始化账号建档。属性目录尚未迁移，不在本脚本落库。

INSERT INTO sys_tenant
    (id, tenant_id, contact_user_name, company_name, intro, remark,
     account_count, status, del_flag, create_time)
SELECT
    2106100000000000006, '100001', '平台参赛者', '平台参赛者',
    '参赛者登录边界。不是承办组织，也不进入演示公司的用户列表。',
    '一名登录一份本人档案。',
    -1, '0', '0', CURRENT_TIMESTAMP
WHERE NOT EXISTS (
    SELECT 1 FROM sys_tenant WHERE tenant_id = '100001' OR id = 2106100000000000006
);

UPDATE sys_tenant
SET contact_user_name = '平台参赛者',
    company_name = '平台参赛者',
    intro = '参赛者登录边界。不是承办组织，也不进入演示公司的用户列表。',
    remark = '一名登录一份本人档案。',
    status = '0',
    del_flag = '0'
WHERE tenant_id = '100001';

INSERT INTO sys_dept
    (dept_id, tenant_id, parent_id, ancestors, dept_name, order_num, status, del_flag, create_time)
SELECT
    2106100000000000004, '100001', 0, '0', '平台参赛者', 0, '0', '0', CURRENT_TIMESTAMP
WHERE NOT EXISTS (
    SELECT 1 FROM sys_dept WHERE dept_id = 2106100000000000004
);

UPDATE sys_dept
SET tenant_id = '100001',
    dept_name = '平台参赛者',
    status = '0',
    del_flag = '0'
WHERE dept_id = 2106100000000000004;

INSERT INTO sys_role
    (role_id, tenant_id, role_name, role_key, role_sort, data_scope,
     menu_check_strictly, dept_check_strictly, status, del_flag, remark, create_time)
SELECT
    2106100000000000001, '100001', '参赛者', 'participant', 1, '5',
    true, true, '0', '0',
    '只能填写自己的身份档案。不能查看系统管理。', CURRENT_TIMESTAMP
WHERE NOT EXISTS (
    SELECT 1 FROM sys_role WHERE role_id = 2106100000000000001
);

UPDATE sys_role
SET tenant_id = '100001',
    role_name = '参赛者',
    role_key = 'participant',
    data_scope = '5',
    status = '0',
    del_flag = '0',
    remark = '只能填写自己的身份档案。不能查看系统管理。'
WHERE role_id = 2106100000000000001;

INSERT INTO sys_menu
    (menu_id, menu_name, parent_id, order_num, path, component, is_frame, is_cache,
     menu_type, visible, status, perms, icon, create_time, remark)
SELECT
    2106100000000000002, '参赛者', 0, 8, 'portal', NULL, '1', '0',
    'M', '0', '0', NULL, 'user', CURRENT_TIMESTAMP,
    '参赛者入口，当前挂在管理界面。'
WHERE NOT EXISTS (
    SELECT 1 FROM sys_menu WHERE menu_id = 2106100000000000002
);

INSERT INTO sys_menu
    (menu_id, menu_name, parent_id, order_num, path, component, is_frame, is_cache,
     menu_type, visible, status, perms, icon, create_time, remark)
SELECT
    2106100000000000003, '身份档案', 2106100000000000002, 1, 'identity', 'portal/identity', '1', '0',
    'C', '0', '0', 'sports:identity:list', 'user', CURRENT_TIMESTAMP,
    '本人身份档案。一名登录只填写自己的档案。'
WHERE NOT EXISTS (
    SELECT 1 FROM sys_menu WHERE menu_id = 2106100000000000003
);

UPDATE sys_menu
SET menu_name = '参赛者',
    parent_id = 0,
    path = 'portal',
    component = NULL,
    visible = '0',
    status = '0',
    remark = '参赛者入口，当前挂在管理界面。'
WHERE menu_id = 2106100000000000002;

UPDATE sys_menu
SET menu_name = '身份档案',
    parent_id = 2106100000000000002,
    path = 'identity',
    component = 'portal/identity',
    perms = 'sports:identity:list',
    visible = '0',
    status = '0',
    remark = '本人身份档案。一名登录只填写自己的档案。'
WHERE menu_id = 2106100000000000003;

INSERT INTO sys_role_menu (role_id, menu_id)
SELECT 2106100000000000001, 2106100000000000002
WHERE NOT EXISTS (
    SELECT 1 FROM sys_role_menu
    WHERE role_id = 2106100000000000001 AND menu_id = 2106100000000000002
);

INSERT INTO sys_role_menu (role_id, menu_id)
SELECT 2106100000000000001, 2106100000000000003
WHERE NOT EXISTS (
    SELECT 1 FROM sys_role_menu
    WHERE role_id = 2106100000000000001 AND menu_id = 2106100000000000003
);

INSERT INTO sys_role_dept (role_id, dept_id)
SELECT 2106100000000000001, 2106100000000000004
WHERE NOT EXISTS (
    SELECT 1 FROM sys_role_dept
    WHERE role_id = 2106100000000000001 AND dept_id = 2106100000000000004
);

INSERT INTO sys_user
    (user_id, tenant_id, dept_id, user_name, nick_name, user_type, phonenumber,
     sex, password, status, del_flag, create_time, remark)
SELECT
    2106100000000000010, '100001', 2106100000000000004, '13800001001', '138****1001', 'app_user', '13800001001',
    '0', '$2a$10$6GlShJDDIEwVNZiu6.I.p.jgSqoGLgYHn/F2EQxX/aG1G6iTchtU2', '0', '0', CURRENT_TIMESTAMP,
    'M1.1 初始化登录。尚未建档。'
WHERE NOT EXISTS (
    SELECT 1 FROM sys_user
    WHERE tenant_id = '100001' AND user_name = '13800001001' AND del_flag = '0'
);

INSERT INTO sys_user_role (user_id, role_id)
SELECT u.user_id, 2106100000000000001
FROM sys_user u
WHERE u.tenant_id = '100001'
  AND u.user_name = '13800001001'
  AND u.del_flag = '0'
  AND NOT EXISTS (
      SELECT 1 FROM sys_user_role r
      WHERE r.user_id = u.user_id AND r.role_id = 2106100000000000001
  );

INSERT INTO asp_account (id, display_name, backend_user_id, status, version)
SELECT 2106100000000000011, '138****1001', u.user_id, 'active', 0
FROM sys_user u
WHERE u.tenant_id = '100001'
  AND u.user_name = '13800001001'
  AND u.del_flag = '0'
  AND NOT EXISTS (
      SELECT 1 FROM asp_account a WHERE a.backend_user_id = u.user_id
  );

INSERT INTO asp_login_identity
    (id, account_id, channel, subject_hash, valid_from, verification_source, version)
SELECT
    2106100000000000012, a.id, 'phone',
    '2c43ab2c1172a0fdba4d9dfca4ceccd5da5fb50859880b06908ef6b67b163449',
    CURRENT_TIMESTAMP, 'sms', 0
FROM sys_user u
JOIN asp_account a ON a.backend_user_id = u.user_id
WHERE u.tenant_id = '100001'
  AND u.user_name = '13800001001'
  AND u.del_flag = '0'
  AND NOT EXISTS (
      SELECT 1 FROM asp_login_identity i
      WHERE i.channel = 'phone'
        AND i.subject_hash = '2c43ab2c1172a0fdba4d9dfca4ceccd5da5fb50859880b06908ef6b67b163449'
        AND i.valid_until IS NULL
  );
