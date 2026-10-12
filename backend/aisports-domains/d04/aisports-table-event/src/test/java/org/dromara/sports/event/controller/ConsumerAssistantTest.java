package org.dromara.sports.event.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.api.PlatformAccountApi;
import org.dromara.sports.event.ai.SportsEventCallAiGatewayClient;
import org.dromara.sports.event.ai.SportsEventCallAiGatewayClient.GuideReply;
import org.dromara.sports.event.service.EventPublicationService;
import org.dromara.sports.event.service.EventPublicationService.EventCard;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@Tag("local")
class ConsumerAssistantTest {
    final EventPublicationService events = mock(EventPublicationService.class);
    final SportsEventCallAiGatewayClient gateway = mock(SportsEventCallAiGatewayClient.class);
    final PlatformAccountApi accounts = mock(PlatformAccountApi.class);
    final ConsumerAssistantController controller = new ConsumerAssistantController(events, gateway, accounts, new ObjectMapper().findAndRegisterModules());

    @Test
    void consentAndSizeCheckedBeforeModel() {
        assertThrows(ServiceException.class, () -> controller.ask(new ConsumerAssistantController.Ask(null, "找赛事", false, null)));
        assertThrows(ServiceException.class, () -> controller.ask(new ConsumerAssistantController.Ask(null, "x".repeat(2001), true, null)));
        verifyNoInteractions(events, gateway);
    }

    @Test
    void modelChoosesSearchAndServerRechecksCitedEvents() {
        when(accounts.currentAccountId()).thenReturn(Optional.of(201L));
        when(gateway.guide(eq("找赛事"), any(), isNull(), eq(201L))).thenReturn(new GuideReply("还有更多", List.of("2", "9"), true));
        EventCard open = event(2);
        when(events.findPublic(2L)).thenReturn(open);
        when(events.findPublic(9L)).thenThrow(new ServiceException("赛事不存在或未公开"));
        var result = controller.ask(new ConsumerAssistantController.Ask(null, "找赛事", true, List.of())).getData();
        assertEquals(1, result.sources().size());
        assertEquals("2", result.sources().get(0).eventId());
        assertTrue(result.hasMore());
        verify(events, org.mockito.Mockito.never()).listPublic();
    }

    @Test
    void pageContextDoesNotPreloadHiddenEvent() {
        when(accounts.currentAccountId()).thenReturn(Optional.empty());
        when(gateway.guide(eq("讲规程"), any(), eq(9L), isNull())).thenReturn(new GuideReply("请看公开赛事", List.of(), false));
        var result = controller.ask(new ConsumerAssistantController.Ask(9L, "讲规程", true, null)).getData();
        assertTrue(result.sources().isEmpty());
        verify(events, org.mockito.Mockito.never()).findPublic(9L);
    }

    private static EventCard event(long id) {
        EventCard event = mock(EventCard.class);
        when(event.id()).thenReturn(id);
        when(event.name()).thenReturn("测试赛事");
        when(event.phase()).thenReturn("registration");
        when(event.holdingStatus()).thenReturn("normal");
        when(event.projectName()).thenReturn("羽毛球");
        return event;
    }
}
