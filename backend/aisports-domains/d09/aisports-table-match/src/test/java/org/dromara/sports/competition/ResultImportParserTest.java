package org.dromara.sports.competition;
import org.dromara.common.core.exception.ServiceException;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

@Tag("local")
class ResultImportParserTest {
    @Test void importsTheSixUserRowsWithContinuationMarks() {
        StringBuilder body = new StringBuilder();
        for (int i = 1; i <= 6; i++) body.append(String.format("%02d,A,win,2:1,21:18|18:21|21:17 \\\n", i));
        var rows = ResultImportParser.parse(body.toString());
        assertEquals(6, rows.size()); assertEquals("01", rows.get(0).code());
        for (var row : rows) { assertEquals("win", row.outcomeA()); assertEquals("loss", row.outcomeB()); assertEquals("21:18|18:21|21:17", row.games()); }
    }
    @Test void bOnlyUsesDocumentedAToBOrientationAndDrawIsComplementary() {
        var row = ResultImportParser.parse("01,B,win,1:2,18:21|21:18|17:21").get(0);
        assertEquals("loss", row.outcomeA()); assertEquals("1:2", row.summary());
        row = ResultImportParser.parse("02,A,draw,1:1,").get(0); assertEquals("draw", row.outcomeB());
    }
    @Test void acceptsLegacyComplementaryRowsButRejectsConflictsAndDuplicates() {
        assertEquals(1, ResultImportParser.parse("01,A,win,2:1,21:18\n01,B,loss,1:2,18:21").size());
        for (String body : new String[]{"01,A,win,2:1,\n01,A,win,2:1,", "01,A,win,2:1,\n01,B,win,1:2,", "01,A,win,2:1,21:18\n01,B,loss,1:2,18:22", "01,A,win,2:1,extra,column", "01,C,win,2:1,"})
            assertThrows(ServiceException.class, () -> ResultImportParser.parse(body));
    }
}
