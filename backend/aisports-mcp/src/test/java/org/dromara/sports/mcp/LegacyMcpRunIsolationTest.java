package org.dromara.sports.mcp;

import org.dromara.sports.api.*;
import org.dromara.sports.platform.core.*;
import org.junit.jupiter.api.*;
import java.util.Set;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** Legacy session tools cannot bypass a run's registered actions, current grants or tool budget. */
@Tag("local")
class LegacyMcpRunIsolationTest {
    @AfterEach void clearContext() { TrustedRunContext.clear(); }

    @Test void everyLegacyToolRejectsAgentRunBeforeReadingAnyData() {
        var ai = mock(AiSceneToolApi.class);
        var events = mock(PublicEventGuideApi.class);
        var registration = mock(RegistrationGuideApi.class);
        var accounts = mock(PlatformAccountApi.class);
        var tools = new SportsEventAiMcpController(ai, events, registration, accounts);
        TrustedRunContext.bind(new AgentRunAccess.RunPrincipal(10L, "platform", 20L,
            null, null, Set.of("room.query"), "{}"));
        assertThrows(RuntimeException.class, tools::sportsEventQueryAiConstraints);
        assertThrows(RuntimeException.class, () -> tools.sportsEventQueryAiDocument(1L, 0, "paragraph"));
        assertThrows(RuntimeException.class, () -> tools.sportsEventCheckAiProposal("{}"));
        assertThrows(RuntimeException.class, () -> tools.sportsEventQueryPublic("", "", "", false, 0));
        assertThrows(RuntimeException.class, () -> tools.sportsRegistrationQueryMine(0));
        verifyNoInteractions(ai, events, registration, accounts);
    }

    @Test void legacySessionStillUsesExistingAuthorizedContract() {
        var ai = mock(AiSceneToolApi.class);
        var tools = new SportsEventAiMcpController(ai, mock(PublicEventGuideApi.class),
            mock(RegistrationGuideApi.class), mock(PlatformAccountApi.class));
        when(ai.describeEventCreateConstraints()).thenReturn("existing-contract");
        assertEquals("existing-contract", tools.sportsEventQueryAiConstraints());
        verify(ai).describeEventCreateConstraints();
    }
}
