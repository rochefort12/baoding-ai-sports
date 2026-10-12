package org.dromara.sports.event.service;

import java.time.OffsetDateTime;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertEquals;

/** Same real instant must yield the public Beijing deadline, regardless of storage offset. */
@Tag("local")
class EventMaterialTimeTest {
    @Test void utcStorageRendersBeijingTime() {
        assertEquals("2026-10-11 14:18", EventMaterialService.localDeadline(OffsetDateTime.parse("2026-10-11T06:18:12Z")));
        assertEquals("2026-10-11 14:18", EventMaterialService.localDeadline(OffsetDateTime.parse("2026-10-11T14:18:12+08:00")));
    }
    @Test void missingDeadlineStaysMissingAndDateRolloverIsCorrect() {
        assertEquals("", EventMaterialService.localDeadline(null));
        assertEquals("2026-10-12 01:18", EventMaterialService.localDeadline(OffsetDateTime.parse("2026-10-11T17:18:12Z")));
    }
}
