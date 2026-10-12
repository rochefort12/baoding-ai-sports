-- 平台登录使用账号上的密码散列。技术租户只为通过登录校验，不表示用户身份。

ALTER TABLE asp_account ADD COLUMN password_hash varchar(100);
COMMENT ON COLUMN asp_account.password_hash IS '登录密码散列。只供平台登录校验，不写入日志';

UPDATE asp_account AS account
SET password_hash = backend_user.password
FROM sys_user AS backend_user
WHERE account.backend_user_id = backend_user.user_id
  AND account.password_hash IS NULL
  AND backend_user.password IS NOT NULL
  AND backend_user.password <> '';

INSERT INTO sys_tenant
    (id, tenant_id, contact_user_name, company_name, intro, remark,
     account_count, status, del_flag, create_time)
SELECT
    2106100000000000007, '900001', '登录兼容', '登录兼容',
    '只为登录校验占位。不是组织，不存放业务，不表示用户身份。',
    '平台会话的技术租户。',
    -1, '0', '0', CURRENT_TIMESTAMP
WHERE NOT EXISTS (
    SELECT 1 FROM sys_tenant WHERE tenant_id = '900001' OR id = 2106100000000000007
);

UPDATE sys_client
SET grant_type = grant_type || ',platform'
WHERE client_id = 'e5cd7e4891bf95d1d19206ce24a7b32e'
  AND position('platform' in grant_type) = 0;
