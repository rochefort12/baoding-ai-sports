package org.dromara.sports.event.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.event.ai.SportsEventAiProperties;
import org.dromara.sports.event.ai.SportsEventCallAiGatewayClient;
import org.dromara.sports.api.StoredObjectApi;
import org.dromara.sports.platform.core.BusinessIdentity;
import org.dromara.sports.platform.core.JsonFingerprint;
import org.dromara.sports.platform.core.ScopedJdbc;
import org.springframework.stereotype.Service;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Set;

/** The event owns its private working drafts. Saving a draft never publishes rules, announcements or SMS. */
@Service @RequiredArgsConstructor
public class EventMaterialService {
    private final EventPublicationService events;
    private final EventPromotionService promotion;
    private final SportsEventCallAiGatewayClient gateway;
    private final SportsEventAiProperties properties;
    private final ScopedJdbc db;
    private final ObjectMapper json;
    private final StoredObjectApi files;
    static final Set<String> KINDS = Set.of("plan", "script", "announcement", "promotion");

    public ObjectNode current(long eventId) {
        var event = events.managed(eventId); // Organization and tenant guards run before document reads.
        var promo = promotion.current(eventId);
        var facts = json.createObjectNode();
        facts.put("name", event.name()); facts.put("project", event.projectName());
        facts.put("when", promo.whenText()); facts.put("where", event.location());
        // Working copy uses the same Beijing clock as the public event card.
        // A UTC database offset must not leak into a participant-facing deadline.
        facts.put("registrationClosesAt", localDeadline(event.registrationClosesAt()));
        facts.put("timezone", "Asia/Shanghai");
        facts.put("organization", promo.organizationName()); facts.put("contact", promo.contactName() + " " + promo.contactMethod());
        facts.put("feeDescription", event.feeDescription()); facts.set("fees", json.valueToTree(promo.fees()));
        facts.put("rules", event.rulesText()); facts.put("notice", event.noticeText());
        facts.put("published", promo.published()); facts.put("cancelled", promo.cancelled());
        var row = db.one("SELECT operations_materials::text AS materials,version AS event_version FROM asp_event WHERE id=? AND tenant_id=?", eventId, BusinessIdentity.getTenantId());
        if (row == null) throw new ServiceException("赛事不存在或当前组织无权访问");
        var result = json.createObjectNode(); result.put("eventId", Long.toString(eventId));
        result.set("facts", facts); result.put("factDigest", JsonFingerprint.hash(facts));
        result.put("aiAvailable", properties.keyConfigured() && properties.tokenConfigured());
        result.put("eventVersion", row.get("event_version") == null ? 0 : ((Number)row.get("event_version")).longValue());
        result.set("materials", parse(row.get("materials"))); return result;
    }

    /** Cover is presentation media only; changing it never changes frozen rules, roster or fee snapshots. */
    public JsonNode saveCover(long eventId, long expectedVersion, Long fileId) {
        var event=events.managed(eventId);
        if ("cancelled".equals(event.holdingStatus())) throw new ServiceException("已取消赛事保留原封面，不能继续调整宣传");
        var row=db.one("SELECT version FROM asp_event WHERE id=? AND tenant_id=? FOR UPDATE",eventId,BusinessIdentity.getTenantId());
        if(row==null || ((Number)row.get("version")).longValue()!=expectedVersion) throw new ServiceException("赛事已更新，请重新读取后选择封面",409);
        if(fileId!=null) files.requireImage(fileId,StoredObjectApi.EVENT_BANNER,BusinessIdentity.getTenantId());
        if(db.update("UPDATE asp_event SET banner_file_id=?,version=version+1,update_time=CURRENT_TIMESTAMP,update_by=? WHERE id=? AND tenant_id=?",
            fileId,BusinessIdentity.getUserId(),eventId,BusinessIdentity.getTenantId())!=1) throw new ServiceException("封面未保存，请重试");
        var result=json.createObjectNode().put("eventId",Long.toString(eventId)).put("status","saved");
        if(fileId==null)result.putNull("bannerFileId");else result.put("bannerFileId",Long.toString(fileId));return result;
    }

    public JsonNode save(long eventId, String kind, long expectedVersion, String expectedDigest, String title, String content) {
        return saveDraft(eventId, kind, expectedVersion, expectedDigest, title, content, "manual");
    }

    public JsonNode generate(long eventId, String kind, long expectedVersion, String expectedDigest, String note) {
        checkKind(kind);
        var before = current(eventId); requireDigest(before, expectedDigest);
        if (before.path("materials").path(kind).path("version").asLong(0) != expectedVersion) throw new ServiceException("这份材料已变化，请先刷新核对，避免重复生成费用", 409);
        if (note == null || note.length() > 1000) throw new ServiceException("创作要求最多1000字");
        // The model call precedes the row lock. Only a successful, still-current draft is committed.
        var material = gateway.composeMaterial(before.path("facts"), kind, note);
        return saveDraft(eventId, kind, expectedVersion, expectedDigest, material.path("title").asText(), material.path("content").asText(), "ai");
    }

    private JsonNode saveDraft(long eventId, String kind, long expectedVersion, String expectedDigest, String title, String content, String source) {
        checkKind(kind);
        if (title == null || title.isBlank() || title.length() > 200 || content == null || content.isBlank() || content.length() > 10000)
            throw new ServiceException("请填写标题和正文，标题最多200字，正文最多10000字");
        var view = current(eventId); requireDigest(view, expectedDigest);
        var locked = db.one("SELECT operations_materials::text AS materials FROM asp_event WHERE id=? AND tenant_id=? FOR UPDATE", eventId, BusinessIdentity.getTenantId());
        if (locked == null) throw new ServiceException("赛事不存在或当前组织无权访问");
        // Facts may have changed while waiting for the row lock; re-read after acquiring it.
        requireDigest(current(eventId), expectedDigest);
        var materials = (ObjectNode) parse(locked.get("materials"));
        var old = materials.path(kind); long actualVersion = old.path("version").asLong(0);
        if (actualVersion != expectedVersion) throw new ServiceException("这份材料已在其他窗口修改，请刷新后核对；当前编辑内容保留", 409);
        var history = json.createArrayNode();
        if (!old.isMissingNode()) {
            var prior = old.deepCopy(); ((ObjectNode) prior).remove("history"); history.add(prior);
            for (var item : old.path("history")) { if (history.size() >= 10) break; history.add(item); }
        }
        var draft = json.createObjectNode().put("kind", kind).put("title", title.strip()).put("content", content.strip())
            .put("version", actualVersion + 1).put("source", source).put("factDigest", expectedDigest)
            .put("updatedAt", OffsetDateTime.now().toString()).put("updatedBy", BusinessIdentity.getUserId().toString());
        draft.set("history", history); materials.set(kind, draft);
        if (db.update("UPDATE asp_event SET operations_materials=?::jsonb,version=version+1,update_time=CURRENT_TIMESTAMP,update_by=? WHERE id=? AND tenant_id=?",
            materials.toString(), BusinessIdentity.getUserId(), eventId, BusinessIdentity.getTenantId()) != 1) throw new ServiceException("材料未保存，请刷新后重试");
        return draft;
    }
    private void checkKind(String kind) { if (!KINDS.contains(kind)) throw new ServiceException("请选择策划、脚本、公告或宣传"); }
    static String localDeadline(OffsetDateTime value) {
        return value == null ? "" : value.atZoneSameInstant(ZoneId.of("Asia/Shanghai"))
            .format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm"));
    }
    private void requireDigest(JsonNode view, String digest) { if (!view.path("factDigest").asText().equals(digest)) throw new ServiceException("赛事信息已更新，请重新读取资料后核对；当前编辑内容保留", 409); }
    private JsonNode parse(Object raw) { try { var value = raw == null ? json.createObjectNode() : json.readTree(raw.toString()); if (!value.isObject()) throw new IllegalArgumentException(); return value; } catch (Exception broken) { throw new ServiceException("材料存储格式异常，请联系平台处理；原记录未修改"); } }
}
