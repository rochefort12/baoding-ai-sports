package org.dromara.sports.event.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.event.ai.ChatOwner;
import org.dromara.sports.event.ai.OperationsChatDocument;
import org.dromara.sports.event.ai.OperationsChatRedis;
import org.dromara.sports.event.ai.OperationsChatStore;
import org.dromara.sports.event.ai.OperationsChatStore.Held;
import org.dromara.sports.event.ai.SportsEventCallAiGatewayClient;
import org.dromara.sports.event.service.EventOperationsService;
import org.dromara.sports.event.service.EventPublicationService;
import org.springframework.web.bind.annotation.*;

/** 组织只读运营对话。数据从服务端获取，不能信任客户端提交的统计或组织编号。 */
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/b/ai/assistant")
public class EventAssistantController {
    private final EventPublicationService eventService;
    private final EventOperationsService operationsService;
    private final SportsEventCallAiGatewayClient gateway;
    private final ObjectMapper mapper;
    private final OperationsChatStore chats;
    private final ChatOwner chatOwner;

    @PostMapping
    public R<Reply> ask(@RequestBody Ask request) {
        if (request == null || !request.consent()) throw new ServiceException("请先同意将必要赛事信息发送到当前配置的外部 AI 模型服务");
        if (request.message() == null || request.message().isBlank() || request.message().length()>2000) throw new ServiceException("请填写不超过2000字的问题");
        if (request.history() != null) {
            if (request.history().size() > 6 || request.history().stream().anyMatch(t -> t == null || t.text() == null || t.text().length() > 2000)) {
                throw new ServiceException("对话上下文过长，请重新提问");
            }
        }
        ChatOwner.Owner owner = chatOwner.current();
        var context = mapper.createObjectNode();
        if (request.page() != null && request.page().length() <= 300) context.put("currentPage",request.page());
        java.util.List<OperationsChatDocument.Turn> stored = java.util.List.of();
        if (OperationsChatRedis.valid(request.sessionId())) {
            Held existing = chats.read(owner.organizationId(), owner.accountId(), request.sessionId());
            if (existing != null) stored = existing.turns();
        }
        java.util.List<?> recent = stored.isEmpty() ? (request.history() == null ? java.util.List.of() : request.history()) : stored.subList(Math.max(0, stored.size() - 6), stored.size());
        context.set("recentConversation", mapper.valueToTree(recent));
        context.put("currentTime", java.time.OffsetDateTime.now(java.time.ZoneId.of("Asia/Shanghai")).toString());
        context.put("timeZone", "Asia/Shanghai");
        if (request.eventId() != null) {
            var event = eventService.managed(request.eventId());
            context.set("readiness", mapper.valueToTree(eventService.readiness(request.eventId())));
            context.set("event", mapper.valueToTree(new EventFacts(event.name(),event.location(),event.projectName(),event.feeDescription(),
                event.startsAt(),event.endsAt(),event.registrationClosesAt(),event.registrationReview(),event.publicationStatus(),event.holdingStatus(),event.rulesText())));
        }
        var snapshot = operationsService.snapshot();
        context.set("operations", mapper.valueToTree(snapshot));
        String reply = gateway.assist(request.message().trim(), context);
        Held held = chats.remember(owner.organizationId(), owner.accountId(), request.sessionId(), request.message().trim(), reply);
        return R.ok(new Reply(reply, snapshot.refreshedAt().toString(), held.sessionId(), held.expiresAt() == null ? null : held.expiresAt().toString(), held.retained()));
    }

    @PostMapping("/route")
    public R<RoutingReply> route(@RequestBody RoutingAsk request) {
        if (request == null || !request.consent()) throw new ServiceException("请先同意使用外部 AI 模型服务");
        if (request.message() == null || request.message().isBlank() || request.message().length() > 20000) throw new ServiceException("请填写不超过20000字的问题或规程");
        chatOwner.current();
        if (request.history() != null && (request.history().size() > 6 || request.history().stream().anyMatch(t -> t == null || t.text() == null || t.text().length() > 2000))) throw new ServiceException("对话上下文过长");
        var context = mapper.createObjectNode();
        context.put("scene", "business.intent");
        context.put("hasDraft", request.taskId() != null); // 仅是意图提示，不授予草稿访问权限；talk/get再次验证归属。
        if (request.eventId() != null) context.put("selectedEvent", eventService.managed(request.eventId()).name());
        context.set("recentConversation", mapper.valueToTree(request.history() == null ? java.util.List.of() : request.history()));
        String intent = "clarify";
        try {
            String raw = gateway.assist(request.message().trim(), context);
            String candidate = mapper.readTree(raw).path("intent").asText();
            if (java.util.Set.of("operations", "draft", "new", "clarify").contains(candidate)) intent = candidate;
        } catch (java.io.IOException | IllegalArgumentException invalid) { /* 不能把模型格式失败兜底为创建。 */ }
        if ("draft".equals(intent) && request.taskId() == null) intent = "clarify";
        return R.ok(new RoutingReply(intent));
    }
    public record RoutingAsk(Long eventId, Long taskId, String message, boolean consent, java.util.List<Turn> history) { }
    public record RoutingReply(String intent) { }

    @GetMapping("/sessions")
    public R<SessionList> sessions() {
        ChatOwner.Owner owner = chatOwner.current();
        java.util.List<SessionCard> cards = chats.list(owner.organizationId(), owner.accountId()).stream()
            .map(item -> new SessionCard(item.sessionId(), item.preview(), item.expiresAt().toString()))
            .toList();
        return R.ok(new SessionList(chats.sessionLimit(), cards));
    }

    @DeleteMapping("/sessions/{sessionId}")
    public R<Void> discardSession(@PathVariable String sessionId) {
        ChatOwner.Owner owner = chatOwner.current();
        chats.discard(owner.organizationId(), owner.accountId(), sessionId);
        return R.ok();
    }

    @GetMapping("/sessions/{sessionId}")
    public R<StoredChat> session(@PathVariable String sessionId) {
        ChatOwner.Owner owner = chatOwner.current();
        Held held = chats.read(owner.organizationId(), owner.accountId(), sessionId);
        if (held == null) throw new ServiceException("这段问答已经过期或不存在");
        return R.ok(new StoredChat(held.sessionId(), held.expiresAt().toString(), held.turns()));
    }
    public record Turn(boolean user, String text) { }
    public record Ask(Long eventId, String message, boolean consent, String page, java.util.List<Turn> history, String sessionId) {
        public Ask(Long eventId,String message,boolean consent) { this(eventId,message,consent,null,null,null); }
    }
    public record Reply(String reply, String refreshedAt, String sessionId, String expiresAt, boolean retained) { }
    public record SessionCard(String sessionId, String preview, String expiresAt) { }
    public record SessionList(int limit, java.util.List<SessionCard> sessions) { }
    public record StoredChat(String sessionId, String expiresAt, java.util.List<OperationsChatDocument.Turn> turns) { }
    private record EventFacts(String name, String location, String projectName, String feeDescription,
                              java.time.OffsetDateTime startsAt, java.time.OffsetDateTime endsAt, java.time.OffsetDateTime registrationClosesAt, String registrationReview,
                              String publicationStatus, String holdingStatus, String rulesText) { }
}
