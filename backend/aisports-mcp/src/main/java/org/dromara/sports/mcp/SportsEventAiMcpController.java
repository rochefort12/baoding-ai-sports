package org.dromara.sports.mcp;

import org.dromara.sports.api.AiSceneToolApi;
import org.dromara.sports.api.PlatformAccountApi;
import org.dromara.sports.api.PublicEventGuideApi;
import org.dromara.sports.api.RegistrationGuideApi;
import org.dromara.sports.platform.core.BusinessSupport;
import org.dromara.sports.platform.core.TrustedRunContext;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.web.bind.annotation.RestController;

/**
 * 现有 MCP 只暴露读取和校验。写赛事仍走办赛人确认后的业务入口。
 */
@RestController
@ConditionalOnProperty(prefix = "spring.ai.mcp.server", name = "enabled", havingValue = "true")
public class SportsEventAiMcpController {

    private final AiSceneToolApi aiSceneToolApi;
    private final PublicEventGuideApi publicEvents;
    private final RegistrationGuideApi registrations;
    private final PlatformAccountApi accounts;

    public SportsEventAiMcpController(AiSceneToolApi aiSceneToolApi, PublicEventGuideApi publicEvents,
                                      RegistrationGuideApi registrations, PlatformAccountApi accounts) {
        this.aiSceneToolApi = aiSceneToolApi;
        this.publicEvents = publicEvents;
        this.registrations = registrations;
        this.accounts = accounts;
    }

    @Tool(name = "sports_event_query_ai_constraints", description = "读取从资料创建赛事允许的字段、审核方式和免费项目约束。不写业务表。")
    public String sportsEventQueryAiConstraints() {
        requireLegacySession();
        return aiSceneToolApi.describeEventCreateConstraints();
    }

    @Tool(name = "sports_event_query_ai_document", description = "读取当前组织某次资料任务里的原文块。不写业务表。")
    public String sportsEventQueryAiDocument(long taskId, int fileIndex, String blockLabel) {
        requireLegacySession();
        return aiSceneToolApi.readEventCreateDocument(taskId, fileIndex, blockLabel);
    }

    @Tool(name = "sports_event_check_ai_proposal", description = "校验候选方案是否越权写入收费、发布或非法玩法。不创建赛事。")
    public String sportsEventCheckAiProposal(String proposalJson) {
        requireLegacySession();
        return aiSceneToolApi.validateEventCreateProposal(proposalJson);
    }

    @Tool(name = "sports_event_query_public", description = "按条件分页检索已公开赛事。每次最多 8 场，不写业务表。")
    public String sportsEventQueryPublic(String text, String project, String phase, boolean includeCancelled, int offset) {
        requireLegacySession();
        return publicEvents.searchPublic(text, project, phase, includeCancelled, offset);
    }

    @Tool(name = "sports_registration_query_mine", description = "读取当前登录者自己的报名进度。不能指定别人，不写业务表。")
    public String sportsRegistrationQueryMine(int offset) {
        requireLegacySession();
        return registrations.myStatus(accounts.currentAccountId().orElse(null), offset);
    }

    /** Durable Agent runs must use the registered executor, including its budget and current authorization. */
    private void requireLegacySession() {
        if (TrustedRunContext.current() != null) {
            throw BusinessSupport.fail("请通过已登记的助手能力办理", 403);
        }
    }
}
