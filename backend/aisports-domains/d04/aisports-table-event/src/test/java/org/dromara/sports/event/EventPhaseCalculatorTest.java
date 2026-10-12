package org.dromara.sports.event;

import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

@Tag("local")
class EventPhaseCalculatorTest {

    private static final ZoneOffset SHANGHAI = ZoneOffset.ofHours(8);

    @Test
    void boundaryFallsIntoTheLaterPhase() {
        OffsetDateTime registrationStart = at(10, 0);
        OffsetDateTime registrationEnd = at(12, 0);
        OffsetDateTime eventStart = at(14, 0);
        OffsetDateTime eventEnd = at(16, 0);
        assertEquals("pre_registration", EventPhaseCalculator.phase(registrationStart, registrationEnd, eventStart, eventEnd, at(9, 59)));
        assertEquals("registration", EventPhaseCalculator.phase(registrationStart, registrationEnd, eventStart, eventEnd, registrationStart));
        assertEquals("registration_closed", EventPhaseCalculator.phase(registrationStart, registrationEnd, eventStart, eventEnd, registrationEnd));
        assertEquals("ongoing", EventPhaseCalculator.phase(registrationStart, registrationEnd, eventStart, eventEnd, eventStart));
        assertEquals("finished", EventPhaseCalculator.phase(registrationStart, registrationEnd, eventStart, eventEnd, eventEnd));
    }

    @Test
    void registrationEndEqualToStartIsOngoing() {
        OffsetDateTime registrationStart = at(10, 0);
        OffsetDateTime same = at(12, 0);
        OffsetDateTime eventEnd = at(13, 0);
        assertEquals("ongoing", EventPhaseCalculator.phase(registrationStart, same, same, eventEnd, same));
        assertTrue(EventPhaseCalculator.ordered(registrationStart, same, same, eventEnd));
    }

    @Test
    void missingTimeHasNoPhase() {
        assertNull(EventPhaseCalculator.phase(null, at(12, 0), at(14, 0), at(16, 0), at(11, 0)));
        assertFalse(EventPhaseCalculator.ordered(at(12, 0), at(10, 0), at(14, 0), at(16, 0)));
    }

    private static OffsetDateTime at(int hour, int minute) {
        return OffsetDateTime.of(2026, 10, 8, hour, minute, 0, 0, SHANGHAI);
    }
}
