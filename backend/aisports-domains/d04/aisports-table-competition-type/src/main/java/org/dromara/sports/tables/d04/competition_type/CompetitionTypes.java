package org.dromara.sports.tables.d04.competition_type;
import cn.dev33.satoken.annotation.SaIgnore;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.api.CompetitionTypeApi;
import org.dromara.sports.platform.core.ScopedJdbc;
import org.springframework.web.bind.annotation.*;
import java.util.Optional;
import java.util.List;
import java.util.Set;
import org.dromara.sports.platform.core.CapabilityProvider;
import org.dromara.sports.platform.core.CapabilityDefinition;
import static org.dromara.sports.platform.core.BusinessSupport.*;
@RestController @RequestMapping("/sports/types") @RequiredArgsConstructor
public class CompetitionTypes implements CompetitionTypeApi,CapabilityProvider {
    private final ScopedJdbc db;private final ObjectMapper json;
    public List<CapabilityDefinition> capabilities(){return List.of(capability(json,"type.catalog","读取开放运动、比赛类型与人数约束","asp_competition_type",true,false,Set.of("platform","organizer","government","admin"),"",Set.of("asp_sport","asp_competition_type"),Set.of()));}
    public JsonNode preview(String code,JsonNode in){return catalog().getData();}
    public JsonNode execute(String code,JsonNode in){return preview(code,in);}
    @GetMapping @SaIgnore public R<JsonNode> catalog(){var n=json.createObjectNode();n.set("sports",safeJson(json,db.list("SELECT id,code,name,capability_status FROM asp_sport WHERE status='active' ORDER BY name")));n.set("types",safeJson(json,db.list("SELECT id,sport_id,code,name,entry_type,min_members,max_members,capability_status FROM asp_competition_type WHERE status='active' ORDER BY sport_id,min_members")));return R.ok(n);}
    public Optional<Long> supported(Long sportId,String entryType,Integer min,Integer max){var row=db.one("SELECT id FROM asp_competition_type WHERE sport_id=? AND entry_type=? AND min_members=? AND max_members=? AND status='active' AND capability_status='manual'",sportId,entryType,min,max);return row==null?Optional.empty():Optional.of(number(row.get("id")));}
}
