package org.dromara.sports.event.ai;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
@Tag("local") class AiCallbackBoundaryTest {
    @Test void callbackUsesThisServerPortAndCannotChooseAnotherHost() {
        assertEquals("http://127.0.0.1:8082", SportsEventCallAiGatewayClient.callbackBase(8082));
        assertEquals("http://127.0.0.1:8080", SportsEventCallAiGatewayClient.callbackBase(8080));
        assertThrows(IllegalArgumentException.class, () -> SportsEventCallAiGatewayClient.callbackBase(0));
        assertThrows(IllegalArgumentException.class, () -> SportsEventCallAiGatewayClient.callbackBase(65536));
    }
    @Test void explicitRefreshNeverOverwritesHumanEditedDraft() {
        var mapper = new ObjectMapper();
        assertTrue(AiSourceRefreshPolicy.canRefresh("{\"dialogue\":[{\"role\":\"ai\",\"text\":\"candidate\"}]}", mapper));
        assertFalse(AiSourceRefreshPolicy.canRefresh("{\"dialogue\":[{\"role\":\"user\",\"text\":\"改为12名额\"}]}", mapper));
        assertFalse(AiSourceRefreshPolicy.canRefresh("not-json", mapper));
    }
}
