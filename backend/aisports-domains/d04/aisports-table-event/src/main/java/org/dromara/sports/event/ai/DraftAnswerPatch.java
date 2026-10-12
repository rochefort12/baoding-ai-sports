package org.dromara.sports.event.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

/** Resolve explicit short answers against the current draft, never a different event.
 * Fixed member counts permit candidate arithmetic; variable teams keep per-person
 * pricing unresolved until the organizer confirms the actual order price.
 */
final class DraftAnswerPatch {
    // An organizer's explicit all-project quotation means the order price of each
    // project. It is a candidate policy, never a statement that money arrived.
    private static final Pattern FEE = Pattern.compile("(?:每人|每位|每单|每组|每队|每项|所有项目|全部项目|每个项目|各项目)\\s*(?:收费|收|费用|报名费|价格|总价)?\\s*(?:为|是)?\\s*(\\d{1,8}(?:\\.\\d{1,2})?)\\s*元");
    private static final Pattern AGE = Pattern.compile("^(?:参赛)?(?:年龄)?\\s*(\\d{1,3})\\s*[-—–~～至到]\\s*(\\d{1,3})\\s*岁?(?:之间)?[。！!]?$");
    private DraftAnswerPatch() { }

    static String apply(ObjectMapper mapper, ObjectNode root, String message) {
        if (message == null || message.length() > 160 || message.matches(".*(?:不是|不要|不收|是否|吗|？|\\?).*")) return null;
        String previous = root.path("nextQuestion").path("text").asText("");
        if (previous.isBlank()) {
            JsonNode dialogue = root.path("dialogue");
            for (int i = dialogue.size() - 1; i >= 0; i--) if (!"user".equals(dialogue.get(i).path("role").asText())) { previous = dialogue.get(i).path("text").asText(""); break; }
        }
        var age = AGE.matcher(message.trim());
        if (age.matches() && (previous.contains("年龄") || previous.contains("岁") || message.contains("年龄"))) {
            int min = Integer.parseInt(age.group(1)), max = Integer.parseInt(age.group(2));
            if (min > max || max > 120) return null;
            ObjectNode patch = mapper.createObjectNode();
            String original = root.path("event").path("rulesText").path("value").asText("");
            String rule = "参赛年龄：" + min + "-" + max + "岁";
            String rules = original.replaceAll("(?m)^参赛年龄：[\\d\\s—–~～至到-]+岁\\s*$", "").stripTrailing();
            field(patch.putObject("event"), "rulesText", (rules.isBlank() ? "" : rules + "\n") + rule);
            patch.put("reply", "已把" + min + "-" + max + "岁的参赛要求写入草稿。");
            root.withObject("answeredTopics").put("age", rule);
            return patch.toString();
        }
        var fee = FEE.matcher(message);
        if (!fee.find()) return null;
        if (fee.find()) return null; // Multiple different prices need project-specific interpretation.
        fee.reset(); fee.find();
        JsonNode units = root.path("units");
        if (!units.isArray() || units.isEmpty()) return null;
        String remainder = FEE.matcher(message).replaceAll("");
        for (JsonNode unit : units) {
            String name = unit.path("name").path("value").asText("");
            if (!name.isBlank()) remainder = remainder.replace(name, "");
        }
        remainder = remainder.replaceAll("(?:所有项目|全部项目|每个项目|各项目|本项目|这个项目|其他项目不变|其它项目不变|调整为|改为|改成|确定为|设置为|定为|我确认|我想|报名费|费用|收费|总价|价格|统一|免费|确认|确定|请|就|按|收|是|为|都|吧|好了|[\\s，,。；;：:！!])", "");
        // A combined answer must go through the model merge in full, never silently drop its other fields.
        if (!remainder.isBlank()) return null;
        List<Integer> targets = new ArrayList<>();
        boolean all = message.matches(".*(?:所有项目|全部项目|每个项目|各项目|每项).*" );
        for (int i = 0; i < units.size(); i++) if (all || units.size() == 1 || (!units.get(i).path("name").path("value").asText("").isBlank() && message.contains(units.get(i).path("name").path("value").asText()))) targets.add(i);
        if (targets.isEmpty() && previous.matches(".*(?:费|每人|整单|总价|金额).*")) {
            String nextField = root.path("nextQuestion").path("field").asText("");
            var index = Pattern.compile("^units\\[(\\d+)\\]\\.feeAmount$").matcher(nextField);
            if (index.matches() && Integer.parseInt(index.group(1)) < units.size()) targets.add(Integer.parseInt(index.group(1)));
        }
        if (targets.isEmpty()) return null;
        BigDecimal amount = new BigDecimal(fee.group(1));
        boolean perPerson = fee.group().startsWith("每人") || fee.group().startsWith("每位");
        ObjectNode patch = mapper.createObjectNode(); var changed = patch.putArray("units");
        // Keep project order stable so the following question still targets the same form row.
        for (JsonNode unit : units) changed.addObject().set("name", unit.path("name").deepCopy());
        List<String> acknowledgements = new ArrayList<>();
        ObjectNode confirmedQuotes = root.withObject("confirmedFeeQuotes");
        for (int index : targets) {
            JsonNode original = units.get(index); ObjectNode unit = (ObjectNode) changed.get(index);
            String type = original.path("entryType").path("value").asText("");
            int count = "individual".equals(type) ? 1 : "pair".equals(type) ? 2 : original.path("minMembers").path("value").asInt(0);
            boolean fixed = count > 0 && (!"team".equals(type) || count == original.path("maxMembers").path("value").asInt(0));
            BigDecimal order = perPerson && fixed ? amount.multiply(BigDecimal.valueOf(count)) : amount;
            field(unit, "feeAmount", order.toPlainString()); field(unit, "feeBasis", perPerson && !fixed ? "per_person" : "order");
            String name = original.path("name").path("value").asText("项目");
            String quote = name + "：" + (perPerson ? "每人" + amount.toPlainString() + "元，" : "") + (perPerson && !fixed ? "人数未定，已保留报价，整单总价待确认" : "每单" + order.toPlainString() + "元");
            acknowledgements.add(quote);
            confirmedQuotes.put(name, quote);
        }
        String feeText = String.join("；", acknowledgements);
        String originalFee = root.path("event").path("feeDescription").path("value").asText("");
        String previousSummary = root.path("generatedFeeSummary").asText("");
        // Only replace our own previous appended summary. Original notice conditions remain evidence.
        if (!previousSummary.isBlank() && originalFee.endsWith(previousSummary)) originalFee = originalFee.substring(0, originalFee.length() - previousSummary.length()).stripTrailing();
        List<String> currentQuotes = new ArrayList<>();
        for (int i = 0; i < units.size(); i++) {
            JsonNode unit = units.get(i);
            String name = unit.path("name").path("value").asText("");
            String quote = targets.contains(i) ? confirmedQuotes.path(name).asText("") : "";
            // A form edit can change another project's price after its earlier spoken answer.
            // The current field is authoritative; never repeat its cached older quotation.
            if (!targets.contains(i) && "filled".equals(unit.path("feeAmount").path("status").asText())) {
                String current = unit.path("feeAmount").path("value").asText("");
                String basis = unit.path("feeBasis").path("value").asText("");
                if (!current.isBlank() && "order".equals(basis)) quote = name + "：每单" + current + "元";
                else if (!current.isBlank() && "per_person".equals(basis)) quote = name + "：每人" + current + "元，整单总价待确认";
            }
            if (!quote.isBlank()) currentQuotes.add(quote);
        }
        String summary = "本次确认报价：" + String.join("；", currentQuotes);
        root.put("generatedFeeSummary", summary);
        field(patch.putObject("event"), "feeDescription", (originalFee.isBlank() ? "" : originalFee + "\n") + summary);
        patch.put("reply", "已写入草稿。" + feeText + "。创建前可在表单核对，这没有登记收款。");
        return patch.toString();
    }

    private static void field(ObjectNode parent, String name, String value) {
        parent.putObject(name).put("value", value).put("status", "filled").putArray("sources");
    }
}
