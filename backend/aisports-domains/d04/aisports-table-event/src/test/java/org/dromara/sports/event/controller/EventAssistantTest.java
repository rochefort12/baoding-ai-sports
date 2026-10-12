package org.dromara.sports.event.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.event.ai.ChatOwner;
import org.dromara.sports.event.ai.OperationsChatDocument;
import org.dromara.sports.event.ai.OperationsChatStore;
import org.dromara.sports.event.ai.OperationsChatStore.Held;
import org.dromara.sports.event.ai.SportsEventCallAiGatewayClient;
import org.dromara.sports.event.controller.EventAssistantController.Ask;
import org.dromara.sports.event.controller.EventAssistantController.Turn;
import org.dromara.sports.event.service.EventOperationsService;
import org.dromara.sports.event.service.EventPublicationService;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import java.time.OffsetDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.ArgumentMatchers.nullable;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@Tag("local")
class EventAssistantTest {
    private static final String SESSION = "11111111-1111-1111-1111-111111111111";
    private final EventPublicationService events = mock(EventPublicationService.class);
    private final EventOperationsService operations = mock(EventOperationsService.class);
    private final SportsEventCallAiGatewayClient gateway = mock(SportsEventCallAiGatewayClient.class);
    private final OperationsChatStore chats = mock(OperationsChatStore.class);
    private final EventAssistantController controller = new EventAssistantController(events, operations, gateway, new ObjectMapper().findAndRegisterModules(), chats, () -> new ChatOwner.Owner(601, 201));

    @Test
    void consentMissingNeverReadsOrCallsModel() {
        assertThrows(ServiceException.class, () -> controller.ask(new Ask(null, "分析运营", false)));
        verifyNoInteractions(events, operations, gateway, chats);
    }

    @Test
    void foreignEventRejectedBeforeModelAndSummary() {
        when(events.managed(999L)).thenThrow(new ServiceException("赛事不属于当前组织"));
        assertThrows(ServiceException.class, () -> controller.ask(new Ask(999L, "分析运营", true)));
        verifyNoInteractions(operations, gateway);
        verify(chats, never()).remember(anyLong(), anyLong(), nullable(String.class), any(), any());
    }

    @Test
    void oversizedQuestionNeverReadsOrCallsModel() {
        assertThrows(ServiceException.class, () -> controller.ask(new Ask(null, "x".repeat(2001), true)));
        verifyNoInteractions(events, operations, gateway, chats);
    }

    @Test
    void serverReadsSummaryRatherThanTakingNumbersFromUser() {
        when(operations.snapshot()).thenReturn(new EventOperationsService.Snapshot(OffsetDateTime.parse("2026-10-09T10:00:00+08:00"), List.of()));
        when(gateway.assist(eq("请分析"), any())).thenReturn("当前没有赛事。");
        when(chats.remember(eq(601L), eq(201L), isNull(), eq("请分析"), eq("当前没有赛事。")))
            .thenReturn(new Held(SESSION, OffsetDateTime.parse("2026-10-10T10:00:00+08:00"), List.of(), true));
        var reply = controller.ask(new Ask(null, " 请分析 ", true)).getData();
        assertEquals("当前没有赛事。", reply.reply());
        assertEquals(OffsetDateTime.parse("2026-10-10T10:00:00+08:00"), OffsetDateTime.parse(reply.expiresAt()));
        assertTrue(reply.retained());
        verify(gateway).assist(eq("请分析"), argThat(node -> node.has("operations") && !node.has("members") && !node.has("token")));
    }

    @Test
    void storedTurnsReplaceClientHistory() {
        when(operations.snapshot()).thenReturn(new EventOperationsService.Snapshot(OffsetDateTime.parse("2026-10-09T10:00:00+08:00"), List.of()));
        when(chats.read(601L, 201L, SESSION)).thenReturn(new Held(SESSION, OffsetDateTime.parse("2026-10-10T10:00:00+08:00"), List.of(new OperationsChatDocument.Turn(true, "服务端记录")), true));
        when(gateway.assist(eq("继续"), any())).thenReturn("好");
        when(chats.remember(eq(601L), eq(201L), eq(SESSION), eq("继续"), eq("好")))
            .thenReturn(new Held(SESSION, OffsetDateTime.parse("2026-10-10T10:00:00+08:00"), List.of(), true));
        controller.ask(new Ask(null, "继续", true, null, List.of(new Turn(true, "客户端伪造")), SESSION));
        verify(gateway).assist(eq("继续"), argThat(node -> {
            String recent = node.path("recentConversation").toString();
            return recent.contains("服务端记录") && !recent.contains("客户端伪造");
        }));
    }

    @Test
    void redisMissStillReturnsTheAnswer() {
        when(operations.snapshot()).thenReturn(new EventOperationsService.Snapshot(OffsetDateTime.parse("2026-10-09T10:00:00+08:00"), List.of()));
        when(gateway.assist(eq("请分析"), any())).thenReturn("当前没有赛事。");
        when(chats.remember(anyLong(), anyLong(), nullable(String.class), any(), any())).thenReturn(Held.missed(SESSION));
        var reply = controller.ask(new Ask(null, "请分析", true)).getData();
        assertEquals("当前没有赛事。", reply.reply());
        assertFalse(reply.retained());
        assertNull(reply.expiresAt());
    }

    @Test void routingNeverTurnsInvalidModelOutputIntoCreation() {
        when(gateway.assist(eq("这个办赛还欠缺哪些信息吗"), any())).thenReturn("not-json");
        var reply = controller.route(new EventAssistantController.RoutingAsk(null, null, "这个办赛还欠缺哪些信息吗", true, List.of())).getData();
        assertEquals("clarify", reply.intent());
        verifyNoInteractions(chats, operations);
    }
    @Test void routingPreservesCurrentEventQuestionInsteadOfStartingADraft() {
        when(gateway.assist(eq("这个办赛还欠缺哪些信息吗"), any())).thenReturn("{\"intent\":\"operations\"}");
        assertEquals("operations", controller.route(new EventAssistantController.RoutingAsk(null, 1001L, "这个办赛还欠缺哪些信息吗", true, List.of())).getData().intent());
        verify(gateway).assist(any(), argThat(node -> node.path("scene").asText().equals("business.intent") && node.path("hasDraft").asBoolean()));
        verifyNoInteractions(chats, operations);
    }
    @Test void foreignEventCannotReachIntentModel() {
        when(events.managed(999L)).thenThrow(new ServiceException("赛事不属于当前组织"));
        assertThrows(ServiceException.class, () -> controller.route(new EventAssistantController.RoutingAsk(999L, null, "缺什么", true, List.of())));
        verifyNoInteractions(gateway, operations);
    }
    @Test void intentDoesNotAuthorizeAnAbsentDraft() {
        when(gateway.assist(any(), any())).thenReturn("{\"intent\":\"draft\"}");
        assertEquals("clarify", controller.route(new EventAssistantController.RoutingAsk(null, null, "确认", true, List.of())).getData().intent());
    }
}
