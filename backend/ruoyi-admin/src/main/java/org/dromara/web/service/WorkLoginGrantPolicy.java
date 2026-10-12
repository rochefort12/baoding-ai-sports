package org.dromara.web.service;

import java.util.Arrays;

/** 工作密码认证只改变组织的定位方式，仍须取得客户端原有 password 授权。 */
public final class WorkLoginGrantPolicy {
    public static final String WORK_PASSWORD = "work-password";

    private WorkLoginGrantPolicy() {
    }

    public static boolean requiresAccountTenantResolution(String grantType) {
        return WORK_PASSWORD.equals(grantType);
    }

    public static boolean permits(String configuredGrants, String grantType) {
        if (configuredGrants == null || grantType == null || grantType.isBlank()) {
            return false;
        }
        String required = requiresAccountTenantResolution(grantType) ? "password" : grantType;
        // 按完整授权项判断，避免 work-password 或 pass 等子串绕过授权目录。
        return Arrays.stream(configuredGrants.split(","))
            .map(String::trim).anyMatch(required::equals);
    }
}
