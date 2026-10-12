package org.dromara.sports.event.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.dromara.sports.event.ai.SportsEventRunAiTaskService.ConfirmDraft;
import org.dromara.sports.event.ai.SportsEventRunAiTaskService.UnitDraft;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 把还没定下来的事项做成可点的短回复，并直接写入草稿。
 * 已经确认的审核、名额、时间和明确整单价格不再交给模型重问。
 * 明确报价写入项目候选，生效价格仍须本人核对并确认创建。
 */
public final class DraftChoices {
    public static final String CONFIRM = "确认保存赛事草稿";
    private static final DateTimeFormatter CLOCK = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    private static final ZoneOffset SHANGHAI = ZoneOffset.ofHours(8);
    private static final Pattern QUOTA = Pattern.compile("^(?:项目是|每项|各项目|每个项目|都是|全部|名额)?\\s*(\\d{1,6})\\s*(?:人|单)?$");
    private static final Pattern FEE_AMOUNT = Pattern.compile("(?:每项|一项|全部|都是|一律)?\\s*(\\d{1,6})\\s*元");
    private static final Pattern TEAM_SIZE = Pattern.compile("^(?:团体(?:人数)?|团队(?:人数)?)?\\s*(\\d{1,6})\\s*[-—–~～至到]\\s*(\\d{1,6})\\s*人(?:吧)?[。！!]?$");
    private static final Pattern MOVE_EVENT = Pattern.compile("^把比赛改到(\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2})至(\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2})$");
    private static final Pattern MOVE_ENTRY = Pattern.compile("^把报名改到(\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2})至(\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2})$");
    private static final Pattern MOVE_CLOSE = Pattern.compile("^报名截止改成(\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2})$");
    private static final int LIMIT = 4;

    private DraftChoices() {
    }

    public record Turn(String proposal, String reply, List<String> suggestions) {
    }

    public static boolean askedToSave(String message) {
        if (message == null) {
            return false;
        }
        if (EventCreationConsent.allowed(message)) {
            return true;
        }
        String text = message.trim();
        if (text.contains("吗") || text.contains("？") || text.contains("?") || text.contains("不要") || text.contains("先别") || text.contains("需要什么")) {
            return false;
        }
        return text.matches(".*直接生成吧?[！!。]?") || text.matches(".*生成(赛事|这场|比赛|草稿)。*") || text.matches(".*请生成.*");
    }

    /** 点选或同义短句能对上当前选项时直接改草稿；对不上则返回 null。 */
    public static Turn tryApply(ObjectMapper mapper, String proposal, String message, OffsetDateTime now) {
        ObjectNode root = read(mapper, proposal);
        String explicit = DraftAnswerPatch.apply(mapper, root, message);
        if (explicit != null) {
            DraftMerge.Merged merged = DraftMerge.absorb(mapper, root.toString(), explicit, message, false);
            return finish(mapper, merged.proposal(), merged.reply(), message, now, false);
        }
        Gap gap = firstGap(root, now);
        String action = resolve(message, gap, choices(root, now));
        if (action == null) {
            return null;
        }
        String agent = agentFor(mapper, root, action, now);
        if (agent == null) {
            return null;
        }
        DraftMerge.Merged merged = DraftMerge.absorb(mapper, proposal, agent, message, false);
        return finish(mapper, merged.proposal(), merged.reply(), message, now, false);
    }

    /** 合并模型回答后：记下已确认话题，去掉重复追问，附上这一轮的选项。 */
    public static Turn finish(ObjectMapper mapper, String proposal, String reply, String userMessage, OffsetDateTime now, boolean askedToSave) {
        ObjectNode root = read(mapper, proposal);
        applyDefaults(root);
        seal(root, userMessage);
        Gap gap = firstGap(root, now);
        List<String> options = choices(root, now);
        String spoken = speak(reply == null ? "" : reply.trim(), root, gap, askedToSave, userMessage, now);
        // The current missing field is exposed beside the editable candidate.
        // Repeating the whole checklist after every acknowledgement crowds chat.
        ObjectNode next = root.putObject("nextQuestion");
        if (gap != null && gap.blocking) {
            next.put("text", gap.question);
            var ready = readiness(root, now);
            if (!ready.blockingIssues().isEmpty()) next.put("field", ready.blockingIssues().get(0).field());
        } else if (questioning(spoken)) next.put("text", spoken);
        writeDialogue(root, spoken);
        ArrayNode suggestions = root.putArray("suggestions");
        options.forEach(suggestions::add);
        return new Turn(root.toString(), spoken, List.copyOf(options));
    }

    public static void writeSuggestions(ObjectMapper mapper, ObjectNode root, OffsetDateTime now) {
        applyDefaults(root);
        ArrayNode suggestions = root.putArray("suggestions");
        choices(root, now).forEach(suggestions::add);
    }

    /** User-approved AI creation default, not a claim that the source explicitly selected it. */
    public static void applyDefaults(ObjectNode root) {
        ObjectNode event = root.withObject("event");
        JsonNode review = event.path("registrationReview");
        String value = review.path("value").asText("");
        if ("conflict".equals(review.path("status").asText())) return;
        if (List.of("manual", "none").contains(value) && "filled".equals(review.path("status").asText())) return;
        if ("manual".equals(value) && !review.path("sources").isEmpty()) return;
        ObjectNode fallback = event.putObject("registrationReview").put("value", "none").put("status", "filled");
        fallback.putArray("sources").addObject().put("kind", "default").put("label", "平台默认：未说明时无需人工审核").put("quote", "");
        fallback.putArray("alternatives");
    }

    private static List<String> choices(ObjectNode root, OffsetDateTime now) {
        Gap gap = firstGap(root, now);
        LinkedHashSet<String> options = new LinkedHashSet<>();
        if (gap != null) {
            options.addAll(gap.options);
        }
        AiDraftReadiness.Ready ready = readiness(root, now);
        if (ready.canSaveDraft() && options.size() < LIMIT) {
            options.add(CONFIRM);
        }
        return options.stream().limit(LIMIT).toList();
    }

    private static String speak(String reply, ObjectNode root, Gap gap, boolean askedToSave, String userMessage, OffsetDateTime now) {
        AiDraftReadiness.Ready ready = readiness(root, now);
        if (askedToSave && ready.canSaveDraft()) {
            return "草稿已整理，尚未保存。请点下面的「确认保存赛事草稿」。保存不等于发布。";
        }
        if (askedToSave && !ready.blockingIssues().isEmpty()) {
            String blocker = ready.blockingIssues().get(0).message();
            if (gap != null && gap.blocking && !gap.options.isEmpty()) {
                return blocker + gap.question;
            }
            return blocker;
        }
        String kept = stripSettled(reply, root, userMessage);
        if (gap != null && gap.blocking && chasing(kept) && !aligned(kept, gap)) {
            String ack = acknowledgement(kept);
            kept = ack.isBlank() ? gap.question : ack + gap.question;
        } else if (kept.isBlank() && gap != null && gap.blocking) {
            kept = gap.question;
        } else if (kept.isBlank()) {
            kept = "这些已经按您确认的记下了。";
        }
        return kept;
    }

    private static String stripSettled(String reply, ObjectNode root, String userMessage) {
        if (reply.isBlank()) {
            return "";
        }
        boolean userAskedRules = userMessage != null && userMessage.contains("规则");
        StringBuilder kept = new StringBuilder();
        for (String sentence : reply.split("(?<=[。！？\\n])")) {
            String text = sentence.trim();
            if (text.isEmpty()) {
                continue;
            }
            boolean changingAge = asksToChange(userMessage, "年龄", "岁");
            boolean changingFee = asksToChange(userMessage, "费", "价格", "报价", "总价", "每人", "每单");
            boolean requestedFollowup = changingAge && sentenceMentions(text, "年龄", "岁") || changingFee && sentenceMentions(text, "费", "价格", "报价", "总价", "每人", "每单");
            if (questioning(text) && !requestedFollowup && settledTopic(text, root, userAskedRules)) {
                continue;
            }
            if (!userAskedRules && text.contains("规则") && questioning(text)) {
                continue;
            }
            if (kept.length() > 0 && !kept.toString().endsWith("\n")) {
                kept.append("");
            }
            kept.append(sentence.trim());
        }
        return kept.toString().trim();
    }

    private static boolean asksToChange(String message, String... topics) {
        return message != null && sentenceMentions(message, topics)
            && sentenceMentions(message, "改", "调整", "重新", "便宜", "贵", "提高", "降低", "变更", "增", "减");
    }

    private static boolean settledTopic(String sentence, ObjectNode root, boolean userAskedRules) {
        if (root.path("answeredTopics").has("age") && sentenceMentions(sentence, "年龄", "多少岁", "几岁") && !userAskedRules) return true;
        if (sentenceMentions(sentence, "费用", "收费", "多少钱", "每人", "每项")) {
            var units = toDraft(root).units();
            if (AiFeeProposalPlan.present(units)) return AiFeeProposalPlan.issues(units).isEmpty();
        }
        if (!topicClosed(root, "fee") && sentenceMentions(sentence, "费用", "收费", "多少钱", "每项")) {
            return false;
        }
        if (topicClosed(root, "fee") && sentenceMentions(sentence, "费用", "收费", "多少钱", "待配置")) {
            return true;
        }
        if (reviewSettled(root.path("event")) && sentenceMentions(sentence, "报名审核", "人工审核", "无需人工", "要不要审核")) {
            return true;
        }
        if (entriesSettled(root.path("units")) && sentenceMentions(sentence, "参赛形式", "个人、双人", "单打还是", "双打还是")) {
            return true;
        }
        if (quotaSettled(root.path("units")) && sentenceMentions(sentence, "名额", "报名上限", "多少单", "多少人", "限报")) {
            return true;
        }
        if (topicClosed(root, "rules") && !userAskedRules && sentenceMentions(sentence, "竞赛规则", "规则说明")) {
            return true;
        }
        return false;
    }

    private static boolean sentenceMentions(String sentence, String... words) {
        for (String word : words) {
            if (sentence.contains(word)) {
                return true;
            }
        }
        return false;
    }

    private static boolean questioning(String sentence) {
        return sentence.contains("？") || sentence.contains("?") || sentence.contains("吗")
            || sentence.contains("您看") || sentence.contains("您说") || sentence.contains("您定")
            || sentence.contains("还是") || sentence.contains("说一下") || sentence.contains("定一下")
            || sentence.contains("还没") || sentence.contains("还差") || sentence.contains("待配置")
            || sentence.contains("对不上") || sentence.contains("请补") || sentence.contains("请选")
            || sentence.contains("请明确");
    }

    private static boolean chasing(String reply) {
        return sentenceMentions(reply, "费用", "审核", "时间", "名额", "参赛形式", "规则", "保存", "报名");
    }

    private static boolean aligned(String reply, Gap gap) {
        return switch (gap.kind) {
            case REVIEW -> sentenceMentions(reply, "审核");
            case ENTRY -> sentenceMentions(reply, "参赛形式", "个人", "双人", "团体", "单打", "双打");
            case QUOTA -> sentenceMentions(reply, "名额", "上限", "多少");
            case EVENT_ENDED, TIME_ORDER -> sentenceMentions(reply, "时间", "比赛", "报名");
            case OPEN_MISSING -> sentenceMentions(reply, "报名开始", "即日");
            case FEE -> sentenceMentions(reply, "费用", "收费");
            case UNCERTAIN -> reply.contains(gap.hint);
            default -> true;
        };
    }

    private static String acknowledgement(String reply) {
        for (String sentence : reply.split("(?<=[。！？])")) {
            String text = sentence.trim();
            if (text.startsWith("好") && !questioning(text)) {
                return text.endsWith("。") ? text : text + "。";
            }
        }
        return "";
    }

    private static String resolve(String message, Gap gap, List<String> options) {
        if (message == null) {
            return null;
        }
        String text = message.trim();
        if (text.isEmpty() || CONFIRM.equals(text)) {
            return null;
        }
        if (options.contains(text)) {
            return text;
        }
        String synonym = synonym(text);
        if ("人工审核".equals(synonym) || "无需人工审核".equals(synonym)) return synonym;
        if ("报名从今天开始".equals(synonym) || MOVE_CLOSE.matcher(text).matches()
            || MOVE_EVENT.matcher(text).matches() || MOVE_ENTRY.matcher(text).matches()) {
            return synonym == null ? text : synonym;
        }
        if (synonym != null && options.contains(synonym)) {
            return synonym;
        }
        // 只有唯一团体项目时才接收无项目名的短回复，避免多项目时猜测适用对象。
        Matcher members = TEAM_SIZE.matcher(text);
        if (members.matches()) {
            // 项目匹配在 agentFor 中完成；此处只识别明确的上下限，不交给模型复述。
            return "members:" + members.group(1) + ":" + members.group(2);
        }
        if (gap != null && gap.kind == Kind.QUOTA) {
            Matcher quota = QUOTA.matcher(text);
            if (quota.matches()) {
                return "quota:" + quota.group(1);
            }
        }
        if (gap != null && gap.kind == Kind.FEE) {
            if (text.equals("全部") || text.equals("都是") || text.equals("按规程") || text.equals("按原来的") || text.equals("费用按规程原文")) {
                return "fee:source";
            }
            Matcher fee = FEE_AMOUNT.matcher(text);
            if (text.length() <= 40 && fee.find() && text.replace(fee.group(), "").length() <= 8) {
                return "fee:" + fee.group(1);
            }
        }
        return null;
    }

    private static JsonNode singleTeam(JsonNode units) {
        JsonNode found = null;
        if (!units.isArray()) return null;
        for (JsonNode unit : units) {
            if ("team".equals(text(unit, "entryType"))) {
                if (found != null) return null;
                found = unit;
            }
        }
        return found;
    }

    private static String synonym(String text) {
        return switch (text) {
            case "不审核", "无需审核", "不用审核", "无需人工审核" -> "无需人工审核";
            case "要审核", "人工核对", "人工审核" -> "人工审核";
            case "都要", "三种都要", "全都要", "个人双人团体都要", "个人、双人、团体都要" -> "个人、双人、团体都要";
            case "单打" -> "个人";
            case "双打" -> "双人";
            case "团体赛" -> "团体";
            case "从今天开始", "即日起", "报名从今天开始" -> "报名从今天开始";
            case "先空着", "先不填", "可以空着" -> "规程说明先空着";
            default -> null;
        };
    }

    private static String agentFor(ObjectMapper mapper, ObjectNode root, String action, OffsetDateTime now) {
        ObjectNode agent = mapper.createObjectNode();
        agent.put("action", "update");
        ObjectNode event = agent.putObject("event");
        String reply;
        switch (action) {
            case "无需人工审核" -> {
                putField(mapper, event, "registrationReview", "none");
                reply = "好的，报名审核按无需人工审核记下了。收费报名仍要实际足额收款后才可通过。";
            }
            case "人工审核" -> {
                putField(mapper, event, "registrationReview", "manual");
                reply = "好的，报名审核按人工审核记下了。收费报名仍要实际足额收款后才可通过。";
            }
            case "个人", "双人", "团体" -> {
                fillEntry(mapper, agent, root, action);
                reply = "好的，参赛形式按" + action + "记下了。";
            }
            case "个人、双人、团体都要" -> {
                fillAllEntries(mapper, agent, root);
                reply = "好的，参赛形式按个人、双人、团体都记下了。";
            }
            case "报名从今天开始" -> {
                putField(mapper, event, "registrationOpensAt", CLOCK.format(now.toLocalDate().atStartOfDay()));
                reply = "好的，报名开始时间按今天记下了。";
            }
            case "规程说明先空着" -> {
                reply = "好的，竞赛规则说明先空着。";
                agent = noteOnly(mapper, reply);
            }
            case "费用按规程原文", "fee:source" -> {
                reply = "好的，费用先按规程原文记下。这不会自动变成生效价格，保存后请到项目与费用里配置。";
                agent = noteOnly(mapper, reply);
            }
            default -> {
                if (action.startsWith("members:")) {
                    JsonNode team = singleTeam(root.path("units"));
                    String[] range = action.split(":");
                    int min = Integer.parseInt(range[1]), max = Integer.parseInt(range[2]);
                    if (team == null || min < 1 || max < min) return null;
                    ObjectNode unit = team.deepCopy();
                    putField(mapper, unit, "minMembers", Integer.toString(min));
                    putField(mapper, unit, "maxMembers", Integer.toString(max));
                    agent.putArray("units").add(unit);
                    reply = "好的，团体人数按" + min + "-" + max + "人记下了。";
                } else if (action.startsWith("quota:") || action.matches("\\d{1,6}单")) {
                    String number = action.startsWith("quota:") ? action.substring("quota:".length()) : action.substring(0, action.length() - 1);
                    fillQuota(mapper, agent, root, Integer.parseInt(number));
                    reply = "好的，报名上限按" + number + "单记下了。";
                } else if (action.startsWith("fee:") || action.matches("每项\\d{1,6}元")) {
                    String amount = action.startsWith("fee:") ? action.substring("fee:".length()) : action.substring("每项".length(), action.length() - 1);
                    reply = "好的，费用按每项" + amount + "元记下了。这不是生效价格，保存后请到项目与费用里配置。";
                    agent = noteOnly(mapper, reply);
                } else if (MOVE_EVENT.matcher(action).matches()) {
                    Matcher matcher = MOVE_EVENT.matcher(action);
                    matcher.matches();
                    reply = applyEventMove(mapper, event, root, matcher.group(1), matcher.group(2));
                } else if (MOVE_ENTRY.matcher(action).matches()) {
                    Matcher matcher = MOVE_ENTRY.matcher(action);
                    matcher.matches();
                    putField(mapper, event, "registrationOpensAt", matcher.group(1));
                    putField(mapper, event, "registrationClosesAt", matcher.group(2));
                    reply = "好的，报名时间按这个改好了。";
                } else if (MOVE_CLOSE.matcher(action).matches()) {
                    Matcher matcher = MOVE_CLOSE.matcher(action);
                    matcher.matches();
                    putField(mapper, event, "registrationClosesAt", matcher.group(1));
                    reply = "好的，报名截止时间改好了。";
                } else if (action.startsWith("开赛就用")) {
                    putField(mapper, event, "startsAt", action.substring("开赛就用".length()));
                    reply = "好的，开赛时间按这个记下了。";
                } else if (action.startsWith("结束就用")) {
                    putField(mapper, event, "endsAt", action.substring("结束就用".length()));
                    reply = "好的，结束时间按这个记下了。";
                } else if (action.startsWith("报名开始就用")) {
                    putField(mapper, event, "registrationOpensAt", action.substring("报名开始就用".length()));
                    reply = "好的，报名开始时间按这个记下了。";
                } else if (action.startsWith("报名截止就用")) {
                    putField(mapper, event, "registrationClosesAt", action.substring("报名截止就用".length()));
                    reply = "好的，报名截止时间按这个记下了。";
                } else {
                    String accepted = acceptReading(mapper, event, root, action);
                    if (accepted == null) {
                        return null;
                    }
                    reply = accepted;
                }
            }
        }
        if (agent != null && !agent.has("reply")) {
            agent.put("reply", reply);
        }
        return agent == null ? null : agent.toString();
    }

    private static ObjectNode noteOnly(ObjectMapper mapper, String reply) {
        ObjectNode agent = mapper.createObjectNode();
        agent.put("action", "update");
        agent.put("reply", reply);
        agent.putObject("event");
        return agent;
    }

    private static void fillEntry(ObjectMapper mapper, ObjectNode agent, ObjectNode root, String label) {
        String code = "个人".equals(label) ? "individual" : "双人".equals(label) ? "pair" : "team";
        ArrayNode units = agent.putArray("units");
        JsonNode existing = root.path("units");
        if (!existing.isArray() || existing.isEmpty()) {
            units.add(unitNode(mapper, project(root) + label, code, null));
            return;
        }
        boolean any = false;
        for (JsonNode unit : existing) {
            ObjectNode copy = (ObjectNode) unit.deepCopy();
            String named = namedEntry(copy);
            if (!validEntry(copy.path("entryType")) && (named.isBlank() || named.equals(code))) {
                putField(mapper, copy, "entryType", code);
                any = true;
            }
            if (code.equals(text(copy, "entryType"))) any = true;
            units.add(copy);
        }
        if (!any) {
            units.removeAll();
            units.add(unitNode(mapper, project(root) + label, code, null));
        }
    }

    private static void fillAllEntries(ObjectMapper mapper, ObjectNode agent, ObjectNode root) {
        ArrayNode units = agent.putArray("units");
        Set<String> present = new LinkedHashSet<>();
        JsonNode existing = root.path("units");
        Integer sharedLimit = null;
        if (existing.isArray()) {
            for (JsonNode unit : existing) {
                // 确认参赛形式不能删除U年龄组/性别等详细项目，suggestion也必须保留。
                ObjectNode copy = unit.deepCopy();
                String type = validEntry(copy.path("entryType")) ? text(copy, "entryType") : namedEntry(copy);
                if (!type.isBlank()) {
                    putField(mapper, copy, "entryType", type);
                    present.add(type);
                }
                units.add(copy);
                if (sharedLimit == null) sharedLimit = integer(unit.path("limitCount"));
            }
        }
        String base = project(root);
        if (!present.contains("individual")) {
            units.add(unitNode(mapper, base + "个人", "individual", sharedLimit));
        }
        if (!present.contains("pair")) {
            units.add(unitNode(mapper, base + "双人", "pair", sharedLimit));
        }
        if (!present.contains("team")) {
            units.add(unitNode(mapper, base + "团体", "team", sharedLimit));
        }
    }

    private static String namedEntry(JsonNode unit) {
        String name = text(unit, "name");
        if (name.contains("双打") || name.endsWith("男双") || name.endsWith("女双") || name.endsWith("混双")) return "pair";
        if (name.contains("单打") || name.endsWith("男单") || name.endsWith("女单")) return "individual";
        if (name.contains("团体")) return "team";
        return "";
    }

    private static void fillQuota(ObjectMapper mapper, ObjectNode agent, ObjectNode root, int limit) {
        ArrayNode units = agent.putArray("units");
        JsonNode existing = root.path("units");
        if (!existing.isArray() || existing.isEmpty()) {
            units.add(unitNode(mapper, project(root), "individual", limit));
            return;
        }
        for (JsonNode unit : existing) {
            ObjectNode copy = (ObjectNode) unit.deepCopy();
            if (!quotaFilled(copy.path("limitCount"))) {
                putField(mapper, copy, "limitCount", Integer.toString(limit));
            }
            units.add(copy);
        }
    }

    private static String applyEventMove(ObjectMapper mapper, ObjectNode event, ObjectNode current, String start, String end) {
        putField(mapper, event, "startsAt", start);
        putField(mapper, event, "endsAt", end);
        JsonNode currentEvent = current.path("event");
        OffsetDateTime newStart = parse(start);
        String open = text(currentEvent, "registrationOpensAt");
        String close = text(currentEvent, "registrationClosesAt");
        OffsetDateTime openAt = parse(open);
        OffsetDateTime closeAt = parse(close);
        boolean registrationMoved = false;
        if (newStart != null && (closeAt == null || !closeAt.isBefore(newStart) || (openAt != null && !openAt.isBefore(closeAt)))) {
            OffsetDateTime newClose = newStart.toLocalDate().minusDays(1).atStartOfDay().atOffset(SHANGHAI);
            OffsetDateTime newOpen = openAt != null && openAt.isBefore(newClose) ? openAt : newClose.minusDays(7);
            putField(mapper, event, "registrationOpensAt", CLOCK.format(newOpen.toLocalDateTime()));
            putField(mapper, event, "registrationClosesAt", CLOCK.format(newClose.toLocalDateTime()));
            registrationMoved = true;
        }
        return registrationMoved
            ? "好的，比赛改到这个时间了。报名也调到开赛之前，避免又对不上。"
            : "好的，比赛时间按这个改好了。";
    }

    private static String acceptReading(ObjectMapper mapper, ObjectNode event, ObjectNode root, String action) {
        for (String field : DraftMerge.EVENT_FIELDS) {
            String prefix = prefix(field);
            if (prefix != null && action.startsWith(prefix)) {
                String value = action.substring(prefix.length());
                if (value.isBlank() || !readings(root.path("event").path(field)).contains(value)) {
                    return null;
                }
                putField(mapper, event, field, value);
                return "好的，" + prefix.replace("就用", "") + "按这个记下了。";
            }
        }
        return null;
    }

    private static ObjectNode unitNode(ObjectMapper mapper, String name, String entryType, Integer limit) {
        ObjectNode unit = mapper.createObjectNode();
        putField(mapper, unit, "name", name);
        putField(mapper, unit, "entryType", entryType);
        if (limit != null && limit > 0) {
            putField(mapper, unit, "limitCount", Integer.toString(limit));
        }
        return unit;
    }

    private static void putField(ObjectMapper mapper, ObjectNode parent, String name, String value) {
        ObjectNode field = mapper.createObjectNode();
        field.put("value", value);
        field.put("status", "filled");
        field.putArray("sources");
        field.putArray("alternatives");
        parent.set(name, field);
    }

    private enum Kind {
        NAME, REVIEW, ENTRY, QUOTA, TEAM_SIZE, EVENT_ENDED, TIME_ORDER, TIME_INVALID, OPEN_MISSING, FEE, UNCERTAIN
    }

    private record Gap(Kind kind, boolean blocking, String question, String hint, List<String> options) {
    }

    private static Gap firstGap(ObjectNode root, OffsetDateTime now) {
        AiDraftReadiness.Ready ready = readiness(root, now);
        if (!ready.blockingIssues().isEmpty()) {
            Gap blocking = blockingGap(ready.blockingIssues().get(0), root, now);
            if (blocking != null) {
                return blocking;
            }
        }
        return softGap(root, now);
    }

    private static Gap blockingGap(AiDraftReadiness.Issue issue, ObjectNode root, OffsetDateTime now) {
        return switch (issue.code()) {
            case "REVIEW_REQUIRED" -> new Gap(Kind.REVIEW, true, "报名审核用哪一种？", "审核", List.of("人工审核", "无需人工审核"));
            case "UNIT_REQUIRED", "ENTRY_TYPE_REQUIRED" -> new Gap(Kind.ENTRY, true, "参赛形式按个人、双人还是团体？", "参赛", List.of("个人", "双人", "团体", "个人、双人、团体都要"));
            case "CAPACITY_REQUIRED" -> new Gap(Kind.QUOTA, true, issue.message(), "名额", quotaOptions(root));
            case "TEAM_SIZE_REQUIRED" -> new Gap(Kind.TEAM_SIZE, true, issue.message(), "团体人数", List.of());
            case "FEE_CONFLICT", "FEE_BASIS_REQUIRED", "FEE_AMOUNT_REQUIRED" -> new Gap(Kind.FEE, true, issue.message(), "费用", List.of());
            case "EVENT_ENDED", "TIME_ORDER" -> timeGap(issue.code(), issue.message(), root, now);
            case "NAME_REQUIRED" -> new Gap(Kind.NAME, true, issue.message(), "名称", readingOptions(root.path("event").path("name"), "赛事名称就用"));
            default -> new Gap(Kind.TIME_INVALID, true, issue.message(), "时间", List.of());
        };
    }

    private static Gap timeGap(String code, String message, ObjectNode root, OffsetDateTime now) {
        List<String> options = new ArrayList<>();
        Times times = times(root);
        if ("EVENT_ENDED".equals(code) || (times.end != null && !times.end.isAfter(now))) {
            addMove(options, moveEvent(times, now, times.close != null && times.close.isAfter(now) ? times.close : now));
        }
        if ("TIME_ORDER".equals(code)) {
            addRegistrationRepairs(options, times, now);
            if (options.isEmpty()) {
                addMove(options, moveEvent(times, now, later(now, times.close)));
            }
        }
        Kind kind = "EVENT_ENDED".equals(code) ? Kind.EVENT_ENDED : Kind.TIME_ORDER;
        String question = "EVENT_ENDED".equals(code) ? "比赛时间已经过去。可以改到后面的这个时间：" : "时间对不上。请选一种改法：";
        return new Gap(kind, true, options.isEmpty() ? message : question, "时间", List.copyOf(options));
    }

    private static void addRegistrationRepairs(List<String> options, Times times, OffsetDateTime now) {
        if (times.open != null && times.close != null && !times.open.isBefore(times.close)) {
            OffsetDateTime close = times.open.plusDays(3).toLocalDate().atStartOfDay().atOffset(SHANGHAI);
            if (times.start != null && !close.isBefore(times.start)) {
                close = times.start.toLocalDate().minusDays(1).atStartOfDay().atOffset(SHANGHAI);
            }
            if (times.open.isBefore(close) && (times.start == null || close.isBefore(times.start) || !close.isAfter(times.start.minusSeconds(1)))) {
                if (times.start == null || close.isBefore(times.start)) {
                    options.add("报名截止改成" + CLOCK.format(close.toLocalDateTime()));
                }
            }
        }
        if (times.start != null && times.end != null && times.start.isAfter(now) && times.start.isBefore(times.end)) {
            OffsetDateTime close = times.start.toLocalDate().minusDays(1).atStartOfDay().atOffset(SHANGHAI);
            OffsetDateTime open = times.open != null && times.open.isBefore(close) ? times.open : close.minusDays(7);
            if (!open.isBefore(close)) {
                open = now.toLocalDate().atStartOfDay().atOffset(SHANGHAI);
            }
            if (open.isBefore(close) && close.isBefore(times.start) && !times.end.isBefore(now)) {
                options.add("把报名改到" + CLOCK.format(open.toLocalDateTime()) + "至" + CLOCK.format(close.toLocalDateTime()));
            }
        }
    }

    private static String moveEvent(Times times, OffsetDateTime now, OffsetDateTime anchor) {
        LocalDate saturday = later(now, anchor).toLocalDate().with(TemporalAdjusters.next(DayOfWeek.SATURDAY));
        OffsetDateTime start = saturday.atTime(9, 0).atOffset(SHANGHAI);
        OffsetDateTime end = saturday.plusDays(1).atTime(18, 0).atOffset(SHANGHAI);
        if (!start.isAfter(now) || !end.isAfter(now)) {
            return null;
        }
        return "把比赛改到" + CLOCK.format(start.toLocalDateTime()) + "至" + CLOCK.format(end.toLocalDateTime());
    }

    private static void addMove(List<String> options, String label) {
        if (label != null && !options.contains(label)) {
            options.add(label);
        }
    }

    private static OffsetDateTime later(OffsetDateTime left, OffsetDateTime right) {
        if (right == null || left.isAfter(right)) {
            return left;
        }
        return right;
    }

    private static Gap softGap(ObjectNode root, OffsetDateTime now) {
        JsonNode event = root.path("event");
        if (!reviewSettled(event) && ("suggestion".equals(status(event.path("registrationReview"))) || "conflict".equals(status(event.path("registrationReview"))) || text(event, "registrationReview").isBlank())) {
            if (text(event, "registrationReview").isBlank() || !"filled".equals(status(event.path("registrationReview")))) {
                if (List.of("manual", "none").contains(text(event, "registrationReview")) || text(event, "registrationReview").isBlank()) {
                    return new Gap(Kind.REVIEW, false, "报名审核用哪一种？", "审核", List.of("人工审核", "无需人工审核"));
                }
            }
        }
        if (!entriesSettled(root.path("units")) && root.path("units").isArray() && !root.path("units").isEmpty()) {
            return new Gap(Kind.ENTRY, false, "参赛形式按个人、双人还是团体？", "参赛", List.of("个人", "双人", "团体", "个人、双人、团体都要"));
        }
        List<String> quota = quotaOptions(root);
        if (!quota.isEmpty() && !quotaSettled(root.path("units"))) {
            return new Gap(Kind.QUOTA, false, "报名上限按哪一个？", "名额", quota);
        }
        Gap reading = uncertainReading(event);
        if (reading != null) {
            return reading;
        }
        if (text(event, "registrationOpensAt").isBlank()) {
            return new Gap(Kind.OPEN_MISSING, false, "报名从哪天开始？", "报名开始", List.of("报名从今天开始"));
        }
        if (!topicClosed(root, "fee") && !AiFeeProposalPlan.present(toDraft(root).units()) && !text(event, "feeDescription").isBlank()) {
            List<String> fees = feeOptions(text(event, "feeDescription"));
            if (!fees.isEmpty()) {
                return new Gap(Kind.FEE, false, "收费说明已经读到了。生效价格不会自动写上，您可以先定一个费用意向：", "费用", fees);
            }
        }
        return null;
    }

    private static Gap uncertainReading(JsonNode event) {
        String[] fields = {"location", "name", "projectName", "startsAt", "endsAt", "registrationOpensAt", "registrationClosesAt"};
        for (String field : fields) {
            JsonNode node = event.path(field);
            String status = status(node);
            if (!"suggestion".equals(status) && !"conflict".equals(status)) {
                continue;
            }
            String prefix = prefix(field);
            List<String> options = readingOptions(node, prefix);
            if (!options.isEmpty()) {
                return new Gap(Kind.UNCERTAIN, false, prefix.replace("就用", "") + "有不止一种读法，请选一个。", prefix, options);
            }
        }
        return null;
    }

    private static List<String> readingOptions(JsonNode field, String prefix) {
        if (prefix == null) {
            return List.of();
        }
        List<String> options = new ArrayList<>();
        for (String reading : readings(field)) {
            if (reading.length() <= 60) {
                options.add(prefix + reading);
            }
            if (options.size() == 3) {
                break;
            }
        }
        return options;
    }

    private static List<String> readings(JsonNode field) {
        LinkedHashSet<String> values = new LinkedHashSet<>();
        String value = field.path("value").asText("").trim();
        if (!value.isBlank()) {
            values.add(value);
        }
        if (field.path("alternatives").isArray()) {
            for (JsonNode alternative : field.path("alternatives")) {
                String text = alternative.isObject() ? alternative.path("value").asText("").trim() : alternative.asText("").trim();
                if (!text.isBlank()) {
                    values.add(text);
                }
            }
        }
        return List.copyOf(values);
    }

    private static List<String> quotaOptions(ObjectNode root) {
        LinkedHashSet<String> options = new LinkedHashSet<>();
        if (root.path("units").isArray()) {
            for (JsonNode unit : root.path("units")) {
                for (String reading : readings(unit.path("limitCount"))) {
                    if (reading.matches("\\d{1,6}")) {
                        options.add(reading + "单");
                    }
                }
            }
        }
        return List.copyOf(options);
    }

    private static List<String> feeOptions(String description) {
        LinkedHashSet<String> amounts = new LinkedHashSet<>();
        Matcher matcher = FEE_AMOUNT.matcher(description);
        while (matcher.find()) {
            amounts.add(matcher.group(1));
        }
        List<String> options = new ArrayList<>();
        options.add("费用按规程原文");
        for (String amount : amounts) {
            if (options.size() == 3) {
                break;
            }
            options.add("每项" + amount + "元");
        }
        return options;
    }

    private static void seal(ObjectNode root, String userMessage) {
        String previous = previousAssistant(root);
        if (isFeeAnswer(userMessage, previous)) {
            closeTopic(root, "fee");
            Matcher fee = FEE_AMOUNT.matcher(userMessage == null ? "" : userMessage);
            if (userMessage != null && userMessage.length() <= 40 && fee.find()) {
                rememberFee(root, "每项" + fee.group(1) + "元", "all");
            } else if (userMessage != null && (userMessage.equals("全部") || userMessage.equals("都是"))) {
                String existing = root.path("feeIntent").path("text").asText("");
                rememberFee(root, existing.isBlank() ? "按规程原文" : existing, "all");
            } else if (userMessage != null && (userMessage.contains("原文") || userMessage.contains("原来") || userMessage.contains("规程"))) {
                rememberFee(root, "按规程原文", "source");
            }
        }
        if (isRulesAnswer(userMessage, previous)) {
            closeTopic(root, "rules");
        }
    }

    private static boolean isFeeAnswer(String message, String previous) {
        if (message == null) {
            return false;
        }
        String text = message.trim();
        if (text.length() > 40) {
            return false;
        }
        if (FEE_AMOUNT.matcher(text).find() || text.equals("费用按规程原文")) {
            return true;
        }
        return sentenceMentions(previous, "费用", "收费") && (text.equals("全部") || text.equals("都是") || text.equals("不改了") || text.equals("不改") || text.equals("按原来的") || text.equals("按规程"));
    }

    private static boolean isRulesAnswer(String message, String previous) {
        if (message == null) {
            return false;
        }
        String text = message.trim();
        if (text.equals("规程说明先空着")) {
            return true;
        }
        if (!(text.equals("先空着") || text.equals("先不填") || text.equals("可以空着") || text.contains("规则先空"))) {
            return false;
        }
        return previous.isBlank() || sentenceMentions(previous, "规则", "规程");
    }

    private static void rememberFee(ObjectNode root, String text, String scope) {
        closeTopic(root, "fee");
        ObjectNode intent = root.putObject("feeIntent");
        intent.put("text", text);
        intent.put("scope", scope);
        intent.put("effective", false);
    }

    private static void closeTopic(ObjectNode root, String topic) {
        ArrayNode topics = root.withArray("closedTopics");
        for (JsonNode item : topics) {
            if (topic.equals(item.asText())) {
                return;
            }
        }
        topics.add(topic);
    }

    private static boolean topicClosed(ObjectNode root, String topic) {
        for (JsonNode item : root.path("closedTopics")) {
            if (topic.equals(item.asText())) {
                return true;
            }
        }
        return false;
    }

    private static String previousAssistant(ObjectNode root) {
        JsonNode dialogue = root.path("dialogue");
        if (!dialogue.isArray()) {
            return "";
        }
        boolean skippedCurrent = false;
        boolean skippedUser = false;
        for (int i = dialogue.size() - 1; i >= 0; i--) {
            String role = dialogue.get(i).path("role").asText();
            if (!skippedCurrent && "ai".equals(role)) {
                skippedCurrent = true;
                continue;
            }
            if (!skippedUser && "user".equals(role)) {
                skippedUser = true;
                continue;
            }
            if ("ai".equals(role)) {
                return dialogue.get(i).path("text").asText("");
            }
        }
        return "";
    }

    private static void writeDialogue(ObjectNode root, String reply) {
        JsonNode dialogue = root.path("dialogue");
        if (dialogue.isArray() && !dialogue.isEmpty()) {
            JsonNode last = dialogue.get(dialogue.size() - 1);
            if ("ai".equals(last.path("role").asText()) && last instanceof ObjectNode ai) {
                ai.put("text", reply);
            }
        }
    }

    private static boolean reviewSettled(JsonNode event) {
        String value = text(event, "registrationReview");
        return ("manual".equals(value) || "none".equals(value)) && "filled".equals(status(event.path("registrationReview")));
    }

    private static boolean entriesSettled(JsonNode units) {
        if (!units.isArray() || units.isEmpty()) {
            return false;
        }
        for (JsonNode unit : units) {
            if (!validEntry(unit.path("entryType")) || !"filled".equals(unit.path("entryType").path("status").asText(""))) {
                return false;
            }
        }
        return true;
    }

    private static boolean quotaSettled(JsonNode units) {
        if (!units.isArray() || units.isEmpty()) {
            return false;
        }
        for (JsonNode unit : units) {
            if (!quotaFilled(unit.path("limitCount")) || !"filled".equals(status(unit.path("limitCount")))) {
                return false;
            }
        }
        return true;
    }

    private static boolean validEntry(JsonNode field) {
        String value = field.isObject() ? field.path("value").asText("") : field.asText("");
        return "individual".equals(value) || "pair".equals(value) || "team".equals(value);
    }

    private static boolean quotaFilled(JsonNode field) {
        Integer value = integer(field);
        return value != null && value > 0;
    }

    private static Integer integer(JsonNode field) {
        String text = field.isObject() ? field.path("value").asText("") : field.asText("");
        if (text.isBlank()) {
            return null;
        }
        try {
            return Integer.valueOf(text);
        } catch (NumberFormatException exception) {
            return null;
        }
    }

    private static String prefix(String field) {
        return switch (field) {
            case "name" -> "赛事名称就用";
            case "location" -> "地点就用";
            case "projectName" -> "运动项目就用";
            case "startsAt" -> "开赛就用";
            case "endsAt" -> "结束就用";
            case "registrationOpensAt" -> "报名开始就用";
            case "registrationClosesAt" -> "报名截止就用";
            default -> null;
        };
    }

    private static String project(ObjectNode root) {
        String name = text(root.path("event"), "projectName");
        return name.isBlank() ? "" : name;
    }

    private static String text(JsonNode event, String field) {
        return event.path(field).path("value").asText("").trim();
    }

    private static String status(JsonNode field) {
        return field.path("status").asText("");
    }

    private record Times(OffsetDateTime open, OffsetDateTime close, OffsetDateTime start, OffsetDateTime end) {
    }

    private static Times times(ObjectNode root) {
        JsonNode event = root.path("event");
        return new Times(parse(text(event, "registrationOpensAt")), parse(text(event, "registrationClosesAt")),
            parse(text(event, "startsAt")), parse(text(event, "endsAt")));
    }

    private static OffsetDateTime parse(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        try {
            return OffsetDateTime.parse(value).withOffsetSameInstant(SHANGHAI);
        } catch (java.time.format.DateTimeParseException ignored) {
            try {
                return LocalDateTime.parse(value.replace(' ', 'T')).atOffset(SHANGHAI);
            } catch (java.time.format.DateTimeParseException invalid) {
                return null;
            }
        }
    }

    private static AiDraftReadiness.Ready readiness(ObjectNode root, OffsetDateTime now) {
        return AiDeclarationProposal.readiness(root.path("event").path("declarationText"),AiDraftReadiness.check(toDraft(root), now));
    }

    private static ConfirmDraft toDraft(ObjectNode root) {
        JsonNode event = root.path("event");
        List<UnitDraft> units = new ArrayList<>();
        if (root.path("units").isArray()) {
            for (JsonNode unit : root.path("units")) {
                units.add(new UnitDraft(unit.path("name").path("value").asText(""), unit.path("entryType").path("value").asText(""),
                    integer(unit.path("minMembers")), integer(unit.path("maxMembers")), integer(unit.path("limitCount")),
                    text(unit,"feeAmount"),text(unit,"feeBasis"),
                    "conflict".equals(unit.path("feeAmount").path("status").asText()) || "conflict".equals(unit.path("feeBasis").path("status").asText())
                        ? "conflict" : unit.path("feeAmount").path("status").asText("missing")));
            }
        }
        return new ConfirmDraft("choice", text(event, "name"), text(event, "location"), text(event, "projectName"), text(event, "feeDescription"),
            text(event, "registrationOpensAt"), text(event, "registrationClosesAt"), text(event, "startsAt"), text(event, "endsAt"),
            text(event, "registrationReview"), text(event, "rulesText"), units);
    }

    private static ObjectNode read(ObjectMapper mapper, String raw) {
        try {
            JsonNode node = mapper.readTree(raw == null || raw.isBlank() ? "{}" : raw);
            if (node instanceof ObjectNode object) {
                return object;
            }
        } catch (Exception ignored) {
            // 坏草稿按空草稿继续，选项层不中断这场对话。
        }
        return mapper.createObjectNode();
    }
}
