package org.dromara.sports.event.ai;

import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.event.ai.SportsEventRunAiTaskService.UnitDraft;
import java.math.BigDecimal;
import java.util.*;

/** Source fees are candidate prices, never payment facts. Only an explicit per-order plan can become an initial draft policy. */
public final class AiFeeProposalPlan {
    private AiFeeProposalPlan() { }
    public static boolean present(List<UnitDraft> units) {
        return units != null && units.stream().anyMatch(u -> !blank(u.feeAmount()) || !blank(u.feeBasis()) || "conflict".equals(u.feeStatus()));
    }
    public static List<AiDraftReadiness.Issue> issues(List<UnitDraft> units) {
        if (!present(units)) return List.of(); // Old unpriced drafts remain editable; absence is never free.
        var issues = new ArrayList<AiDraftReadiness.Issue>();
        for (int i=0;i<units.size();i++) {
            var unit=units.get(i); String label="「"+unit.name()+"」", field="units["+i+"].feeAmount";
            if ("conflict".equals(unit.feeStatus())) issues.add(new AiDraftReadiness.Issue("FEE_CONFLICT",field,label+"费用有矛盾，请确认每单总价；不会任选金额"));
            else if (!"order".equals(unit.feeBasis())) issues.add(new AiDraftReadiness.Issue("FEE_BASIS_REQUIRED",field,label+"请确认整单总价；按人、附加或未明确计费不能直接转为报名价格"));
            else if (!"filled".equals(unit.feeStatus()) || !valid(unit.feeAmount())) issues.add(new AiDraftReadiness.Issue("FEE_AMOUNT_REQUIRED",field,label+"请补充明确的每单金额（元，最多两位小数）；未填不代表免费"));
        }
        return List.copyOf(issues);
    }
    public static BigDecimal amount(UnitDraft unit) {
        if (!issues(List.of(unit)).isEmpty()) throw new ServiceException(issues(List.of(unit)).get(0).message());
        return new BigDecimal(unit.feeAmount()).setScale(2);
    }
    private static boolean valid(String text) {
        if (blank(text) || !text.matches("(?:0|[1-9][0-9]{0,7})(?:\\.[0-9]{1,2})?")) return false;
        return new BigDecimal(text).signum()>=0;
    }
    private static boolean blank(String text) { return text==null || text.isBlank(); }
}
