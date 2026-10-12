package org.dromara.sports.event.ai;

import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

@Tag("local")
class OperationsChatLimitTest {

    @Test
    void ninthSessionDropsTheOldest() {
        List<String> existing = List.of("8", "7", "6", "5", "4", "3", "2", "1");
        assertEquals(List.of("1"), OperationsChatLimit.overflow(existing, "9", 8));
    }

    @Test
    void updatingAnExistingSessionDropsNothing() {
        List<String> existing = List.of("8", "7", "6", "5", "4", "3", "2", "1");
        assertEquals(List.of(), OperationsChatLimit.overflow(existing, "1", 8));
    }

    @Test
    void underTheLimitDropsNothing() {
        assertEquals(List.of(), OperationsChatLimit.overflow(List.of("2", "1"), "3", 8));
    }
}
