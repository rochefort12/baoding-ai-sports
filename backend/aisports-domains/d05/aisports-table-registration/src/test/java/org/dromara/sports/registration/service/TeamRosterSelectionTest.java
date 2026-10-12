package org.dromara.sports.registration.service;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Tag;
import org.dromara.common.core.exception.ServiceException;
import java.util.List;
import java.util.Arrays;
import static org.junit.jupiter.api.Assertions.*;

@Tag("local")
class TeamRosterSelectionTest {
    @Test void pairMustHaveTwoDifferentActualAccounts() {
        assertEquals(List.of(1L, 2L), TeamRosterSelection.checked(List.of(2L, 1L), 2, 2));
        assertThrows(ServiceException.class, () -> TeamRosterSelection.checked(List.of(1L, 1L), 2, 2));
    }
    @Test void rejectsMissingAndOutOfRangePlayers() {
        assertThrows(ServiceException.class, () -> TeamRosterSelection.checked(List.of(), 2, 2));
        assertThrows(ServiceException.class, () -> TeamRosterSelection.checked(List.of(1L, 2L, 3L), 2, 2));
        assertThrows(ServiceException.class, () -> TeamRosterSelection.checked(Arrays.asList(1L, null), 2, 2));
        assertThrows(ServiceException.class, () -> TeamRosterSelection.checked(List.of(0L, 2L), 2, 2));
    }
    @Test void replayDoesNotDependOnDisplayOrder() {
        assertEquals(TeamRosterSelection.digest(10L, 20L, List.of(1L, 2L)), TeamRosterSelection.digest(10L, 20L, List.of(2L, 1L)));
    }
    @Test void differentRosterTeamOrProjectCannotReusePayload() {
        String digest = TeamRosterSelection.digest(10L, 20L, List.of(1L, 2L));
        assertNotEquals(digest, TeamRosterSelection.digest(10L, 20L, List.of(1L, 3L)));
        assertNotEquals(digest, TeamRosterSelection.digest(11L, 20L, List.of(1L, 2L)));
        assertNotEquals(digest, TeamRosterSelection.digest(10L, 21L, List.of(1L, 2L)));
    }
}
