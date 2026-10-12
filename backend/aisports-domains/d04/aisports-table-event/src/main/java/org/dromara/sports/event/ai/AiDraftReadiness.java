package org.dromara.sports.event.ai;

import org.dromara.sports.event.ai.SportsEventRunAiTaskService.ConfirmDraft;
import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;

/** 候选预检与最终保存共用；保存草稿不代表费用已配置或可以发布。 */
public final class AiDraftReadiness {
    private static final DateTimeFormatter DISPLAY = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    private AiDraftReadiness() { }
    public record Issue(String code, String field, String message) { }
    public record Ready(boolean canSaveDraft, List<Issue> blockingIssues, String nextStep, String checkedAt) { }
    public static Ready check(ConfirmDraft draft, OffsetDateTime now) {
        List<Issue> issues = new ArrayList<>();
        if (blank(draft.name())) issues.add(new Issue("NAME_REQUIRED", "name", "请补充赛事名称"));
        if (!List.of("manual", "none").contains(Objects.toString(draft.registrationReview(), "")))
            issues.add(new Issue("REVIEW_REQUIRED", "registrationReview", "请选择人工审核或无需人工审核；收费仍需足额实收"));
        if (draft.units() == null || draft.units().isEmpty()) issues.add(new Issue("UNIT_REQUIRED", "units", "请补充至少一个竞赛项目及其参赛形式、报名上限"));
        else for (int i = 0; i < draft.units().size(); i++) {
            var unit = draft.units().get(i);
            String label = blank(unit.name()) ? "第" + (i + 1) + "个项目" : "「" + unit.name() + "」";
            if (blank(unit.name())) issues.add(new Issue("UNIT_NAME_REQUIRED", "units[" + i + "].name", label + "还缺项目名称"));
            if (!List.of("individual", "pair", "team").contains(Objects.toString(unit.entryType(), "")))
                issues.add(new Issue("ENTRY_TYPE_REQUIRED", "units[" + i + "].entryType", label + "请选择单人、双人或团队参赛"));
            if (unit.limitCount() == null || unit.limitCount() < 1) {
                String meaning = "pair".equals(unit.entryType()) ? "1单对应2人" : "individual".equals(unit.entryType()) ? "1单对应1人" : "1单对应1支参赛队";
                issues.add(new Issue("CAPACITY_REQUIRED", "units[" + i + "].limitCount", label + "还缺报名上限，请填写至少1单（" + meaning + "），不是全赛事总人数。这个项目准备接受多少单报名？"));
            }
            // 与项目实际创建的人数约束保持一致，不能预检通过后才在事务里拒绝。
            if ("team".equals(unit.entryType()) && (unit.minMembers() == null || unit.maxMembers() == null
                || unit.minMembers() < 1 || unit.maxMembers() < unit.minMembers())) {
                issues.add(new Issue("TEAM_SIZE_REQUIRED", "units[" + i + "].minMembers", label + "请填写团体人数上下限，例如“团体3-5人”"));
            }
        }
        issues.addAll(AiFeeProposalPlan.issues(draft.units()));
        OffsetDateTime opens = time(draft.registrationOpensAt(), "registrationOpensAt", "报名开始", issues);
        OffsetDateTime closes = time(draft.registrationClosesAt(), "registrationClosesAt", "报名截止", issues);
        OffsetDateTime starts = time(draft.startsAt(), "startsAt", "开赛", issues);
        OffsetDateTime ends = time(draft.endsAt(), "endsAt", "结束", issues);
        if (ends != null && !ends.isAfter(now)) issues.add(new Issue("EVENT_ENDED", "endsAt", "赛事结束时间" + DISPLAY.format(ends) + "早于或等于当前时间" + DISPLAY.format(now) + "（上海时间），不能建立竞赛项目。请修改草稿的比赛时间，例如选择未来的周末，并核对报名时间。"));
        if (opens != null && closes != null && !opens.isBefore(closes) || closes != null && starts != null && closes.isAfter(starts) || starts != null && ends != null && !starts.isBefore(ends))
            issues.add(new Issue("TIME_ORDER", "times", "报名开始须早于截止，截止不晚于开赛，开赛须早于结束；请一起核对四个时间"));
        String next = issues.isEmpty() ? AiFeeProposalPlan.present(draft.units())
            ? "可以核对各项目每单价格并确认保存。保存后请完善收款渠道，再核对时间、公开联系人和发布条件；保存不等于发布。"
            : "可以确认保存赛事草稿。保存后请到项目与费用明确免费或收费，再核对时间、公开联系人和发布条件；保存不等于发布。"
            : "还不能保存赛事草稿。下一步：" + issues.get(0).message();
        return new Ready(issues.isEmpty(), List.copyOf(issues), next, now.toString());
    }
    private static OffsetDateTime time(String value, String field, String label, List<Issue> issues) {
        if (blank(value)) return null;
        try { return OffsetDateTime.parse(value).withOffsetSameInstant(ZoneOffset.ofHours(8)); }
        catch (java.time.format.DateTimeParseException ignored) {
            try { return LocalDateTime.parse(value.replace(' ', 'T')).atOffset(ZoneOffset.ofHours(8)); }
            catch (java.time.format.DateTimeParseException invalid) { issues.add(new Issue("TIME_INVALID", field, label + "时间格式不正确，请使用年月日和时分秒")); return null; }
        }
    }
    private static boolean blank(String value) { return value == null || value.isBlank(); }
}
