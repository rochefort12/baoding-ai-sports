package org.dromara.sports.event.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

import java.util.ArrayList;
import java.util.List;

/**
 * 把模型给出的草稿补丁合并进已有草稿，并留下对话。
 * 不判断用户想做什么；创建与否由调用方看模型给出的 action。
 */
public final class DraftMerge {

    static final String[] EVENT_FIELDS = {
        "name", "location", "projectName", "feeDescription",
        "registrationOpensAt", "registrationClosesAt", "startsAt", "endsAt",
        "registrationReview", "rulesText", "contactName", "contactMethod", "refundTerms", "declarationText"
    };
    private static final String[] UNIT_FIELDS = {"name", "entryType", "limitCount", "minMembers", "maxMembers", "feeAmount", "feeBasis"};

    private DraftMerge() {
    }

    public static Merged absorb(ObjectMapper mapper, String previous, String agentJson, String userMessage, boolean allowCreate) {
        ObjectNode current = readObject(mapper, previous);
        JsonNode agent = readObject(mapper, agentJson);
        String action = agent.path("action").asText("ask");
        if (!"ask".equals(action) && !"update".equals(action) && !"create".equals(action)) {
            action = "ask";
        }
        if (!allowCreate && "create".equals(action)) {
            action = "ask";
        }
        ObjectNode event = current.withObject("event");
        JsonNode incomingEvent = agent.path("event");
        if (incomingEvent.isObject()) {
            for (String field : EVENT_FIELDS) {
                if (incomingEvent.has(field)) {
                    event.set(field, copyField(mapper, field, incomingEvent.get(field), userMessage, event.get(field)));
                }
            }
        }
        for (String field : EVENT_FIELDS) {
            if (!event.has(field)) {
                event.set(field, emptyField(mapper));
            }
        }
        if (agent.has("units") && agent.path("units").isArray() && !agent.path("units").isEmpty()) {
            JsonNode existingUnits = current.path("units");
            // 模型的整体替换标记不能自行删除年龄/水平/亲子等分类项目。
            boolean replace = replacingUnits(userMessage);
            boolean[] used = existingUnits.isArray() ? new boolean[existingUnits.size()] : new boolean[0];
            ArrayNode units = mapper.createArrayNode();
            int incomingIndex = 0;
            for (JsonNode unit : agent.path("units")) {
                int match = matchUnit(existingUnits, used, unit, incomingIndex);
                ObjectNode copy = units.addObject();
                JsonNode prior = match >= 0 ? existingUnits.get(match) : null;
                for (String field : UNIT_FIELDS) {
                    copy.set(field, copyField(mapper, field, unit.path(field), userMessage, prior == null ? null : prior.get(field)));
                }
                // The model cannot invent a business project ID; matching the current candidate owns it.
                if(prior!=null&&prior.has("createdUnitId"))copy.set("createdUnitId",prior.path("createdUnitId").deepCopy());
                if (match >= 0) {
                    used[match] = true;
                }
                incomingIndex++;
            }
            if (!replace && existingUnits.isArray()) {
                for (int i = 0; i < existingUnits.size(); i++) {
                    if (!used[i]) {
                        units.add(existingUnits.get(i).deepCopy());
                    }
                }
            }
            current.set("units", units);
        } else if (!current.path("units").isArray()) {
            current.putArray("units");
        }
        String reply = agent.path("reply").asText("").trim();
        if (reply.isEmpty()) {
            reply = "我按目前听到的更新了草稿。";
        }
        ArrayNode dialogue = current.withArray("dialogue");
        if (userMessage != null && !userMessage.isBlank()) {
            dialogue.add(turn(mapper, "user", userMessage.trim()));
        }
        dialogue.add(turn(mapper, "ai", reply));
        while (dialogue.size() > 40) {
            dialogue.remove(0);
        }
        ArrayNode suggestions = mapper.createArrayNode();
        if (agent.path("suggestions").isArray()) {
            for (JsonNode item : agent.path("suggestions")) {
                String text = item.asText("").trim();
                if (!text.isEmpty() && suggestions.size() < 4) {
                    suggestions.add(text.length() > 40 ? text.substring(0, 40) : text);
                }
            }
        }
        current.put("version", 1);
        current.set("suggestions", suggestions);
        current.putArray("warnings").add("项目价格是待确认草稿；只有您确认后才保存。收款渠道和公开发布仍需核对，未识别费用不会自动设成免费。");
        return new Merged(current.toString(), reply, action, texts(suggestions));
    }

    public static String field(ObjectMapper mapper, String proposal, String name) {
        return readObject(mapper, proposal).path("event").path(name).path("value").asText("");
    }

    private static ObjectNode readObject(ObjectMapper mapper, String raw) {
        try {
            JsonNode node = mapper.readTree(raw == null || raw.isBlank() ? "{}" : raw);
            if (node.isObject()) {
                return (ObjectNode) node;
            }
        } catch (Exception ignored) {
            // 坏掉的旧草稿按空草稿继续，不中断这场对话。
        }
        return mapper.createObjectNode();
    }

    private static boolean replacingUnits(String userMessage) {
        if (userMessage == null) {
            return false;
        }
        return userMessage.contains("只保留") || userMessage.contains("删掉") || userMessage.contains("去掉");
    }

    private static int matchUnit(JsonNode existingUnits, boolean[] used, JsonNode incoming, int incomingIndex) {
        if (!existingUnits.isArray()) {
            return -1;
        }
        String incomingName = unitName(incoming);
        if (!incomingName.isBlank()) {
            for (int i = 0; i < existingUnits.size(); i++) {
                if (!used[i] && incomingName.equals(unitName(existingUnits.get(i)))) {
                    return i;
                }
            }
            return -1;
        }
        if (incomingIndex < existingUnits.size() && !used[incomingIndex] && unitName(existingUnits.get(incomingIndex)).isBlank()) {
            return incomingIndex;
        }
        return -1;
    }

    private static String unitName(JsonNode unit) {
        JsonNode name = unit.path("name");
        String value = name.isObject() ? name.path("value").asText("") : name.asText("");
        return value.trim();
    }

    private static ObjectNode copyField(ObjectMapper mapper, String name, JsonNode source, String userMessage, JsonNode existing) {
        if (existing instanceof ObjectNode prior && !prior.path("value").asText("").isBlank()) {
            String incomingValue = incomingText(name, source);
            if (incomingValue.isBlank() && (source == null || !"conflict".equals(source.path("status").asText()))) {
                return prior.deepCopy();
            }
        }
        ObjectNode node = mapper.createObjectNode();
        if (source != null && source.isObject()) {
            String value = source.path("value").asText("");
            if ("registrationReview".equals(name)) {
                value = "manual".equals(value) || "none".equals(value) ? value : "";
            }
            if ("entryType".equals(name) && !value.isEmpty() && !"individual".equals(value) && !"pair".equals(value) && !"team".equals(value)) {
                value = "";
            }
            node.put("value", value);
            String status = source.path("status").asText("filled");
            if (!"missing".equals(status) && !"filled".equals(status) && !"conflict".equals(status) && !"suggestion".equals(status)) {
                status = "filled";
            }
            node.put("status", value.isBlank() && !"conflict".equals(status) ? "missing" : status);
            keepConfirmedStatus(node, existing);
            ArrayNode sources = source.path("sources").isArray() ? (ArrayNode) source.path("sources").deepCopy() : mapper.createArrayNode();
            if (sources.isEmpty() && userMessage != null && !userMessage.isBlank() && !value.isBlank()) {
                ObjectNode fromTalk = sources.addObject();
                fromTalk.put("kind", "dialogue");
                fromTalk.put("label", "对话");
                fromTalk.put("quote", userMessage.length() > 80 ? userMessage.substring(0, 80) : userMessage);
            }
            node.set("sources", sources);
            node.set("alternatives", source.path("alternatives").isArray() ? source.path("alternatives").deepCopy() : mapper.createArrayNode());
            return node;
        }
        String value = source == null || source.isMissingNode() || source.isNull() ? "" : source.asText("");
        if ("registrationReview".equals(name)) {
            value = "manual".equals(value) || "none".equals(value) ? value : "";
        }
        node.put("value", value);
        node.put("status", value.isBlank() ? "missing" : "filled");
        keepConfirmedStatus(node, existing);
        ArrayNode sources = node.putArray("sources");
        if (!value.isBlank() && userMessage != null && !userMessage.isBlank()) {
            ObjectNode fromTalk = sources.addObject();
            fromTalk.put("kind", "dialogue");
            fromTalk.put("label", "对话");
            fromTalk.put("quote", userMessage.length() > 80 ? userMessage.substring(0, 80) : userMessage);
        }
        node.putArray("alternatives");
        return node;
    }

    private static String incomingText(String name, JsonNode source) {
        String value;
        if (source != null && source.isObject()) {
            value = source.path("value").asText("");
        } else if (source == null || source.isMissingNode() || source.isNull()) {
            value = "";
        } else {
            value = source.asText("");
        }
        if ("registrationReview".equals(name) && !"manual".equals(value) && !"none".equals(value)) {
            return "";
        }
        if ("entryType".equals(name) && !value.isEmpty() && !"individual".equals(value) && !"pair".equals(value) && !"team".equals(value)) {
            return "";
        }
        return value;
    }

    /** 已确认的值被原样带回时，不降成待定，避免下一轮把同一件事再问一遍。 */
    private static void keepConfirmedStatus(ObjectNode node, JsonNode existing) {
        if (!(existing instanceof ObjectNode prior)) {
            return;
        }
        if (!"filled".equals(prior.path("status").asText())) {
            return;
        }
        if (!prior.path("value").asText("").equals(node.path("value").asText(""))) {
            return;
        }
        if (!"conflict".equals(node.path("status").asText())) {
            node.put("status", "filled");
        }
    }

    private static ObjectNode emptyField(ObjectMapper mapper) {
        ObjectNode node = mapper.createObjectNode();
        node.put("value", "");
        node.put("status", "missing");
        node.putArray("sources");
        node.putArray("alternatives");
        return node;
    }

    private static ObjectNode turn(ObjectMapper mapper, String role, String text) {
        ObjectNode node = mapper.createObjectNode();
        node.put("role", role);
        node.put("text", text);
        return node;
    }

    private static List<String> texts(ArrayNode nodes) {
        List<String> values = new ArrayList<>();
        nodes.forEach(item -> values.add(item.asText()));
        return values;
    }

    public record Merged(String proposal, String reply, String action, List<String> suggestions) {
    }
}
