package org.dromara.sports.finance;

import org.dromara.common.core.exception.ServiceException;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

@Tag("local")
class FeeRulesTest {

    @Test
    void freeDoesNotRequirePayment() {
        assertEquals("not_required", FeeRules.obligationStatus("free", BigDecimal.ZERO));
        assertThrows(ServiceException.class, () -> FeeRules.obligationStatus("free", new BigDecimal("10")));
        assertEquals("open", FeeRules.obligationStatus("offline", new BigDecimal("50.00")));
    }

    @Test
    void unpaidCloseVoidsAndPaidCloseKeepsSettlement() {
        assertEquals("void", FeeRules.afterEntryClosed("open"));
        assertEquals("void", FeeRules.afterEntryClosed("not_required"));
        assertEquals("settled", FeeRules.afterEntryClosed("settled"));
        assertTrue(FeeRules.opensActionCase("settled"));
        assertFalse(FeeRules.opensActionCase("open"));
    }

    @Test
    void reversalReopensOnlyALiveEntry() {
        assertEquals("open", FeeRules.afterReversal(true, "settled"));
        assertEquals("void", FeeRules.afterReversal(false, "settled"));
        assertEquals("void", FeeRules.afterReversal(false, "void"));
    }
}
