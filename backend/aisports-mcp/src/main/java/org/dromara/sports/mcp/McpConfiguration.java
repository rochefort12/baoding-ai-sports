package org.dromara.sports.mcp;

import org.springframework.ai.tool.ToolCallbackProvider;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.method.MethodToolCallbackProvider;
import org.springframework.aop.support.AopUtils;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.ApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.AnnotatedElementUtils;
import org.springframework.web.bind.annotation.RestController;

import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * 仅注册 org.dromara.sports 下 Controller 中显式声明的工具。
 * 同步、无会话传输复用当前请求的 Sa-Token 与 MyBatis 租户上下文。
 * 不创建新的系统用户或具有管理员权限的机器令牌。
 */
@Configuration(proxyBeanMethods = false)
@ConditionalOnProperty(prefix = "spring.ai.mcp.server", name = "enabled", havingValue = "true")
public class McpConfiguration {
    @Bean
    public FilterRegistrationBean<McpAuthenticationFilter> mcpAuthenticationFilter(
        @Value("${spring.ai.mcp.server.stateless.mcp-endpoint:/mcp}") String endpoint,
        @Value("${spring.ai.mcp.server.protocol:STATELESS}") String protocol,
        @Value("${spring.ai.mcp.server.type:SYNC}") String type,
        @Value("${spring.ai.mcp.server.annotation-scanner.enabled:false}") boolean scanner,
        @Value("${aisports.mcp.allowed-origins:http://localhost:5173,http://127.0.0.1:5173}") String origins,
        @Value("${aisports.mcp.allowed-hosts:localhost,127.0.0.1}") String hosts,
        org.dromara.sports.platform.core.AgentRunAccess runs) {
        if (!"STATELESS".equals(protocol) || !"SYNC".equals(type) || scanner) {
            throw new IllegalStateException("MCP 必须使用 SYNC/STATELESS 并关闭自动注解扫描，以保留请求授权上下文");
        }
        if (!endpoint.matches("/[a-zA-Z0-9/_-]+") || endpoint.endsWith("/")) {
            throw new IllegalArgumentException("MCP 端点必须是无通配符的绝对路径");
        }
        FilterRegistrationBean<McpAuthenticationFilter> registration = new FilterRegistrationBean<>(
            new McpAuthenticationFilter(split(origins), split(hosts),runs));
        registration.addUrlPatterns(endpoint, endpoint + "/*");
        // RequestContextFilter must bind the servlet request before Sa-Token is called.
        registration.setOrder(Ordered.LOWEST_PRECEDENCE - 10);
        return registration;
    }

    @Bean
    public ToolCallbackProvider sportsToolCallbackProvider(ApplicationContext context) {
        Object[] controllers = context.getBeansWithAnnotation(RestController.class).values().stream()
            .filter(bean -> AopUtils.getTargetClass(bean).getPackageName().startsWith("org.dromara.sports."))
            .filter(bean -> Arrays.stream(AopUtils.getTargetClass(bean).getMethods())
                .anyMatch(method -> AnnotatedElementUtils.hasAnnotation(method, Tool.class)))
            .toArray();
        if (controllers.length == 0) {
            return () -> new org.springframework.ai.tool.ToolCallback[0];
        }
        ToolCallbackProvider provider = MethodToolCallbackProvider.builder().toolObjects(controllers).build();
        Set<String> names = new HashSet<>();
        Arrays.stream(provider.getToolCallbacks()).forEach(callback -> {
            if (!names.add(callback.getToolDefinition().name())) {
                throw new IllegalStateException("重复 MCP 工具名称: " + callback.getToolDefinition().name());
            }
        });
        return provider;
    }

    private static Set<String> split(String values) {
        return Arrays.stream(values.split(",")).map(String::trim).filter(value -> !value.isEmpty()).collect(Collectors.toSet());
    }
}
