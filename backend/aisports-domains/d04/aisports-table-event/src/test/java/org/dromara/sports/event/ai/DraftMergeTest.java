package org.dromara.sports.event.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

@Tag("local")
class DraftMergeTest {

    private final ObjectMapper mapper = new ObjectMapper();

    @Test void sourceConflictCanInvalidateAnEarlierCandidateAndRetainsFulfillmentFields() throws Exception {
        String previous="{\"event\":{\"refundTerms\":{\"value\":\"全额退款\",\"status\":\"filled\"}}}";
        String patch="{\"event\":{\"refundTerms\":{\"value\":\"\",\"status\":\"conflict\",\"alternatives\":[\"全额退款\",\"不退款\"]},\"contactMethod\":{\"value\":\"organizer@simulation.invalid\",\"status\":\"filled\",\"sources\":[{\"quote\":\"邮箱：organizer@simulation.invalid\"}]}}}";
        var merged=mapper.readTree(DraftMerge.absorb(mapper,previous,patch,null,false).proposal());
        assertEquals("",merged.path("event").path("refundTerms").path("value").asText());
        assertEquals("conflict",merged.path("event").path("refundTerms").path("status").asText());
        assertEquals(2,merged.path("event").path("refundTerms").path("alternatives").size());
        assertEquals("organizer@simulation.invalid",merged.path("event").path("contactMethod").path("value").asText());
        assertEquals(1,merged.path("event").path("contactMethod").path("sources").size());
    }

    @Test
    void modelCannotDeleteClassificationsDuringAnUnrelatedUpdate() throws Exception {
        String previous = """
            {"event":{},"units":[{"name":{"value":"亲子双打"},"entryType":{"value":"pair"}},
            {"name":{"value":"成人双打"},"entryType":{"value":"pair"}}]}
            """;
        String patch = """
            {"replaceUnits":true,"units":[{"name":{"value":"亲子双打"},"limitCount":{"value":"32"}}]}
            """;
        var merged = DraftMerge.absorb(mapper, previous, patch, "名额32单", false);
        assertEquals(2, mapper.readTree(merged.proposal()).path("units").size());
        assertTrue(merged.proposal().contains("成人双打"));
        var removed = DraftMerge.absorb(mapper, previous, patch, "只保留亲子双打", false);
        assertEquals(1, mapper.readTree(removed.proposal()).path("units").size());
    }

    @Test
    void clearChangeOverwritesAndQuestionDoesNotBecomeReview() {
        String previous = """
            {"event":{"name":{"value":"旧名称","status":"filled","sources":[],"alternatives":[]},"registrationReview":{"value":"","status":"missing","sources":[],"alternatives":[]}},"units":[{"name":{"value":"男单","status":"filled","sources":[],"alternatives":[]}}]}
            """;
        String agent = """
            {"reply":"比如核对身份证上的年龄。","suggestions":["要审核","不审核"],"action":"ask","event":{"feeDescription":{"value":"198元/人/项","status":"filled"}}}
            """;
        DraftMerge.Merged merged = DraftMerge.absorb(mapper, previous, agent, "请举个例子", true);
        assertEquals("旧名称", DraftMerge.field(mapper, merged.proposal(), "name"));
        assertEquals("198元/人/项", DraftMerge.field(mapper, merged.proposal(), "feeDescription"));
        assertEquals("", DraftMerge.field(mapper, merged.proposal(), "registrationReview"));
        assertEquals("ask", merged.action());
        assertFalse(merged.proposal().contains("\"value\":\"none\""));
    }

    @Test
    void explicitReviewValueOverwritesAndCreateIsBlockedBeforeTheUserSpeaks() {
        String agent = """
            {"reply":"好，这场不审核。","action":"create","event":{"registrationReview":{"value":"none","status":"filled"},"registrationReviewNote":{"value":"不审核"}}}
            """;
        DraftMerge.Merged first = DraftMerge.absorb(mapper, null, agent, null, false);
        assertEquals("ask", first.action());
        assertEquals("none", DraftMerge.field(mapper, first.proposal(), "registrationReview"));
        String change = """
            {"reply":"名称改成市公开赛。","action":"update","event":{"name":{"value":"市公开赛","status":"filled"}}}
            """;
        DraftMerge.Merged second = DraftMerge.absorb(mapper, first.proposal(), change, "把名称改成市公开赛", true);
        assertEquals("市公开赛", DraftMerge.field(mapper, second.proposal(), "name"));
        assertEquals("none", DraftMerge.field(mapper, second.proposal(), "registrationReview"));
        assertEquals("update", second.action());
    }

    @Test
    void chineseReviewWordIsNotMapped() {
        String agent = """
            {"reply":"我先记下你的说法。","action":"update","event":{"registrationReview":{"value":"不审核","status":"filled"}}}
            """;
        DraftMerge.Merged merged = DraftMerge.absorb(mapper, null, agent, "不审核", true);
        assertEquals("", DraftMerge.field(mapper, merged.proposal(), "registrationReview"));
    }

    @Test
    void emptyUnitListDoesNotEraseExistingUnits() {
        String previous = """
            {"event":{},"units":[{"name":{"value":"男单","status":"filled","sources":[],"alternatives":[]},"entryType":{"value":"individual","status":"filled","sources":[],"alternatives":[]}}]}
            """;
        String agent = """
            {"reply":"名称先记下。","action":"update","event":{"name":{"value":"市公开赛","status":"filled"}},"units":[]}
            """;
        DraftMerge.Merged merged = DraftMerge.absorb(mapper, previous, agent, "名称是市公开赛", true);
        assertEquals(true, merged.proposal().contains("男单"));
    }

    @Test
    void blankPatchDoesNotEraseConfirmedReviewOrQuota() {
        String previous = """
            {"event":{"registrationReview":{"value":"none","status":"filled","sources":[],"alternatives":[]}},"units":[{"name":{"value":"男单","status":"filled","sources":[],"alternatives":[]},"entryType":{"value":"individual","status":"filled","sources":[],"alternatives":[]},"limitCount":{"value":"32","status":"filled","sources":[],"alternatives":[]}}]}
            """;
        String agent = """
            {"reply":"费用还没配到项目上。","action":"ask","event":{"registrationReview":{"value":"","status":"missing"}},"units":[{"name":{"value":"男单","status":"filled"},"entryType":{"value":"","status":"missing"},"limitCount":{"value":"","status":"missing"}}]}
            """;
        DraftMerge.Merged merged = DraftMerge.absorb(mapper, previous, agent, "全部100元", true);
        assertEquals("none", DraftMerge.field(mapper, merged.proposal(), "registrationReview"));
        assertTrue(merged.proposal().contains("\"value\":\"32\""));
        assertTrue(merged.proposal().contains("\"value\":\"individual\""));
    }
}
