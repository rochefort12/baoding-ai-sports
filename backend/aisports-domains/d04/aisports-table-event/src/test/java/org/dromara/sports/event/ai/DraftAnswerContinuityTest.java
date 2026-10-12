package org.dromara.sports.event.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Tag;
import java.time.OffsetDateTime;
import static org.junit.jupiter.api.Assertions.*;

@Tag("local")
class DraftAnswerContinuityTest {
    private final ObjectMapper mapper = new ObjectMapper();
    private final OffsetDateTime now = OffsetDateTime.parse("2026-10-12T19:00:00+08:00");
    private ObjectNode draft(String type, int min, int max) {
        ObjectNode root=mapper.createObjectNode(),event=root.putObject("event");
        value(event,"name","测试赛");value(event,"registrationReview","manual");value(event,"rulesText","保留原资格和退改规定");
        value(event,"registrationOpensAt","2026-10-12 18:00:00");value(event,"registrationClosesAt","2026-10-15 18:00:00");value(event,"startsAt","2026-10-16 09:00:00");value(event,"endsAt","2026-10-16 18:00:00");
        ObjectNode unit=root.putArray("units").addObject();value(unit,"name","公开组");value(unit,"entryType",type);value(unit,"minMembers",Integer.toString(min));value(unit,"maxMembers",Integer.toString(max));value(unit,"limitCount","16");
        root.putArray("dialogue"); return root;
    }
    private void value(ObjectNode node,String name,String value){node.putObject(name).put("value",value).put("status","filled");}

    @Test void missingReviewDefaultsToNoneWithoutAsking() throws Exception {
        var root=draft("individual",1,1);root.withObject("event").remove("registrationReview");
        var turn=DraftChoices.finish(mapper,root.toString(),"报名是否需要人工审核？","请整理",now,false);
        var after=mapper.readTree(turn.proposal());assertEquals("none",after.at("/event/registrationReview/value").asText());assertEquals("default",after.at("/event/registrationReview/sources/0/kind").asText());assertFalse(turn.reply().contains("是否需要人工审核"));assertFalse(turn.suggestions().contains("人工审核"));
    }
    @Test void ungroundedReviewSuggestionUsesApprovedDefault() {
        var root=draft("individual",1,1);root.withObject("event").putObject("registrationReview").put("value","manual").put("status","suggestion").putArray("sources");DraftChoices.applyDefaults(root);assertEquals("none",root.at("/event/registrationReview/value").asText());
    }
    @Test void explicitManualReviewIsPreserved() {
        var root=draft("individual",1,1);DraftChoices.applyDefaults(root);assertEquals("manual",root.at("/event/registrationReview/value").asText());
    }
    @Test void realReviewConflictIsNotSilentlyDefaulted() {
        var root=draft("individual",1,1);root.withObject("event").putObject("registrationReview").put("value","").put("status","conflict");DraftChoices.applyDefaults(root);assertEquals("conflict",root.at("/event/registrationReview/status").asText());
    }
    @Test void userCanSwitchDefaultToManual() throws Exception {
        var root=draft("individual",1,1);root.withObject("event").remove("registrationReview");DraftChoices.applyDefaults(root);
        var turn=DraftChoices.tryApply(mapper,root.toString(),"人工审核",now);assertNotNull(turn);assertEquals("manual",mapper.readTree(turn.proposal()).at("/event/registrationReview/value").asText());
    }
    @Test void defaultReviewDoesNotInventAFreePrice() throws Exception {
        var root=draft("pair",2,2);root.withObject("event").remove("registrationReview");
        var turn=DraftChoices.finish(mapper,root.toString(),"已整理","请整理",now,false);var after=mapper.readTree(turn.proposal());assertEquals("none",after.at("/event/registrationReview/value").asText());assertTrue(after.at("/units/0/feeAmount/value").asText("").isBlank());assertFalse(turn.suggestions().contains("人工审核"));
    }

    @Test void pairPerPersonAnswerWritesActualCandidatePriceAndPreservesQuota() throws Exception {
        var root=draft("pair",2,2);var turn=DraftChoices.tryApply(mapper,root.toString(),"每人收费50.50元",now);
        assertNotNull(turn);var after=mapper.readTree(turn.proposal());
        assertEquals("101.00",after.at("/units/0/feeAmount/value").asText());assertEquals("order",after.at("/units/0/feeBasis/value").asText());
        assertEquals("16",after.at("/units/0/limitCount/value").asText());assertEquals(1,after.path("units").size());
        assertTrue(after.at("/units/0/feeAmount/sources/0/quote").asText().contains("50.50"));
    }
    @Test void orderFeeDoesNotMultiplyAgain() throws Exception {
        var turn=DraftChoices.tryApply(mapper,draft("pair",2,2).toString(),"每组80元",now);
        assertEquals("80",mapper.readTree(turn.proposal()).at("/units/0/feeAmount/value").asText());
    }
    @Test void explicitAllProjectAmountReplacesUnresolvedFeesWithoutRepeatedTotalQuestion() throws Exception {
        for (String message : java.util.List.of("全部项目100元", "所有项目100元", "每项100元", "全部项目每项100.50元")) {
            var root=draft("pair",2,2);
            var second=((ObjectNode)root.path("units").get(0)).deepCopy();value(second,"name","第二组");value(second,"entryType","team");value(second,"minMembers","3");value(second,"maxMembers","5");root.withArray("units").add(second);
            for(var unit:root.path("units")){value((ObjectNode)unit,"feeAmount","50");value((ObjectNode)unit,"feeBasis","unknown");}
            root.putObject("nextQuestion").put("text","公开组请确认整单总价").put("field","units[0].feeAmount");
            var turn=DraftChoices.tryApply(mapper,root.toString(),message,now);assertNotNull(turn);
            var after=mapper.readTree(turn.proposal());String amount=message.contains("100.50")?"100.50":"100";
            for(var unit:after.path("units")){assertEquals(amount,unit.at("/feeAmount/value").asText());assertEquals("order",unit.at("/feeBasis/value").asText());assertEquals(message,unit.at("/feeAmount/sources/0/quote").asText());assertEquals("16",unit.at("/limitCount/value").asText());}
            assertEquals(2,after.path("units").size());assertFalse(turn.reply().contains("请确认整单总价"));assertFalse(turn.reply().contains("项目与费用里配置"));assertFalse(after.at("/nextQuestion/field").asText().contains("feeAmount"));
        }
    }
    @Test void conditionalAllProjectFeeDoesNotLoseItsConditions() {
        for(String message:java.util.List.of("全部项目每项100元，附加20元","全部项目100元，首项优惠","全部项目100元可以吗？","不是全部项目100元"))assertNull(DraftAnswerPatch.apply(mapper,draft("pair",2,2),message));
    }
    @Test void missingFieldRemainsStructuredWithoutAnAppendedNextStep() throws Exception {
        var root=draft("pair",2,2);value((ObjectNode)root.path("units").get(0),"feeAmount","50");value((ObjectNode)root.path("units").get(0),"feeBasis","unknown");
        var turn=DraftChoices.finish(mapper,root.toString(),"好的，报名上限已经写入草稿。","32单",now,false);
        assertFalse(turn.reply().contains("下一步："));assertEquals("units[0].feeAmount",mapper.readTree(turn.proposal()).at("/nextQuestion/field").asText());
    }
    @Test void variableTeamKeepsQuoteAndAsksTotalInsteadOfAskingAmountAgain() throws Exception {
        var turn=DraftChoices.tryApply(mapper,draft("team",3,5).toString(),"每人20元",now);
        var after=mapper.readTree(turn.proposal());assertEquals("20",after.at("/units/0/feeAmount/value").asText());assertEquals("per_person",after.at("/units/0/feeBasis/value").asText());
        assertTrue(turn.reply().contains("整单总价"));assertFalse(turn.reply().contains("每人多少钱"));assertEquals("units[0].feeAmount",after.at("/nextQuestion/field").asText());
    }
    @Test void followupTargetsOnlyTheCurrentlyAskedProject() throws Exception {
        var root=draft("individual",1,1);var second=((ObjectNode)root.path("units").get(0)).deepCopy();value(second,"name","第二组");root.withArray("units").add(second);
        root.putObject("nextQuestion").put("text","第二组每人费用是多少？").put("field","units[1].feeAmount");
        var turn=DraftChoices.tryApply(mapper,root.toString(),"每人30元",now);var after=mapper.readTree(turn.proposal());
        assertTrue(after.at("/units/0/feeAmount/value").asText("").isBlank());assertEquals("30",after.at("/units/1/feeAmount/value").asText());
    }
    @Test void ambiguousMultipleProjectsAreNotAllOverwritten() {
        var root=draft("individual",1,1);var second=((ObjectNode)root.path("units").get(0)).deepCopy();value(second,"name","第二组");root.withArray("units").add(second);
        assertNull(DraftAnswerPatch.apply(mapper,root,"每人30元"));
    }
    @Test void ageAnswerUpdatesRulesAndSuppressesRepeatedAgeQuestion() throws Exception {
        var root=draft("individual",1,1);root.putObject("nextQuestion").put("text","参赛年龄范围是多少？");
        var turn=DraftChoices.tryApply(mapper,root.toString(),"18-35岁",now);assertNotNull(turn);
        var after=mapper.readTree(turn.proposal());assertTrue(after.at("/event/rulesText/value").asText().contains("保留原资格和退改规定"));assertTrue(after.at("/event/rulesText/value").asText().contains("18-35岁"));
        var again=DraftChoices.finish(mapper,turn.proposal(),"请问参赛年龄范围是多少？","继续",now,false);
        assertFalse(again.reply().contains("年龄范围是多少"));assertEquals(1,mapper.readTree(again.proposal()).path("units").size());
    }
    @Test void newAgeRangeReplacesOnlyPreviousConfirmedAgeLine() throws Exception {
        var root=draft("individual",1,1);root.putObject("nextQuestion").put("text","年龄？");
        var turn=DraftChoices.tryApply(mapper,root.toString(),"18-35岁",now);
        var changed=DraftChoices.tryApply(mapper,turn.proposal(),"参赛年龄20-40岁",now);
        String rules=mapper.readTree(changed.proposal()).at("/event/rulesText/value").asText();assertTrue(rules.contains("20-40岁"));assertFalse(rules.contains("18-35岁"));
    }
    @Test void negativeOrQuestionPriceIsNotAConfirmation() {
        var root=draft("pair",2,2);assertNull(DraftAnswerPatch.apply(mapper,root,"每人50元可以吗？"));assertNull(DraftAnswerPatch.apply(mapper,root,"不是每人50元"));
    }
    @Test void combinedAnswerIsDelegatedWithoutDroppingItsOtherFields() {
        var root=draft("pair",2,2);
        assertNull(DraftAnswerPatch.apply(mapper,root,"年龄18-35岁，每人50元"));
        assertNull(DraftAnswerPatch.apply(mapper,root,"每人50元，名额改成32单"));
        assertNull(DraftAnswerPatch.apply(mapper,root,"每人50元，只保留双打"));
    }
    @Test void explicitWishToChangeAllowsANecessaryNewClarification() {
        var first=DraftChoices.tryApply(mapper,draft("pair",2,2).toString(),"每人50元",now);
        var fee=DraftChoices.finish(mapper,first.proposal(),"新的每单费用是多少？","费用想调整一下",now,false);
        assertTrue(fee.reply().contains("费用是多少"));
        var age=DraftChoices.tryApply(mapper,first.proposal(),"年龄18-35岁",now);
        var changed=DraftChoices.finish(mapper,age.proposal(),"年龄改成多少岁？","我想调整年龄",now,false);
        assertTrue(changed.reply().contains("改成多少岁"));
    }
    @Test void otherProjectSummaryUsesItsCurrentManuallyEditedAmount() throws Exception {
        var root=draft("individual",1,1);var second=((ObjectNode)root.path("units").get(0)).deepCopy();value(second,"name","第二组");root.withArray("units").add(second);
        var initial=DraftChoices.tryApply(mapper,root.toString(),"所有项目每人50元",now);
        var manual=(ObjectNode)mapper.readTree(initial.proposal());value((ObjectNode)manual.path("units").get(1),"feeAmount","80");
        var changed=DraftChoices.tryApply(mapper,manual.toString(),"公开组每人20元",now);
        String summary=mapper.readTree(changed.proposal()).at("/event/feeDescription/value").asText();
        assertTrue(summary.contains("第二组：每单80元"));assertFalse(summary.contains("第二组：每人50元"));
    }
    @Test void changedFeeReplacesOnlyGeneratedSummaryAndSuppressesRepeatedPriceQuestion() throws Exception {
        var root=draft("pair",2,2);value(root.withObject("event"),"feeDescription","保留原规程的退改条件");
        var first=DraftChoices.tryApply(mapper,root.toString(),"每人50元",now);
        var changed=DraftChoices.tryApply(mapper,first.proposal(),"每人30元",now);
        var after=mapper.readTree(changed.proposal());String description=after.at("/event/feeDescription/value").asText();
        assertTrue(description.contains("保留原规程的退改条件"));assertTrue(description.contains("每单60元"));assertFalse(description.contains("每人50元"));
        var again=DraftChoices.finish(mapper,changed.proposal(),"请问每人收费多少元？","继续",now,false);
        assertFalse(again.reply().contains("收费多少"));
    }
}
