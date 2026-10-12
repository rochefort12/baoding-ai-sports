-- MCP invocation permission is centrally assignable; no role is granted automatically.
-- User requirement: explicitly selected generated read tools with existing RuoYi RBAC.
-- Reserved preparation menu ID: 2106000000000000001. Tools remain globally disabled by default.
INSERT INTO sys_menu
    (menu_id, menu_name, parent_id, order_num, path, menu_type, visible, status,
     perms, icon, create_time, remark)
VALUES
    (2106000000000000001, 'MCP只读调用', 3, 90, '', 'F', '0', '0',
     'sports:mcp:invoke', '#', CURRENT_TIMESTAMP,
     '可选MCP访问权限。需同时授予具体查询权限，工具服务必须验证租户、行级授权与脱敏。默认不自动分配角色。');
