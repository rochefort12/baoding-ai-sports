package org.dromara.sports.event.service;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.dromara.sports.platform.core.*;
import org.springframework.stereotype.Service;
import java.util.List;
import java.util.Set;
import static org.dromara.sports.platform.core.BusinessSupport.*;

/** Both page writes use the registry/executor. Agent channels remain disabled until separately verified. */
@Service @RequiredArgsConstructor
public class EventMaterialActionProvider implements CapabilityProvider {
    private final EventMaterialService materials;
    private final ObjectMapper json;
    private static final Set<String> READS = Set.of("asp_event","asp_event_poster","asp_competition_unit","asp_fee_policy","asp_event_payment_config","asp_organization","asp_organization_application","asp_account_tenant_principal","asp_account","asp_file");
    public List<CapabilityDefinition> capabilities() { return List.of(
        capability(json,"event.material.save","保存赛事工作文稿","asp_event",false,false,Set.of("organizer"),"",READS,Set.of("asp_event"),"eventId","kind","expectedVersion","factDigest","title","content"),
        capability(json,"event.material.generate","AI生成赛事策划脚本公告宣传草稿","asp_event",false,false,Set.of("organizer"),"",READS,Set.of("asp_event"),"eventId","kind","expectedVersion","factDigest","note?","consent"),
        capability(json,"event.cover.save","更换赛事展示封面","asp_event",false,false,Set.of("organizer"),"",READS,Set.of("asp_event"),"eventId","expectedVersion","fileId?")
    ); }
    public JsonNode preview(String code, JsonNode input) { return materials.current(id(input,"eventId")); }
    public JsonNode execute(String code, JsonNode input) {
        long eventId=id(input,"eventId"), version=input.path("expectedVersion").asLong(-1);
        if (version < 0) throw fail("请提供当前材料版本",400);
        if(code.equals("event.cover.save"))return materials.saveCover(eventId,version,optionalId(input,"fileId"));
        String kind=text(input,"kind",30), digest=text(input,"factDigest",64);
        if (code.equals("event.material.save")) return materials.save(eventId,kind,version,digest,text(input,"title",200),text(input,"content",18000));
        if (code.equals("event.material.generate")) {
            if (!"confirmed".equals(input.path("consent").asText())) throw fail("请先同意将必要赛事信息用于AI生成",400);
            return materials.generate(eventId,kind,version,digest,input.path("note").asText(""));
        }
        throw fail("不支持的文稿操作",400);
    }
}
