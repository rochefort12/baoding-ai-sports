package org.dromara.sports.event.controller;

import cn.dev33.satoken.annotation.SaIgnore;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.ratelimiter.annotation.RateLimiter;
import org.dromara.common.ratelimiter.enums.LimitType;
import org.dromara.sports.api.PlatformAccountApi;
import org.dromara.sports.event.ai.SportsEventCallAiGatewayClient;
import org.dromara.sports.event.ai.SportsEventCallAiGatewayClient.GuideReply;
import org.dromara.sports.event.service.EventPublicationService;
import org.dromara.sports.event.service.EventPublicationService.EventCard;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * 参赛咨询。模型决定检索条件和是否继续翻页，公开赛事和本人报名都由服务端查询。
 */
@SaIgnore
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/public/ai/assistant")
public class ConsumerAssistantController {

    private final EventPublicationService events;
    private final SportsEventCallAiGatewayClient gateway;
    private final PlatformAccountApi accounts;
    private final ObjectMapper mapper;

    @PostMapping
    @RateLimiter(time = 60, count = 6, limitType = LimitType.IP, message = "咨询较频繁，请稍后再试，也可以直接查看赛事")
    public R<Reply> ask(@RequestBody Ask request) {
        if (request == null || !request.consent()) {
            throw new ServiceException("请先同意将问题和必要公开赛事信息发送到 DeepSeek");
        }
        if (request.message() == null || request.message().isBlank() || request.message().length() > 2000) {
            throw new ServiceException("请填写不超过2000字的问题");
        }
        if (request.history() != null && (request.history().size() > 8 || request.history().stream().anyMatch(turn -> turn == null || turn.text() == null || turn.text().length() > 2000))) {
            throw new ServiceException("对话上下文过长，请重新提问");
        }
        Long accountId = accounts.currentAccountId().orElse(null);
        ArrayNode history = mapper.createArrayNode();
        if (request.history() != null) {
            for (Turn turn : request.history()) {
                history.addObject().put("user", turn.user()).put("text", turn.text());
            }
        }
        GuideReply guided = gateway.guide(request.message().trim(), history, request.eventId(), accountId);
        List<Source> sources = new ArrayList<>();
        for (String eventId : guided.eventIds()) {
            if (sources.size() == 8) {
                break;
            }
            try {
                sources.add(source(events.findPublic(Long.valueOf(eventId))));
            } catch (RuntimeException ignored) {
                // 模型提到的编号如果已经不公开，就不放进来源卡片。
            }
        }
        return R.ok(new Reply(guided.reply(), sources, guided.hasMore(), OffsetDateTime.now().toString()));
    }

    private static Source source(EventCard event) {
        return new Source(event.id().toString(), event.name(), event.projectName(), event.location(),
            event.startsAt(), event.endsAt(), event.registrationOpensAt(), event.registrationClosesAt(),
            event.phase(), event.holdingStatus(), event.feeDescription(), "/public/events/" + event.id());
    }

    public record Turn(boolean user, String text) {
    }

    public record Ask(Long eventId, String message, boolean consent, List<Turn> history) {
    }

    public record Source(String eventId, String name, String projectName, String location, OffsetDateTime startsAt, OffsetDateTime endsAt,
                         OffsetDateTime registrationOpensAt, OffsetDateTime registrationClosesAt, String phase, String holdingStatus,
                         String feeDescription, String href) {
    }

    public record Reply(String reply, List<Source> sources, boolean hasMore, String refreshedAt) {
    }
}
