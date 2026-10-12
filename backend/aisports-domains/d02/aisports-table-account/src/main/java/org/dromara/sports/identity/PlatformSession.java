package org.dromara.sports.identity;

/**
 * 平台会话的技术租户。只为让登录校验和租户拦截器失败关闭。
 * 不是组织，不表示用户属于这里，也不存放业务数据。
 */
public final class PlatformSession {

    public static final String TENANT_ID = "900001";

    /** 前端落地用的角色标记。不是 sys_role，也不是租户管理员。 */
    public static final String LANDING_ROLE = "participant";

    private PlatformSession() {
    }
}
