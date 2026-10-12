ALTER TABLE asp_organization_application ADD COLUMN assigned_reviewer_id bigint;
COMMENT ON COLUMN asp_organization_application.assigned_reviewer_id IS '指定政府审核经办人，普通岗位只能处理明确分配给本人的申请';
CREATE INDEX ix_asp_organization_application_reviewer ON asp_organization_application(assigned_reviewer_id,status);
INSERT INTO sys_role(role_id,tenant_id,role_name,role_key,role_sort,data_scope,menu_check_strictly,dept_check_strictly,status,del_flag,remark,create_time)
VALUES(832000000001,'000000','体育政府管理','sports_government',10,'5',true,true,'0','0','岗位菜单不是全局对象授权；申请须分配，主办方须明确授予范围',CURRENT_TIMESTAMP)
ON CONFLICT(role_id) DO NOTHING;
INSERT INTO sys_role_menu(role_id,menu_id)
SELECT 832000000001,menu_id FROM sys_menu WHERE menu_id IN(2106100000000000015,2106100000000000016,831000000201,831000000202,831000000203)
ON CONFLICT(role_id,menu_id) DO NOTHING;
