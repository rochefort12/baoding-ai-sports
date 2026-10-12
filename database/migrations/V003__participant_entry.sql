-- M1.1 参赛者登录租户。只授予身份档案，不授予系统管理。
-- 页面仍挂在管理界面，正式参赛者入口后移。不写入手机号或微信渠道。

INSERT INTO sys_tenant
    (id, tenant_id, contact_user_name, company_name, intro, remark,
     account_count, status, del_flag, create_time)
VALUES
    (2106100000000000006, '100001', '平台参赛者', '平台参赛者',
     '参赛者登录边界。不是承办组织，也不进入演示公司的用户列表。',
     'M1.1 临时载体使用的登录租户。',
     -1, '0', '0', CURRENT_TIMESTAMP);

INSERT INTO sys_dept
    (dept_id, tenant_id, parent_id, ancestors, dept_name, order_num, status, del_flag, create_time)
VALUES
    (2106100000000000004, '100001', 0, '0', '平台参赛者', 0, '0', '0', CURRENT_TIMESTAMP);

INSERT INTO sys_role
    (role_id, tenant_id, role_name, role_key, role_sort, data_scope,
     menu_check_strictly, dept_check_strictly, status, del_flag, remark, create_time)
VALUES
    (2106100000000000001, '100001', '参赛者', 'participant', 1, '5',
     true, true, '0', '0',
     '只能填写自己的身份档案。不能查看系统管理。', CURRENT_TIMESTAMP);

INSERT INTO sys_menu
    (menu_id, menu_name, parent_id, order_num, path, component, is_frame, is_cache,
     menu_type, visible, status, perms, icon, create_time, remark)
VALUES
    (2106100000000000002, '参赛者', 0, 8, 'portal', NULL, '1', '0',
     'M', '0', '0', NULL, 'user', CURRENT_TIMESTAMP,
     '临时挂在管理界面，正式参赛者页面后移。'),
    (2106100000000000003, '身份档案', 2106100000000000002, 1, 'identity', 'portal/identity', '1', '0',
     'C', '0', '0', 'sports:identity:list', 'user', CURRENT_TIMESTAMP,
     '登录名、本人档案、同名参赛人、家长代报和孩子独立账号。');

INSERT INTO sys_role_menu (role_id, menu_id)
VALUES
    (2106100000000000001, 2106100000000000002),
    (2106100000000000001, 2106100000000000003);

INSERT INTO sys_role_dept (role_id, dept_id)
VALUES
    (2106100000000000001, 2106100000000000004);
