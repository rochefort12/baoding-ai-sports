package org.dromara.sports.event.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * 一段运营问答的暂存内容。到期时间在创建时定下，后续追加不延长。
 */
public final class OperationsChatDocument {

    public static final Duration KEEP = Duration.ofHours(24);
    public static final int MAX_TURNS = 40;
    public static final int MAX_TEXT = 2000;

    private final String id;
    private final OffsetDateTime expiresAt;
    private final List<Turn> turns;

    private OperationsChatDocument(String id, OffsetDateTime expiresAt, List<Turn> turns) {
        this.id = id;
        this.expiresAt = expiresAt;
        this.turns = List.copyOf(turns);
    }

    public static OperationsChatDocument create(String id, OffsetDateTime now) {
        return new OperationsChatDocument(id, now.plus(KEEP), List.of());
    }

    public OperationsChatDocument append(String userText, String reply) {
        List<Turn> next = new ArrayList<>(turns);
        next.add(new Turn(true, clip(userText)));
        next.add(new Turn(false, clip(reply)));
        while (next.size() > MAX_TURNS) {
            next.remove(0);
        }
        return new OperationsChatDocument(id, expiresAt, next);
    }

    public String id() {
        return id;
    }

    public OffsetDateTime expiresAt() {
        return expiresAt;
    }

    public List<Turn> turns() {
        return turns;
    }

    public String preview() {
        for (int i = turns.size() - 1; i >= 0; i--) {
            Turn turn = turns.get(i);
            if (turn.user() && !turn.text().isBlank()) {
                String compact = turn.text().replace('\n', ' ').trim();
                return compact.length() > 24 ? compact.substring(0, 24) : compact;
            }
        }
        return "运营问答";
    }

    public String json(ObjectMapper mapper) {
        ObjectNode node = mapper.createObjectNode();
        node.put("expiresAt", expiresAt.toString());
        ArrayNode array = node.putArray("turns");
        for (Turn turn : turns) {
            ObjectNode item = array.addObject();
            item.put("user", turn.user());
            item.put("text", turn.text());
        }
        return node.toString();
    }

    public static OperationsChatDocument parse(String id, String json, ObjectMapper mapper) {
        try {
            JsonNode node = mapper.readTree(json);
            OffsetDateTime expiresAt = OffsetDateTime.parse(node.path("expiresAt").asText());
            List<Turn> turns = new ArrayList<>();
            for (JsonNode item : node.path("turns")) {
                turns.add(new Turn(item.path("user").asBoolean(false), clip(item.path("text").asText(""))));
            }
            while (turns.size() > MAX_TURNS) {
                turns.remove(0);
            }
            return new OperationsChatDocument(id, expiresAt, turns);
        } catch (Exception exception) {
            throw new IllegalArgumentException("问答暂存读不出来");
        }
    }

    public static String clip(String text) {
        String value = text == null ? "" : text.replace("\u0000", "").trim();
        return value.length() > MAX_TEXT ? value.substring(0, MAX_TEXT) : value;
    }

    public record Turn(boolean user, String text) {
    }
}
