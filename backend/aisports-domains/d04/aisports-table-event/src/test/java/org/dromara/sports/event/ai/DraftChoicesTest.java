package org.dromara.sports.event.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import java.time.OffsetDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

@Tag("local")
class DraftChoicesTest {
    private final ObjectMapper mapper = new ObjectMapper();
    private final OffsetDateTime now = OffsetDateTime.parse("2026-10-09T12:00:00+08:00");

    @Test
    void conflictingReviewBecomesOptionsBeforeOtherReadings() {
        String proposal = event("""
            "registrationReview":{"value":"","status":"conflict","sources":[],"alternatives":["none","manual"]},
            "location":{"value":"辽宁体育馆","status":"conflict","sources":[],"alternatives":["李永波羽毛球俱乐部"]},
            "registrationOpensAt":{"value":"2026-10-09 00:00:00","status":"filled","sources":[],"alternatives":[]},
            "registrationClosesAt":{"value":"2026-10-12 00:00:00","status":"filled","sources":[],"alternatives":[]},
            "startsAt":{"value":"2026-10-17 09:00:00","status":"filled","sources":[],"alternatives":[]},
            "endsAt":{"value":"2026-10-18 18:00:00","status":"filled","sources":[],"alternatives":[]}
            """, unit("羽毛球个人", "individual", "32"));
        DraftChoices.Turn turned = DraftChoices.finish(mapper, proposal, "报名审核您选哪种？", "看看", now, false);
        assertTrue(turned.suggestions().containsAll(List.of("人工审核", "无需人工审核")));
        assertFalse(turned.suggestions().contains("地点就用辽宁体育馆"));
    }

    @Test
    void pastCompetitionOffersAConcreteLaterWeekendNotAnotherOpenQuestion() {
        String proposal = event("""
            "registrationReview":{"value":"none","status":"filled","sources":[],"alternatives":[]},
            "registrationOpensAt":{"value":"2026-10-09 00:00:00","status":"filled","sources":[],"alternatives":[]},
            "registrationClosesAt":{"value":"2026-10-12 00:00:00","status":"filled","sources":[],"alternatives":[]},
            "startsAt":{"value":"2026-06-27 00:00:00","status":"filled","sources":[],"alternatives":[]},
            "endsAt":{"value":"2026-06-28 00:00:00","status":"filled","sources":[],"alternatives":[]}
            """, unit("羽毛球个人", "individual", "32"));
        DraftChoices.Turn turned = DraftChoices.finish(mapper, proposal,
            "比赛是6月，报名是10月，您看改比赛还是改报名？另外竞赛项目费用还没配。", "请生成赛事", now, true);
        assertTrue(turned.suggestions().stream().anyMatch(item -> item.equals("把比赛改到2026-10-17 09:00:00至2026-10-18 18:00:00")), turned.suggestions().toString());
        assertFalse(turned.suggestions().contains(DraftChoices.CONFIRM));
        assertFalse(turned.reply().contains("请明确说"));
        assertTrue(turned.reply().contains("2026-06-28") || turned.reply().contains("已经过去") || turned.reply().contains("早于"));
    }

    @Test
    void choosingTheLaterWeekendMovesCompetitionAndKeepsRegistration() {
        String proposal = event("""
            "registrationReview":{"value":"none","status":"filled","sources":[],"alternatives":[]},
            "registrationOpensAt":{"value":"2026-10-09 00:00:00","status":"filled","sources":[],"alternatives":[]},
            "registrationClosesAt":{"value":"2026-10-12 00:00:00","status":"filled","sources":[],"alternatives":[]},
            "startsAt":{"value":"2026-06-27 00:00:00","status":"filled","sources":[],"alternatives":[]},
            "endsAt":{"value":"2026-06-28 00:00:00","status":"filled","sources":[],"alternatives":[]}
            """, unit("羽毛球个人", "individual", "32"));
        DraftChoices.Turn turned = DraftChoices.tryApply(mapper, proposal, "把比赛改到2026-10-17 09:00:00至2026-10-18 18:00:00", now);
        assertEquals("2026-10-17 09:00:00", DraftMerge.field(mapper, turned.proposal(), "startsAt"));
        assertEquals("2026-10-18 18:00:00", DraftMerge.field(mapper, turned.proposal(), "endsAt"));
        assertEquals("2026-10-12 00:00:00", DraftMerge.field(mapper, turned.proposal(), "registrationClosesAt"));
        assertTrue(turned.suggestions().contains(DraftChoices.CONFIRM));
    }

    @Test
    void confirmedFeeIsNotAskedAgainAndStaysOutOfThePriceBook() {
        String proposal = event("""
            "feeDescription":{"value":"参赛服务费198元/人/项，加项100元/人/项","status":"filled","sources":[],"alternatives":[]},
            "registrationReview":{"value":"none","status":"filled","sources":[],"alternatives":[]},
            "registrationOpensAt":{"value":"2026-10-09 00:00:00","status":"filled","sources":[],"alternatives":[]},
            "registrationClosesAt":{"value":"2026-10-12 00:00:00","status":"filled","sources":[],"alternatives":[]},
            "startsAt":{"value":"2026-10-17 09:00:00","status":"filled","sources":[],"alternatives":[]},
            "endsAt":{"value":"2026-10-18 18:00:00","status":"filled","sources":[],"alternatives":[]}
            """, unit("羽毛球个人", "individual", "32"));
        DraftChoices.Turn first = DraftChoices.finish(mapper, withDialogue(proposal, "各项目费用怎么配？"),
            "三个项目各自的费用还没配，您说一下。", "每项100元", now, false);
        assertTrue(first.proposal().contains("\"effective\":false"));
        assertTrue(first.proposal().contains("每项100元"));
        assertFalse(first.reply().contains("还没配"));
        DraftChoices.Turn again = DraftChoices.finish(mapper, first.proposal(),
            "竞赛项目费用还没配到具体项目上。您把三个项目各自的费用说一下。", "好的", now, false);
        assertFalse(again.reply().contains("还没配"));
        assertFalse(again.reply().contains("说一下"));
        assertTrue(again.suggestions().contains(DraftChoices.CONFIRM));
    }

    @Test
    void allEntryFormsAndReviewStick() {
        String proposal = event("""
            "registrationReview":{"value":"","status":"missing","sources":[],"alternatives":[]},
            "projectName":{"value":"羽毛球","status":"filled","sources":[],"alternatives":[]}
            """, "");
        DraftChoices.Turn review = DraftChoices.tryApply(mapper, proposal, "无需人工审核", now);
        assertEquals("none", DraftMerge.field(mapper, review.proposal(), "registrationReview"));
        DraftChoices.Turn forms = DraftChoices.tryApply(mapper, review.proposal(), "都要", now);
        assertTrue(forms.proposal().contains("羽毛球个人"));
        assertTrue(forms.proposal().contains("羽毛球双人"));
        assertTrue(forms.proposal().contains("羽毛球团体"));
        assertTrue(forms.proposal().contains("individual"));
        assertTrue(forms.proposal().contains("pair"));
        assertTrue(forms.proposal().contains("team"));
        DraftChoices.Turn repeated = DraftChoices.finish(mapper, forms.proposal(), "参赛形式按个人、双人还是团体？", "再问一次", now, false);
        assertFalse(repeated.reply().contains("个人、双人还是团体"));
    }

    @Test
    void statedQuotaFillsEveryOpenUnit() {
        String proposal = event("""
            "registrationReview":{"value":"none","status":"filled","sources":[],"alternatives":[]}
            """, unit("羽毛球个人", "individual", "") + "," + unit("羽毛球双人", "pair", ""));
        DraftChoices.Turn turned = DraftChoices.tryApply(mapper, proposal, "项目是32人", now);
        assertTrue(turned.proposal().contains("\"value\":\"32\""));
        assertFalse(turned.reply().contains("还缺报名上限"));
    }

    @Test
    void placeConflictOffersTheReadings() {
        String proposal = event("""
            "registrationReview":{"value":"none","status":"filled","sources":[],"alternatives":[]},
            "location":{"value":"","status":"conflict","sources":[],"alternatives":["辽宁体育馆","李永波羽毛球俱乐部"]},
            "registrationOpensAt":{"value":"2026-10-09 00:00:00","status":"filled","sources":[],"alternatives":[]},
            "registrationClosesAt":{"value":"2026-10-12 00:00:00","status":"filled","sources":[],"alternatives":[]},
            "startsAt":{"value":"2026-10-17 09:00:00","status":"filled","sources":[],"alternatives":[]},
            "endsAt":{"value":"2026-10-18 18:00:00","status":"filled","sources":[],"alternatives":[]}
            """, unit("羽毛球个人", "individual", "32"));
        DraftChoices.Turn turned = DraftChoices.finish(mapper, proposal, "地点有两种读法。", "看看", now, false);
        assertTrue(turned.suggestions().contains("地点就用辽宁体育馆"));
        assertTrue(turned.suggestions().contains("地点就用李永波羽毛球俱乐部"));
        DraftChoices.Turn chosen = DraftChoices.tryApply(mapper, proposal, "地点就用李永波羽毛球俱乐部", now);
        assertEquals("李永波羽毛球俱乐部", DraftMerge.field(mapper, chosen.proposal(), "location"));
        assertTrue(chosen.proposal().contains("\"status\":\"filled\""));
    }

    @Test
    void unrelatedSentenceIsNotTreatedAsAChoice() {
        String proposal = event("""
            "registrationReview":{"value":"","status":"missing","sources":[],"alternatives":[]}
            """, "");
        assertNull(DraftChoices.tryApply(mapper, proposal, "今天天气怎么样", now));
        assertFalse(DraftChoices.askedToSave("创建赛事吗？"));
        assertTrue(DraftChoices.askedToSave("请生成赛事"));
        assertTrue(DraftChoices.askedToSave("直接生成吧"));
    }

    @Test
    void teamRangeReplyUpdatesRealFieldsAndSurvivesLaterEmptyModelValues() throws Exception {
        String proposal = event("\"registrationReview\":{\"value\":\"manual\",\"status\":\"filled\"}",
            unit("个人", "individual", "32") + "," + unit("双人", "pair", "32") + "," + unit("团体", "team", "32"));
        DraftChoices.Turn opened = DraftChoices.tryApply(mapper, proposal, "报名从今天开始", now);
        assertEquals("2026-10-09 00:00:00", DraftMerge.field(mapper, opened.proposal(), "registrationOpensAt"));
        DraftChoices.Turn closed = DraftChoices.tryApply(mapper, opened.proposal(), "报名截止改成2026-10-12 00:00:00", now);
        assertEquals("2026-10-12 00:00:00", DraftMerge.field(mapper, closed.proposal(), "registrationClosesAt"));
        proposal = closed.proposal();
        DraftChoices.Turn missing = DraftChoices.finish(mapper, proposal, "", DraftChoices.CONFIRM, now, true);
        assertTrue(missing.reply().contains("团体人数"));
        assertFalse(missing.suggestions().contains(DraftChoices.CONFIRM));
        for (String reply : List.of("3-5人吧", "3-5人", "团体3至5人")) {
            DraftChoices.Turn applied = DraftChoices.tryApply(mapper, proposal, reply, now);
            assertNotNull(applied, reply);
            var team = mapper.readTree(applied.proposal()).path("units").get(0);
            assertEquals("3", team.path("minMembers").path("value").asText());
            assertEquals("5", team.path("maxMembers").path("value").asText());
            assertTrue(applied.suggestions().contains(DraftChoices.CONFIRM));
            String emptyModel = "{\"reply\":\"好的\",\"units\":[{\"name\":\"团体\",\"minMembers\":null,\"maxMembers\":null}]}";
            DraftMerge.Merged merged = DraftMerge.absorb(mapper, applied.proposal(), emptyModel, "好的", false);
            DraftChoices.Turn next = DraftChoices.finish(mapper, merged.proposal(), merged.reply(), "好的", now, false);
            assertTrue(next.suggestions().contains(DraftChoices.CONFIRM));
        }
        assertNull(DraftChoices.tryApply(mapper, proposal, "5-3人", now));
        assertNull(DraftChoices.tryApply(mapper, proposal, "0-5人", now));
        String multiple = event("\"registrationReview\":{\"value\":\"manual\",\"status\":\"filled\"}",
            unit("男子团体", "team", "32") + "," + unit("女子团体", "team", "32"));
        assertNull(DraftChoices.tryApply(mapper, multiple, "3-5人", now));
    }

    @Test
    void choosingEntryFormsPreservesEverySourceClassificationEvenWhenSuggested() throws Exception {
        for (List<String> names : List.of(List.of("U8男子单打", "U10女子双打"),
            List.of("业余男子单打", "职业男子单打", "职业女子双打"),
            List.of("亲子双打", "成人双打"))) {
            String units = names.stream().map(name -> unit(name, name.contains("单打") ? "individual" : "pair", "32")
                .replace("\"status\":\"filled\"", "\"status\":\"suggestion\""))
                .collect(java.util.stream.Collectors.joining(","));
            String proposal = event("\"registrationReview\":{\"value\":\"manual\",\"status\":\"filled\"}", units);
            DraftChoices.Turn all = DraftChoices.tryApply(mapper, proposal, "都要", now);
            assertNotNull(all);
            var preserved = mapper.readTree(all.proposal()).path("units");
            for (String name : names) {
                assertTrue(java.util.stream.StreamSupport.stream(preserved.spliterator(), false)
                    .anyMatch(item -> name.equals(item.path("name").path("value").asText())), name);
            }
            DraftChoices.Turn single = DraftChoices.tryApply(mapper, proposal, "双人", now);
            assertNotNull(single);
            assertEquals(names.size(), mapper.readTree(single.proposal()).path("units").size());
        }
    }

    private String event(String eventFields, String units) {
        return """
            {"version":1,"event":{"name":{"value":"2026年全国青少年体育联合会青少年羽毛球巡回赛（沈阳站）","status":"filled","sources":[],"alternatives":[]},
            "projectName":{"value":"羽毛球","status":"filled","sources":[],"alternatives":[]},
            "feeDescription":{"value":"参赛服务费198元/人/项，加项100元/人/项","status":"filled","sources":[],"alternatives":[]},
            %s},"units":[%s]}
            """.formatted(eventFields, units);
    }

    private String unit(String name, String entry, String limit) {
        String limitStatus = limit.isBlank() ? "missing" : "filled";
        return """
            {"name":{"value":"%s","status":"filled","sources":[],"alternatives":[]},"entryType":{"value":"%s","status":"filled","sources":[],"alternatives":[]},"limitCount":{"value":"%s","status":"%s","sources":[],"alternatives":[]}}
            """.formatted(name, entry, limit, limitStatus);
    }

    private String withDialogue(String proposal, String previousAi) {
        return proposal.substring(0, proposal.lastIndexOf('}')) + ",\"dialogue\":[{\"role\":\"ai\",\"text\":\"" + previousAi + "\"}]}";
    }
}
