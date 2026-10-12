package org.dromara.sports.event.controller;

import cn.dev33.satoken.annotation.SaIgnore;
import com.fasterxml.jackson.databind.JsonNode;
import lombok.RequiredArgsConstructor;
import org.dromara.sports.event.service.ConsumerGuideToolService;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * 网关检索回调。只认内部令牌。报名账号来自最初的登录请求，不来自模型参数。
 */
@SaIgnore
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/internal/ai/guide")
public class ConsumerGuideInternalController {

    private final ConsumerGuideToolService tools;

    @PostMapping("/tools")
    public Map<String, String> tool(@RequestHeader(value = "X-Ai-Internal-Token", required = false) String token,
                                    @RequestBody ToolCall call) {
        Long accountId = call == null ? null : call.accountId();
        tools.requireToken(token);
        String result = tools.call(accountId, call == null ? "" : call.name(), call == null ? null : call.arguments());
        return Map.of("result", result);
    }

    public record ToolCall(String name, JsonNode arguments, Long accountId) {
    }
}
