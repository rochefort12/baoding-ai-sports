package org.dromara.sports.event.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.dromara.common.redis.utils.RedisUtils;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * 运营问答放在 Redis，创建时起 24 小时后过期。追加内容不把截止时间往后推。
 * Redis 不可用时返回未暂存，不把这次失败变成问答失败。
 */
@Service
public class OperationsChatRedis implements OperationsChatStore {

    private static final ZoneId SHANGHAI = ZoneId.of("Asia/Shanghai");

    private final ObjectMapper mapper;
    private final SportsEventAiProperties properties;

    public OperationsChatRedis(ObjectMapper mapper, SportsEventAiProperties properties) {
        this.mapper = mapper;
        this.properties = properties;
    }

    @Override
    public Held remember(long organizationId, long accountId, String sessionId, String userText, String reply) {
        try {
            OffsetDateTime now = OffsetDateTime.now(SHANGHAI);
            String id = valid(sessionId) ? sessionId : UUID.randomUUID().toString();
            String key = sessionKey(organizationId, accountId, id);
            String existing = RedisUtils.getCacheObject(key);
            OperationsChatDocument document;
            if (existing == null || existing.isBlank()) {
                document = OperationsChatDocument.create(id, now);
            } else {
                document = OperationsChatDocument.parse(id, existing, mapper);
                if (!document.expiresAt().isAfter(now)) {
                    document = OperationsChatDocument.create(id, now);
                }
            }
            document = document.append(userText, reply);
            Duration left = Duration.between(now, document.expiresAt());
            if (left.isZero() || left.isNegative()) {
                return Held.missed(id);
            }
            RedisUtils.setCacheObject(key, document.json(mapper), left);
            writeIndex(organizationId, accountId, document, now);
            return new Held(id, document.expiresAt(), document.turns(), true);
        } catch (RuntimeException exception) {
            return Held.missed(valid(sessionId) ? sessionId : "");
        }
    }

    @Override
    public Held read(long organizationId, long accountId, String sessionId) {
        if (!valid(sessionId)) {
            return null;
        }
        try {
            String existing = RedisUtils.getCacheObject(sessionKey(organizationId, accountId, sessionId));
            if (existing == null || existing.isBlank()) {
                return null;
            }
            OperationsChatDocument document = OperationsChatDocument.parse(sessionId, existing, mapper);
            if (!document.expiresAt().isAfter(OffsetDateTime.now(SHANGHAI))) {
                return null;
            }
            return new Held(sessionId, document.expiresAt(), document.turns(), true);
        } catch (RuntimeException exception) {
            return null;
        }
    }

    @Override
    public List<Summary> list(long organizationId, long accountId) {
        try {
            String raw = RedisUtils.getCacheObject(indexKey(organizationId, accountId));
            if (raw == null || raw.isBlank()) {
                return List.of();
            }
            OffsetDateTime now = OffsetDateTime.now(SHANGHAI);
            List<Summary> summaries = new ArrayList<>();
            for (JsonNode item : mapper.readTree(raw)) {
                String id = item.path("sessionId").asText("");
                if (!valid(id)) {
                    continue;
                }
                Held held = read(organizationId, accountId, id);
                if (held == null || held.expiresAt() == null || !held.expiresAt().isAfter(now)) {
                    continue;
                }
                summaries.add(new Summary(id, item.path("preview").asText("运营问答"), held.expiresAt()));
                if (summaries.size() >= sessionLimit()) {
                    break;
                }
            }
            return summaries;
        } catch (Exception exception) {
            return List.of();
        }
    }

    private void writeIndex(long organizationId, long accountId, OperationsChatDocument document, OffsetDateTime now) {
        try {
            String raw = RedisUtils.getCacheObject(indexKey(organizationId, accountId));
            List<String> existingIds = new ArrayList<>();
            if (raw != null && !raw.isBlank()) {
                for (JsonNode item : mapper.readTree(raw)) {
                    String id = item.path("sessionId").asText("");
                    if (valid(id)) {
                        existingIds.add(id);
                    }
                }
            }
            for (String dropped : OperationsChatLimit.overflow(existingIds, document.id(), sessionLimit())) {
                RedisUtils.deleteObject(sessionKey(organizationId, accountId, dropped));
            }
            ArrayNode kept = mapper.createArrayNode();
            ObjectNode current = kept.addObject();
            current.put("sessionId", document.id());
            current.put("preview", document.preview());
            current.put("expiresAt", document.expiresAt().toString());
            if (raw != null && !raw.isBlank()) {
                for (JsonNode item : mapper.readTree(raw)) {
                    if (kept.size() >= sessionLimit()) {
                        break;
                    }
                    String id = item.path("sessionId").asText("");
                    if (!valid(id) || id.equals(document.id())) {
                        continue;
                    }
                    OffsetDateTime expiresAt = OffsetDateTime.parse(item.path("expiresAt").asText());
                    if (expiresAt.isAfter(now) && RedisUtils.isExistsObject(sessionKey(organizationId, accountId, id))) {
                        kept.add(item);
                    }
                }
            }
            OffsetDateTime latest = document.expiresAt();
            for (JsonNode item : kept) {
                OffsetDateTime expiresAt = OffsetDateTime.parse(item.path("expiresAt").asText());
                if (expiresAt.isAfter(latest)) {
                    latest = expiresAt;
                }
            }
            Duration left = Duration.between(now, latest);
            RedisUtils.setCacheObject(indexKey(organizationId, accountId), kept.toString(), left.isZero() || left.isNegative() ? Duration.ofSeconds(1) : left);
        } catch (Exception exception) {
            // 单段问答已经写下。列表失败时刷新后仍可用会话编号读回。
        }
    }

    @Override
    public int sessionLimit() {
        return properties.opsSessionLimit();
    }

    @Override
    public void discard(long organizationId, long accountId, String sessionId) {
        if (!valid(sessionId)) {
            return;
        }
        try {
            RedisUtils.deleteObject(sessionKey(organizationId, accountId, sessionId));
            String raw = RedisUtils.getCacheObject(indexKey(organizationId, accountId));
            if (raw == null || raw.isBlank()) {
                return;
            }
            ArrayNode kept = mapper.createArrayNode();
            OffsetDateTime latest = null;
            for (JsonNode item : mapper.readTree(raw)) {
                String id = item.path("sessionId").asText("");
                if (!valid(id) || id.equals(sessionId) || !RedisUtils.isExistsObject(sessionKey(organizationId, accountId, id))) {
                    continue;
                }
                kept.add(item);
                OffsetDateTime expiresAt = OffsetDateTime.parse(item.path("expiresAt").asText());
                if (latest == null || expiresAt.isAfter(latest)) {
                    latest = expiresAt;
                }
            }
            if (kept.isEmpty() || latest == null) {
                RedisUtils.deleteObject(indexKey(organizationId, accountId));
                return;
            }
            Duration left = Duration.between(OffsetDateTime.now(SHANGHAI), latest);
            RedisUtils.setCacheObject(indexKey(organizationId, accountId), kept.toString(), left.isZero() || left.isNegative() ? Duration.ofSeconds(1) : left);
        } catch (Exception exception) {
            // 正文键已经删掉。列表残留会在下次读取时被跳过。
        }
    }

    public static boolean valid(String sessionId) {
        if (sessionId == null || sessionId.isBlank()) {
            return false;
        }
        try {
            return UUID.fromString(sessionId).toString().equals(sessionId);
        } catch (IllegalArgumentException exception) {
            return false;
        }
    }

    private static String sessionKey(long organizationId, long accountId, String sessionId) {
        return "sports:ai:ops:" + organizationId + ":" + accountId + ":" + sessionId;
    }

    private static String indexKey(long organizationId, long accountId) {
        return "sports:ai:ops:" + organizationId + ":" + accountId + ":index";
    }
}
