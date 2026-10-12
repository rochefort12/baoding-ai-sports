package org.dromara.sports.tables.d10.honor;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.net.URI;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.LinkedHashSet;
import java.util.Set;
import static org.dromara.sports.platform.core.BusinessSupport.*;

/** Typed application facts. An applicant never supplies a verified title, status, issuer or reviewer. */
final class HonorCertificationRules {
    private HonorCertificationRules() { }
    static ObjectNode claim(ObjectMapper json, String raw) {
        ObjectNode node = object(json, raw, Set.of("eventYear","eventName","sportId","place","level","sourceUrl","proofFileIds"));
        facts(node);
        String url = node.path("sourceUrl").asText("").strip();
        if (!url.isEmpty()) url(url);
        node.put("sourceUrl",url);
        var ids = node.path("proofFileIds");
        if (!ids.isArray() || ids.size()>8) throw fail("请保留最多8份证明材料",400);
        Set<Long> seen = new LinkedHashSet<>();
        for (var item:ids) {
            var holder=json.createObjectNode().set("fileId",item);
            if (!seen.add(id(holder,"fileId"))) throw fail("证明材料不能重复",400);
        }
        var canonical=node.putArray("proofFileIds");seen.forEach(v->canonical.add(v.toString()));
        return node;
    }
    static ObjectNode verified(ObjectMapper json, String raw) {
        ObjectNode node = object(json,raw,Set.of("eventYear","eventName","sportId","place","level","officialIssuer","officialResultsUrl"));
        facts(node);
        node.put("officialIssuer",plain(node,"officialIssuer",160));
        node.put("officialResultsUrl",url(plain(node,"officialResultsUrl",1000)));
        return node;
    }
    private static ObjectNode object(ObjectMapper json,String raw,Set<String> keys) {
        if (raw==null || raw.length()>6000) throw fail("认证资料过长",400);
        try {
            JsonNode parsed=json.readTree(raw);
            if (!parsed.isObject()) throw fail("请填写结构完整的认证资料",400);
            parsed.fieldNames().forEachRemaining(k->{if(!keys.contains(k))throw fail("认证资料包含不支持的字段",400);});
            return (ObjectNode)parsed;
        } catch(org.dromara.common.core.exception.ServiceException exception) {throw exception;}
        catch(Exception exception) {throw fail("认证资料格式不正确",400);}
    }
    private static void facts(ObjectNode n) {
        if (!n.path("level").isTextual() || !"world".equals(n.path("level").asText())) throw fail("本入口仅认证明确核实的世界级赛事荣誉",400);
        int max=LocalDate.now(ZoneId.of("Asia/Shanghai")).getYear();
        if (!n.path("eventYear").isIntegralNumber() || n.path("eventYear").asInt()<1900 || n.path("eventYear").asInt()>max)
            throw fail("请填写已举行赛事的真实年份",400);
        n.put("eventName",plain(n,"eventName",100));
        n.put("sportId",Long.toString(id(n,"sportId")));
        if (!n.path("place").isIntegralNumber() || !Set.of(1,2,3).contains(n.path("place").asInt()))
            throw fail("认证名次仅支持冠军、亚军和季军",400);
    }
    static String plain(JsonNode n,String key,int limit) {
        if (!n.path(key).isTextual()) throw fail("请填写"+key,400);
        String value=text(n,key,limit);
        if (value.chars().anyMatch(Character::isISOControl)) throw fail("认证文字不能包含控制字符",400);
        return value;
    }
    private static String url(String value) {
        try {
            URI u=URI.create(value);
            if (!"https".equalsIgnoreCase(u.getScheme()) || u.getHost()==null || u.getUserInfo()!=null
                || u.getHost().equalsIgnoreCase("localhost") || u.getHost().matches("[0-9.]+")) throw new IllegalArgumentException();
            // Stored as evidence, never fetched by the server. No internal networking or model browsing occurs.
            return value;
        } catch(Exception e) {throw fail("请填写公开结果页面的HTTPS地址",400);}
    }
    static String title(JsonNode facts,String sportName) {
        String title=facts.path("eventYear").asInt()+" · "+facts.path("eventName").asText()+" · "+sportName+" · 世界"+
            switch(facts.path("place").asInt()){case 1->"冠军";case 2->"亚军";case 3->"季军";default->throw fail("认证名次无效",400);};
        if(title.length()>200)throw fail("确认的赛事和项目名称过长",400);
        return title;
    }
    static void editable(String state) {if(!Set.of("draft","correction","rejected").contains(state))throw fail("已提交的认证资料不可直接修改，请查看办理进度",409);}
    static void wearable(String state,String legacyStatus) {if(!"approved".equals(state)||!"verified".equals(legacyStatus))throw fail("只有审核通过且有效的荣誉可以佩戴或公开",409);}
}
