package org.dromara.sports.mcp;

import cn.dev33.satoken.stp.StpUtil;
import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.mockito.MockedStatic;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.*;

@Tag("local")
class McpAuthenticationFilterTest {
    private final McpAuthenticationFilter filter = new McpAuthenticationFilter(Set.of("http://localhost:5173"), Set.of("localhost"));

    private MockHttpServletRequest request() {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/mcp");
        request.setServerName("localhost");
        return request;
    }

    @Test
    void missingHeadersFailBeforeTokenAccess() throws Exception {
        var response = new MockHttpServletResponse();
        var chain = mock(FilterChain.class);
        filter.doFilter(request(), response, chain);
        assertEquals(401, response.getStatus());
        verifyNoInteractions(chain);
    }

    @Test
    void rejectsUntrustedOriginAndHost() throws Exception {
        for (boolean testOrigin : new boolean[] {true, false}) {
            var request = request();
            if (testOrigin) { request.addHeader("Origin", "https://untrusted.invalid"); }
            else { request.setServerName("rebind.invalid"); }
            var response = new MockHttpServletResponse();
            var chain = mock(FilterChain.class);
            filter.doFilter(request, response, chain);
            assertEquals(403, response.getStatus());
            verifyNoInteractions(chain);
        }
    }

    @Test
    void tokenClientMustMatch() throws Exception {
        var request = request();
        request.addHeader("Authorization", "synthetic-token");
        request.addHeader("clientid", "different-client");
        try (MockedStatic<StpUtil> token = mockStatic(StpUtil.class)) {
            token.when(() -> StpUtil.getExtra("clientid")).thenReturn("expected-client");
            var response = new MockHttpServletResponse();
            var chain = mock(FilterChain.class);
            filter.doFilter(request, response, chain);
            assertEquals(401, response.getStatus());
            verifyNoInteractions(chain);
        }
    }

    @Test
    void authenticatedCallChecksMcpPermission() throws Exception {
        var request = request();
        request.addHeader("Authorization", "synthetic-token");
        request.addHeader("clientid", "expected-client");
        try (MockedStatic<StpUtil> token = mockStatic(StpUtil.class)) {
            token.when(() -> StpUtil.getExtra("clientid")).thenReturn("expected-client");
            var response = new MockHttpServletResponse();
            var chain = mock(FilterChain.class);
            filter.doFilter(request, response, chain);
            token.verify(() -> StpUtil.checkPermission("sports:mcp:invoke"));
            verify(chain).doFilter(request, response);
        }
    }
}
