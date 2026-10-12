package org.dromara.sports.event.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import java.util.LinkedHashMap;
import java.util.Map;

/** 同一JSON快照承载发布前候选及发布后承诺；候选绝不能被当成已同意公开。 */
final class EventPublicationTerms {
    private EventPublicationTerms() { }
    static JsonNode read(ObjectMapper mapper, String snapshot) {
        try { return mapper.readTree(snapshot == null ? "{}" : snapshot); }
        catch (Exception ignored) { return mapper.createObjectNode(); }
    }
    static boolean isDraft(JsonNode node) { return node != null && "draft".equals(node.path("state").asText()); }
    static String text(JsonNode node, String key) {
        String value = node == null ? "" : node.path(key).asText("").trim();
        return value.isEmpty() ? null : value;
    }
    static String draft(ObjectMapper mapper, String current, Long organizationId,
                        String name, String method, String refundTerms) {
        JsonNode previous = read(mapper,current);
        // 缺省参数保留旧草稿，避免旧接口、封面编辑清空来源；显式空字符串才表示清除。
        if (name == null && method == null && refundTerms == null) return current;
        if (!isDraft(previous) && text(previous,"confirmedAt") != null) {
            if ((name != null && !java.util.Objects.equals(clean(name),text(previous,"contactName")))
                || (method != null && !java.util.Objects.equals(clean(method),text(previous,"contactMethod")))
                || (refundTerms != null && !java.util.Objects.equals(clean(refundTerms),text(previous,"refundTerms")))) {
                throw new ServiceException("已发布的联系信息和退改承诺已冻结，不能通过编辑草稿变更");
            }
            return current;
        }
        Map<String,Object> candidate = new LinkedHashMap<>();
        candidate.put("state","draft"); candidate.put("organizationId",organizationId);
        candidate.put("contactName",name == null ? text(previous,"contactName") : clean(name));
        candidate.put("contactMethod",method == null ? text(previous,"contactMethod") : clean(method));
        candidate.put("refundTerms",refundTerms == null ? text(previous,"refundTerms") : clean(refundTerms));
        try { return mapper.writeValueAsString(candidate); }
        catch (Exception ignored) { throw new ServiceException("赛事联系和退改草稿无法保存"); }
    }
    static String refund(ObjectMapper mapper, String current, String legacyExplanation) {
        String terms = text(read(mapper,current),"refundTerms");
        return terms == null ? legacyExplanation : terms;
    }
    private static String clean(String value) { return value == null || value.trim().isEmpty() ? null : value.trim(); }
}
