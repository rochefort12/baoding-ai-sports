package org.dromara.sports.mcp;

import cn.dev33.satoken.stp.StpUtil;
import org.dromara.common.satoken.utils.LoginHelper;

/**
 * 工具调用必须显式执行的授权边界，不能仅依赖 MVC 拦截器或代理注解。
 * 共享身份表的行级授权仍由具体服务实现；租户信息只能来自认证上下文。
 */
public final class McpAccess {
    private McpAccess() { }

    public static void requirePermission(String permission) {
        StpUtil.checkLogin();
        StpUtil.checkPermission("sports:mcp:invoke");
        StpUtil.checkPermission(permission);
        String tenantId = LoginHelper.getTenantId();
        if (tenantId == null || tenantId.isBlank()) {
            throw new IllegalStateException("MCP 调用缺少租户身份");
        }
    }
}
