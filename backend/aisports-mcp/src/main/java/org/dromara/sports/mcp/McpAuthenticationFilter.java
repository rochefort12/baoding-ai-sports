package org.dromara.sports.mcp;

import cn.dev33.satoken.exception.SaTokenException;
import cn.dev33.satoken.stp.StpUtil;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.dromara.common.satoken.utils.LoginHelper;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Set;

/**
 * Spring AI 的函数式路由不在若依 AllUrlHandler 的注解路由集合内，必须额外鉴权。
 * Header Authorization 使用已有 Sa-Token；clientid 必须与令牌声明一致。
 * 不接受 URL 参数令牌；不输出认证异常、令牌或用户信息。
 */
public class McpAuthenticationFilter extends OncePerRequestFilter {
    private final Set<String> allowedOrigins;
    private final Set<String> allowedHosts;
    private final org.dromara.sports.platform.core.AgentRunAccess runs;

    public McpAuthenticationFilter(Set<String> allowedOrigins, Set<String> allowedHosts) {
        this(allowedOrigins,allowedHosts,null);
    }
    public McpAuthenticationFilter(Set<String> allowedOrigins,Set<String> allowedHosts,org.dromara.sports.platform.core.AgentRunAccess runs) {
        this.allowedOrigins = allowedOrigins;
        this.allowedHosts = allowedHosts;
        this.runs=runs;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
        throws ServletException, IOException {
        String origin = request.getHeader("Origin");
        if (!allowedHosts.contains(request.getServerName()) || (origin != null && !allowedOrigins.contains(origin))) {
            reject(response, 403);
            return;
        }
        String runToken=request.getHeader("X-Sports-Run");
        if(runToken!=null){
            if(runs==null || origin!=null || !Set.of("127.0.0.1","::1","0:0:0:0:0:0:0:1").contains(request.getRemoteAddr())){reject(response,403);return;}
            try {var principal=runs.authorize(runToken);org.dromara.sports.platform.core.TrustedRunContext.bind(principal);
                if(principal.tenantId()!=null)org.dromara.common.tenant.helper.TenantHelper.setDynamic(principal.tenantId());
                chain.doFilter(request,response);
            }catch(org.dromara.common.core.exception.ServiceException denied){reject(response,403);}
            finally{org.dromara.sports.platform.core.TrustedRunContext.clear();org.dromara.common.tenant.helper.TenantHelper.clearDynamic();}
            return;
        }
        if (request.getHeader("Authorization") == null || request.getHeader(LoginHelper.CLIENT_KEY) == null) {
            reject(response, 401);
            return;
        }
        try {
            StpUtil.checkLogin();
            Object expectedClient = StpUtil.getExtra(LoginHelper.CLIENT_KEY);
            if (expectedClient == null || !expectedClient.toString().equals(request.getHeader(LoginHelper.CLIENT_KEY))) {
                reject(response, 401);
                return;
            }
            StpUtil.checkPermission("sports:mcp:invoke");
        } catch (SaTokenException e) {
            reject(response, StpUtil.isLogin() ? 403 : 401);
            return;
        }
        chain.doFilter(request, response);
    }

    private static void reject(HttpServletResponse response, int status) throws IOException {
        response.setStatus(status);
        response.setContentType("application/json;charset=UTF-8");
        response.getWriter().write("{\"error\":\"MCP access denied\"}");
    }
}
