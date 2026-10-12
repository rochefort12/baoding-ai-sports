package org.dromara.sports.event.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import java.time.OffsetDateTime;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

@Tag("local")
class OperationsChatDocumentTest {

    @Test
    void laterTurnsDoNotExtendTheOriginalDeadline() {
        OffsetDateTime start = OffsetDateTime.parse("2026-10-09T10:30:00+08:00");
        OperationsChatDocument created = OperationsChatDocument.create("11111111-1111-1111-1111-111111111111", start);
        OperationsChatDocument once = created.append("第一句", "第一答");
        OperationsChatDocument twice = once.append("过了一小时再问", "第二答");
        assertEquals(start.plusHours(24), once.expiresAt());
        assertEquals(once.expiresAt(), twice.expiresAt());
        assertEquals(4, twice.turns().size());
        assertEquals("过了一小时再问", twice.preview());
    }

    @Test
    void oldestTurnsDropAfterForty() {
        OperationsChatDocument document = OperationsChatDocument.create("11111111-1111-1111-1111-111111111111", OffsetDateTime.parse("2026-10-09T10:30:00+08:00"));
        for (int i = 0; i < 21; i++) {
            document = document.append("问" + i, "答" + i);
        }
        assertEquals(40, document.turns().size());
        assertEquals("问1", document.turns().get(0).text());
        assertEquals("答20", document.turns().get(39).text());
    }

    @Test
    void roundTripKeepsTheDeadline() {
        OffsetDateTime start = OffsetDateTime.parse("2026-10-09T10:30:00+08:00");
        OperationsChatDocument document = OperationsChatDocument.create("11111111-1111-1111-1111-111111111111", start).append("报名还有几单", "还有1单");
        OperationsChatDocument parsed = OperationsChatDocument.parse(document.id(), document.json(new ObjectMapper()), new ObjectMapper());
        assertEquals(document.expiresAt(), parsed.expiresAt());
        assertEquals("报名还有几单", parsed.turns().get(0).text());
        assertTrue(parsed.expiresAt().isAfter(start.plusHours(23)));
    }
}
