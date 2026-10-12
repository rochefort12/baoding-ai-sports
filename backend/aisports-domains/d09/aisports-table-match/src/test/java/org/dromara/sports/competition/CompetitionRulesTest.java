package org.dromara.sports.competition;

import org.dromara.common.core.exception.ServiceException;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

@Tag("local")
class CompetitionRulesTest {

    @Test
    void outcomesAreComplementaryForEveryPair() {
        String[] outcomes = {"win", "loss", "draw", "", "other"};
        for (String a : outcomes) for (String b : outcomes) {
            boolean valid = (a.equals("win") && b.equals("loss")) || (a.equals("loss") && b.equals("win")) || (a.equals("draw") && b.equals("draw"));
            if (valid) assertDoesNotThrow(() -> CompetitionRules.requireComplementary(a, b));
            else assertThrows(ServiceException.class, () -> CompetitionRules.requireComplementary(a, b));
        }
    }

    @Test
    void draftCanChangeAndFinalRejectsDifferentContent() {
        assertDoesNotThrow(() -> CompetitionRules.rejectChangedFinal("draft", "21:18", "21:17"));
        assertThrows(ServiceException.class, () -> CompetitionRules.rejectChangedFinal("confirmed", "21:18", "21:17"));
    }

    @Test
    void identicalFinalIsNotANewWrite() {
        assertDoesNotThrow(() -> CompetitionRules.rejectChangedFinal("confirmed", "win", "win"));
        assertTrue(CompetitionRules.isFinal("confirmed"));
    }
}
