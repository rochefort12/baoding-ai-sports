package org.dromara.sports.mcp;

import cn.dev33.satoken.exception.SaTokenException;
import cn.dev33.satoken.stp.StpUtil;
import org.dromara.common.satoken.utils.LoginHelper;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.*;

@Tag("local")
class McpAccessTest {
    @Test
    void checksBothPermissionsAndRequiresAuthenticatedTenant() {
        try (var token = mockStatic(StpUtil.class); var login = mockStatic(LoginHelper.class)) {
            assertThrows(IllegalStateException.class, () -> McpAccess.requirePermission("sports:sample:list"));
            token.verify(StpUtil::checkLogin);
            token.verify(() -> StpUtil.checkPermission("sports:mcp:invoke"));
            token.verify(() -> StpUtil.checkPermission("sports:sample:list"));
            login.when(LoginHelper::getTenantId).thenReturn("000000");
            McpAccess.requirePermission("sports:sample:list");
        }
    }

    @Test
    void deniedPermissionStopsBeforeTenantAndServiceAccess() {
        try (var token = mockStatic(StpUtil.class); var login = mockStatic(LoginHelper.class)) {
            token.when(() -> StpUtil.checkPermission("sports:sample:list")).thenThrow(new SaTokenException("synthetic denial"));
            assertThrows(SaTokenException.class, () -> McpAccess.requirePermission("sports:sample:list"));
            login.verifyNoInteractions();
        }
    }

    @Test
    void unsafeTransportAndScannerConfigurationFailClosed() {
        McpConfiguration configuration = new McpConfiguration();
        assertThrows(IllegalStateException.class, () -> configuration.mcpAuthenticationFilter(
            "/mcp", "SSE", "SYNC", false, "http://localhost:5173", "localhost",null));
        assertThrows(IllegalStateException.class, () -> configuration.mcpAuthenticationFilter(
            "/mcp", "STATELESS", "ASYNC", false, "http://localhost:5173", "localhost",null));
        assertThrows(IllegalStateException.class, () -> configuration.mcpAuthenticationFilter(
            "/mcp", "STATELESS", "SYNC", true, "http://localhost:5173", "localhost",null));
        assertThrows(IllegalArgumentException.class, () -> configuration.mcpAuthenticationFilter(
            "/*", "STATELESS", "SYNC", false, "http://localhost:5173", "localhost",null));
    }
}
