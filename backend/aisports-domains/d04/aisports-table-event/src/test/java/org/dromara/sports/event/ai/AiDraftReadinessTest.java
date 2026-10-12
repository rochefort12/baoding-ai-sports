package org.dromara.sports.event.ai;

import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.time.OffsetDateTime;
import java.util.List;
import static org.junit.jupiter.api.Assertions.*;
import org.dromara.sports.event.ai.SportsEventRunAiTaskService.ConfirmDraft;
import org.dromara.sports.event.ai.SportsEventRunAiTaskService.UnitDraft;

@Tag("local")
class AiDraftReadinessTest {
    private final OffsetDateTime now = OffsetDateTime.parse("2026-10-09T12:00:00+08:00");
    private ConfirmDraft draft(String ends, Integer limit, String type) {
        return new ConfirmDraft("key", "青少年赛", "保定", "羽毛球", "198元/人/项，加项100元/人/项", null, null, null, ends,
            "none", null, List.of(new UnitDraft("U8男子单打", type, null, null, limit)));
    }
    @Test void pastDateReportsActualTimesAndBlocksCreation() {
        var ready = AiDraftReadiness.check(draft("2026-07-26 18:00:00", 32, "individual"), now);
        assertFalse(ready.canSaveDraft());
        assertTrue(ready.blockingIssues().get(0).message().contains("2026-07-26 18:00:00"));
        assertTrue(ready.blockingIssues().get(0).message().contains("2026-10-09 12:00:00"));
        assertEquals("EVENT_ENDED", ready.blockingIssues().get(0).code());
    }
    @Test void capacityNamesProjectAndExplainsSinglesAndPairs() {
        var single = AiDraftReadiness.check(draft(null, null, "individual"), now);
        assertTrue(single.nextStep().contains("U8男子单打"));
        assertTrue(single.nextStep().contains("1单对应1人"));
        var pair = AiDraftReadiness.check(draft(null, 0, "pair"), now);
        assertTrue(pair.nextStep().contains("1单对应2人"));
    }
    @Test void teamBoundsMustMatchActualProjectCreationConstraints() {
        assertEquals("TEAM_SIZE_REQUIRED", AiDraftReadiness.check(draft(null, 32, "team"), now).blockingIssues().get(0).code());
        for (var bounds : List.of(new Integer[]{0, 5}, new Integer[]{5, 3}, new Integer[]{null, 5})) {
            var team = new ConfirmDraft("key", "赛", "馆", "羽毛球", "待配置", null, null, null, null,
                "manual", null, List.of(new UnitDraft("团体", "team", bounds[0], bounds[1], 32)));
            assertFalse(AiDraftReadiness.check(team, now).canSaveDraft());
        }
        var valid = new ConfirmDraft("key", "赛", "馆", "羽毛球", "待配置", null, null, null, null,
            "manual", null, List.of(new UnitDraft("团体", "team", 3, 5, 32)));
        assertTrue(AiDraftReadiness.check(valid, now).canSaveDraft());
    }
    @Test void savingDoesNotClaimFeesOrPublicationAreReady() {
        var ready = AiDraftReadiness.check(draft("2026-10-25 18:00:00", 32, "individual"), now);
        assertTrue(ready.canSaveDraft());
        assertTrue(ready.nextStep().contains("明确免费或收费"));
        assertTrue(ready.nextStep().contains("保存不等于发布"));
    }
    @Test void equalityAndTimezoneUseTheSameInstant() {
        assertFalse(AiDraftReadiness.check(draft("2026-10-09T04:00:00Z", 32, "individual"), now).canSaveDraft());
    }
    @Test void invalidAndConflictingTimesAreNotSilentlyAccepted() {
        assertFalse(AiDraftReadiness.check(draft("2026-99-20", 32, "individual"), now).canSaveDraft());
        var conflicting = new ConfirmDraft("key", "赛", "馆", "羽毛球", "待配置", "2026-10-20 10:00:00", "2026-10-19 10:00:00", "2026-10-25 09:00:00", "2026-10-25 18:00:00", "manual", null,
            List.of(new UnitDraft("单打", "individual", 1, 1, 32)));
        assertTrue(AiDraftReadiness.check(conflicting, now).blockingIssues().stream().anyMatch(i -> i.code().equals("TIME_ORDER")));
    }
}
