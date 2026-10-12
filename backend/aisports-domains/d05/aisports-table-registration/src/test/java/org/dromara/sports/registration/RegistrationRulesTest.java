package org.dromara.sports.registration;

import org.dromara.common.core.exception.ServiceException;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

@Tag("local")
class RegistrationRulesTest {

    private static final ZoneOffset SHANGHAI = ZoneOffset.ofHours(8);

    @Test
    void entryTypeFixesSinglesAndDoubles() {
        assertEquals(new RegistrationRules.MemberBounds(1, 1), RegistrationRules.bounds("individual", 9, 9));
        assertEquals(new RegistrationRules.MemberBounds(2, 2), RegistrationRules.bounds("pair", null, null));
        assertEquals(new RegistrationRules.MemberBounds(3, 5), RegistrationRules.bounds("team", 3, 5));
        assertThrows(ServiceException.class, () -> RegistrationRules.bounds("team", 5, 3));
    }

    @Test
    void windowBoundaryBelongsToTheLaterPhase() {
        OffsetDateTime opens = at(10, 0);
        OffsetDateTime closes = at(12, 0);
        assertFalse(RegistrationRules.windowOpen(opens, closes, at(9, 59)));
        assertTrue(RegistrationRules.windowOpen(opens, closes, opens));
        assertFalse(RegistrationRules.windowOpen(opens, closes, closes));
        assertTrue(RegistrationRules.beforeClose(closes, at(11, 0)));
        assertFalse(RegistrationRules.beforeClose(closes, closes));
    }

    @Test
    void sameRequestKeyDoesNotOccupyAgain() {
        assertEquals(RegistrationRules.RETURN, RegistrationRules.submitAction("submitted", "k1", "k1", true, true));
        assertEquals(RegistrationRules.RETURN, RegistrationRules.submitAction("approved", "k1", "k1", true, true));
        assertEquals(RegistrationRules.RETURN, RegistrationRules.submitAction("rejected", "k1", "k1", true, true));
        assertEquals(RegistrationRules.OCCUPY, RegistrationRules.submitAction("draft", "k1", "k1", false, false));
        assertEquals(RegistrationRules.RETURN, RegistrationRules.submitAction("draft", "k1", "k1", true, true));
        assertEquals(RegistrationRules.REPLACE, RegistrationRules.submitAction("draft", "k1", "k2", false, true));
        assertEquals(RegistrationRules.RETURN, RegistrationRules.submitAction("draft", "k2", "k1", true, true));
        assertEquals(RegistrationRules.REPLACE, RegistrationRules.submitAction("rejected", "k1", "k2", false, true));
        assertThrows(ServiceException.class, () -> RegistrationRules.submitAction("submitted", "k1", "k2", false, true));
        assertThrows(ServiceException.class, () -> RegistrationRules.submitAction("draft", "k1", "k2", false, false));
        assertThrows(ServiceException.class, () -> RegistrationRules.submitAction("approved", "k1", "k2", false, true));
    }

    private static OffsetDateTime at(int hour, int minute) {
        return OffsetDateTime.of(2026, 10, 5, hour, minute, 0, 0, SHANGHAI);
    }
}
