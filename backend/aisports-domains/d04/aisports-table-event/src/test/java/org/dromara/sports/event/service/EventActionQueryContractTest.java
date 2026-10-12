package org.dromara.sports.event.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.sports.platform.core.ScopedJdbc;
import org.junit.jupiter.api.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** Query schema and delegation guards only; real cross-organization behavior is checked through HTTP. */
@Tag("local")
class EventActionQueryContractTest {
    @Test void mineSupportsBothEmptyQueryAndOptionalStringEventId() {
        var provider = new EventActionProvider(mock(EventPublicationService.class), mock(ScopedJdbc.class), new ObjectMapper());
        var definition = provider.capabilities().stream().filter(d -> d.code().equals("event.mine")).findFirst().orElseThrow();
        assertEquals("string", definition.inputSchema().path("properties").path("eventId").path("type").asText());
        assertEquals(0, definition.inputSchema().path("required").size());
        assertFalse(definition.inputSchema().path("additionalProperties").asBoolean());
        assertFalse(definition.mutation());
        assertFalse(definition.confirmation());
    }

    @Test void refusedOwnedEventStopsBeforeReadinessOrRelatedQueries() {
        var events = mock(EventPublicationService.class);
        var db = mock(ScopedJdbc.class);
        var json = new ObjectMapper();
        var provider = new EventActionProvider(events, db, json);
        when(events.managed(99L)).thenThrow(new org.dromara.common.core.exception.ServiceException("foreign event",403));
        assertThrows(RuntimeException.class, () -> provider.preview("event.mine", json.createObjectNode().put("eventId", "99")));
        verify(events).managed(99L);
        verify(events, never()).readiness(anyLong());
        verifyNoInteractions(db);
    }
}
