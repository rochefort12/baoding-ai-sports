package org.dromara.sports.team;

import org.dromara.common.core.exception.ServiceException;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.time.OffsetDateTime;
import static org.junit.jupiter.api.Assertions.*;

@Tag("local")
class TeamShareRulesTest {
    private final OffsetDateTime now = OffsetDateTime.parse("2026-10-12T12:00:00+08:00");

    @Test void randomTokensAreBoundedAndDistinct() {
        var first = TeamShareRules.newToken();
        assertEquals(64, first.length());
        assertEquals(first, TeamShareRules.token(first));
        assertNotEquals(first, TeamShareRules.newToken());
    }
    @Test void malformedTokensDoNotEnterLookup() {
        for (String value : new String[]{"", "a".repeat(63), "G".repeat(64), "../" + "a".repeat(64)})
            assertThrows(ServiceException.class, () -> TeamShareRules.token(value));
        assertThrows(ServiceException.class, () -> TeamShareRules.token(null));
    }
    @Test void expirationBoundaryIsExclusive() {
        assertEquals("pending", TeamShareRules.status("pending", true, true, now.plusSeconds(1), now));
        assertEquals("expired", TeamShareRules.status("pending", true, true, now, now));
    }
    @Test void transferAndDisbandInvalidateEvenBeforeExpiry() {
        assertEquals("invalidated", TeamShareRules.status("pending", true, false, now.plusDays(7), now));
        assertEquals("invalidated", TeamShareRules.status("pending", false, true, now.plusDays(7), now));
    }
    @Test void revocationDoesNotResurfaceAsAnotherStatus() {
        assertEquals("revoked", TeamShareRules.status("revoked", true, true, now.minusDays(1), now));
    }
    @Test void explicitConsentIsRequired() {
        assertThrows(ServiceException.class, () -> TeamShareRules.requireAccept("pending", false, false, false));
    }
    @Test void removedMemberCannotReuseOldShareButCurrentMemberMayRetry() {
        assertThrows(ServiceException.class, () -> TeamShareRules.requireAccept("pending", true, false, true));
        assertDoesNotThrow(() -> TeamShareRules.requireAccept("pending", true, true, true));
    }
    @Test void invalidatedShareNeverAddsAnotherMember() {
        for (String status : new String[]{"revoked", "expired", "invalidated"})
            assertThrows(ServiceException.class, () -> TeamShareRules.requireAccept(status, false, false, true));
    }
}
