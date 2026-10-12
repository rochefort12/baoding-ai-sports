package org.dromara.sports.event.ai;

import org.dromara.sports.event.ai.SportsEventRunAiTaskService.UnitDraft;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
import java.util.List;
import static org.junit.jupiter.api.Assertions.*;

@Tag("local")
class AiFeeProposalTest {
    private UnitDraft fee(String amount,String basis,String status) { return new UnitDraft("双打","pair",2,2,4,amount,basis,status); }
    @Test void explicitOrderAndExplicitZeroAreCandidatePricesNotReceipts() {
        assertTrue(AiFeeProposalPlan.issues(List.of(fee("40.00","order","filled"))).isEmpty());
        assertEquals(new BigDecimal("40.00"),AiFeeProposalPlan.amount(fee("40","order","filled")));
        assertEquals(new BigDecimal("0.00"),AiFeeProposalPlan.amount(fee("0","order","filled")));
        assertFalse(AiFeeProposalPlan.present(List.of(new UnitDraft("旧未定价","individual",1,1,8))));
    }
    @Test void partialConflictPerPersonAdditionalAndInvalidAmountsRequireQuestions() {
        for (var unit:List.of(fee("20","per_person","filled"),fee("20","additional","filled"),fee("","order","conflict"),fee("-1","order","filled"),fee("1.001","order","filled"),fee("","order","missing")))
            assertFalse(AiFeeProposalPlan.issues(List.of(unit)).isEmpty());
        assertFalse(AiFeeProposalPlan.issues(List.of(fee("20","order","filled"),new UnitDraft("另一组","pair",2,2,4))).isEmpty());
    }
}
