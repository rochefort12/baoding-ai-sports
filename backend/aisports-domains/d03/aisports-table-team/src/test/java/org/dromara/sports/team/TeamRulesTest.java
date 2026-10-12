package org.dromara.sports.team;

import org.dromara.common.core.exception.ServiceException;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

@Tag("local")
class TeamRulesTest {

    @Test
    void applyRequiresActiveTeamAndNoCurrentRelation() {
        assertDoesNotThrow(() -> TeamRules.requireCanApply(true, false, false));
        assertThrows(ServiceException.class, () -> TeamRules.requireCanApply(false, false, false));
        assertThrows(ServiceException.class, () -> TeamRules.requireCanApply(true, true, false));
        assertThrows(ServiceException.class, () -> TeamRules.requireCanApply(true, false, true));
    }

    @Test
    void inviteRequiresCaptainAndAFreeTarget() {
        assertDoesNotThrow(() -> TeamRules.requireCanInvite(true, true, false, false, false));
        assertThrows(ServiceException.class, () -> TeamRules.requireCanInvite(true, false, false, false, false));
        assertThrows(ServiceException.class, () -> TeamRules.requireCanInvite(true, true, true, false, false));
        assertThrows(ServiceException.class, () -> TeamRules.requireCanInvite(true, true, false, false, true));
    }

    @Test
    void captainCannotLeaveOrRemoveSelf() {
        assertDoesNotThrow(() -> TeamRules.requireLeave(true, "member"));
        assertThrows(ServiceException.class, () -> TeamRules.requireLeave(true, "captain"));
        assertDoesNotThrow(() -> TeamRules.requireRemove(true, true, "member"));
        assertThrows(ServiceException.class, () -> TeamRules.requireRemove(true, true, "captain"));
        assertThrows(ServiceException.class, () -> TeamRules.requireRemove(true, false, "member"));
    }

    @Test
    void transferTargetMustAlreadyBeMember() {
        assertDoesNotThrow(() -> TeamRules.requireTransfer(true, true, true, false));
        assertThrows(ServiceException.class, () -> TeamRules.requireTransfer(true, true, false, false));
        assertThrows(ServiceException.class, () -> TeamRules.requireTransfer(true, true, true, true));
        assertThrows(ServiceException.class, () -> TeamRules.requireTransfer(false, true, true, false));
    }

    @Test
    void submitRechecksCurrentTeamAndRoster() {
        assertDoesNotThrow(() -> TeamRules.requireTeamSubmit(true, true, true));
        assertThrows(ServiceException.class, () -> TeamRules.requireTeamSubmit(false, true, true));
        assertThrows(ServiceException.class, () -> TeamRules.requireTeamSubmit(true, false, true));
        assertThrows(ServiceException.class, () -> TeamRules.requireTeamSubmit(true, true, false));
    }
}
