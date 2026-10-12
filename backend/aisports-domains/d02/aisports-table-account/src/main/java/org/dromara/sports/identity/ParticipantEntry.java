package org.dromara.sports.identity;

/**
 * 参赛者登录边界。租户和角色由 V003 写入，注册与身份接口都引用这里。
 * 这是管理界面上的临时载体，正式参赛者页面后移时仍使用同一租户。
 */
public final class ParticipantEntry {

    public static final String TENANT_ID = "100001";

    public static final long ROLE_ID = 2106100000000000001L;

    public static final long DEPT_ID = 2106100000000000004L;

    private ParticipantEntry() {
    }
}
