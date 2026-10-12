package org.dromara.sports.event.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.dromara.sports.event.ai.LocalDocumentExtractor.Block;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 无模型时按原文标签填候选。缺的留空，两处不同写冲突，从名称推断的玩法标成建议。
 * 文档正文只当数据，不改变字段规则。
 */
public final class EventProposalHeuristic {

    private static final Pattern DATE = Pattern.compile(
        "(\\d{4})\\s*[年./-]\\s*(\\d{1,2})\\s*[月./-]\\s*(\\d{1,2})\\s*日?(?:\\s*(\\d{1,2})\\s*[:：时]\\s*(\\d{1,2}))?");
    private static final Pattern QUOTA = Pattern.compile("(?:名额|限额|人数上限)\\s*[:：]?\\s*(\\d{1,4})");
    private static final Pattern TEAM_SIZE = Pattern.compile("(\\d{1,2})\\s*[-~至到]\\s*(\\d{1,2})\\s*人");
    private static final String[] EVENT_FIELDS = {
        "name", "location", "projectName", "feeDescription",
        "registrationOpensAt", "registrationClosesAt", "startsAt", "endsAt",
        "registrationReview", "rulesText"
    };

    private EventProposalHeuristic() {
    }

    public static ObjectNode draft(ObjectMapper mapper, List<Block> blocks) {
        Map<String, Field> fields = new LinkedHashMap<>();
        for (String name : EVENT_FIELDS) {
            fields.put(name, new Field());
        }
        StringBuilder rules = new StringBuilder();
        List<UnitSeed> units = new ArrayList<>();
        for (Block block : blocks) {
            if (block.text() == null || block.text().isBlank()) {
                continue;
            }
            if (rules.length() < 4000) {
                if (rules.length() > 0) {
                    rules.append('\n');
                }
                rules.append(block.text());
            }
            for (String line : block.text().split("\\R")) {
                applyLine(fields, units, block, line.trim());
            }
        }
        if (rules.length() > 0) {
            fields.get("rulesText").offer(rules.substring(0, Math.min(rules.length(), 4000)), source(blocks.get(0)), false);
        }
        ObjectNode root = mapper.createObjectNode();
        root.put("version", 1);
        ObjectNode event = root.putObject("event");
        for (String name : EVENT_FIELDS) {
            event.set(name, fields.get(name).toJson(mapper));
        }
        ArrayNode unitNodes = root.putArray("units");
        for (UnitSeed seed : units) {
            unitNodes.add(seed.toJson(mapper));
        }
        ArrayNode warnings = root.putArray("warnings");
        warnings.add("竞赛项目会按免费创建。资料里的收费只写入公开收费说明。");
        return root;
    }

    private static void applyLine(Map<String, Field> fields, List<UnitSeed> units, Block block, String line) {
        if (line.isEmpty()) {
            return;
        }
        String name = after(line, "赛事名称", "比赛名称", "活动名称", "大会名称");
        if (name != null) {
            fields.get("name").offer(name, source(block), false);
        }
        String location = after(line, "比赛地点", "举办地点", "地点", "场馆");
        if (location != null) {
            fields.get("location").offer(location, source(block), false);
        }
        String project = after(line, "运动项目说明", "运动项目", "项目说明");
        if (project != null) {
            fields.get("projectName").offer(project, source(block), false);
        }
        String fee = after(line, "收费说明", "收费方式", "收费标准", "报名费", "费用");
        if (fee != null) {
            fields.get("feeDescription").offer(fee, source(block), false);
        }
        if (line.contains("无需审核")) {
            fields.get("registrationReview").offer("none", source(block), false);
        } else if (line.contains("人工审核")) {
            fields.get("registrationReview").offer("manual", source(block), false);
        }
        if (line.contains("报名")) {
            fillRange(fields.get("registrationOpensAt"), fields.get("registrationClosesAt"), line, source(block));
        }
        if (line.contains("比赛") || line.contains("开赛")) {
            fillRange(fields.get("startsAt"), fields.get("endsAt"), line, source(block));
        }
        if (line.contains("单打") || line.contains("双打") || line.contains("团体")) {
            units.add(UnitSeed.from(line, source(block)));
        }
    }

    private static void fillRange(Field start, Field end, String line, ObjectNode source) {
        Matcher matcher = DATE.matcher(line);
        List<String> found = new ArrayList<>();
        while (matcher.find() && found.size() < 2) {
            found.add(format(matcher));
        }
        if (!found.isEmpty()) {
            start.offer(found.get(0), source, false);
        }
        if (found.size() > 1) {
            end.offer(found.get(1), source, false);
        }
    }

    private static String format(Matcher matcher) {
        int hour = matcher.group(4) == null ? 0 : Integer.parseInt(matcher.group(4));
        int minute = matcher.group(5) == null ? 0 : Integer.parseInt(matcher.group(5));
        return String.format("%s-%02d-%02d %02d:%02d:00",
            matcher.group(1), Integer.parseInt(matcher.group(2)), Integer.parseInt(matcher.group(3)), hour, minute);
    }

    private static String after(String line, String... labels) {
        for (String label : labels) {
            int at = line.indexOf(label);
            if (at < 0) {
                continue;
            }
            String rest = line.substring(at + label.length()).replaceFirst("^[：:\\s]+", "").trim();
            if (!rest.isEmpty() && rest.length() <= 1000) {
                return rest;
            }
        }
        return null;
    }

    private static ObjectNode source(Block block) {
        ObjectNode node = new ObjectMapper().createObjectNode();
        node.put("fileIndex", block.fileIndex());
        node.put("kind", block.kind());
        node.put("label", block.label());
        node.put("quote", block.text().length() > 80 ? block.text().substring(0, 80) : block.text());
        return node;
    }

    private static final class Field {
        private String value = "";
        private String status = "missing";
        private final List<ObjectNode> sources = new ArrayList<>();
        private final List<String> alternatives = new ArrayList<>();

        void offer(String incoming, ObjectNode source, boolean suggestion) {
            if (incoming == null || incoming.isBlank()) {
                return;
            }
            sources.add(source);
            if ("missing".equals(status)) {
                value = incoming;
                status = suggestion ? "suggestion" : "filled";
                return;
            }
            if (value.equals(incoming)) {
                return;
            }
            if (!alternatives.contains(value)) {
                alternatives.add(value);
            }
            if (!alternatives.contains(incoming)) {
                alternatives.add(incoming);
            }
            value = "";
            status = "conflict";
        }

        ObjectNode toJson(ObjectMapper mapper) {
            ObjectNode node = mapper.createObjectNode();
            node.put("value", value);
            node.put("status", status);
            ArrayNode sourceNodes = node.putArray("sources");
            sources.forEach(sourceNodes::add);
            ArrayNode alternativeNodes = node.putArray("alternatives");
            alternatives.forEach(alternativeNodes::add);
            return node;
        }
    }

    private record UnitSeed(String name, String entryType, boolean suggestedType, String quota, String min, String max, ObjectNode source) {
        static UnitSeed from(String line, ObjectNode source) {
            String entry = "individual";
            boolean suggested = true;
            if (line.contains("团体")) {
                entry = "team";
                suggested = false;
            } else if (line.contains("双打")) {
                entry = "pair";
                suggested = false;
            } else if (line.contains("单打")) {
                entry = "individual";
                suggested = false;
            }
            Matcher quota = QUOTA.matcher(line);
            String quotaText = quota.find() ? quota.group(1) : "";
            Matcher size = TEAM_SIZE.matcher(line);
            boolean sized = "team".equals(entry) && size.find();
            String name = line.replaceAll("(?:名额|限额|人数上限).*$", "").trim();
            if (name.length() > 80) {
                name = name.substring(0, 80);
            }
            return new UnitSeed(name, entry, suggested, quotaText,
                sized ? size.group(1) : "", sized ? size.group(2) : "", source);
        }

        ObjectNode toJson(ObjectMapper mapper) {
            ObjectNode node = mapper.createObjectNode();
            node.set("name", valued(mapper, name, "filled"));
            node.set("entryType", valued(mapper, entryType, suggestedType ? "suggestion" : "filled"));
            node.set("limitCount", valued(mapper, quota, quota.isEmpty() ? "missing" : "filled"));
            node.set("minMembers", valued(mapper, min, min.isEmpty() ? "missing" : "filled"));
            node.set("maxMembers", valued(mapper, max, max.isEmpty() ? "missing" : "filled"));
            return node;
        }

        private ObjectNode valued(ObjectMapper mapper, String raw, String state) {
            ObjectNode node = mapper.createObjectNode();
            node.put("value", raw);
            node.put("status", state);
            ArrayNode sources = node.putArray("sources");
            sources.add(source);
            node.putArray("alternatives");
            return node;
        }
    }
}
