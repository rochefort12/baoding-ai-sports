package org.dromara.sports.tables.d04.competition_unit;
import com.fasterxml.jackson.databind.*;
import lombok.RequiredArgsConstructor;
import org.dromara.sports.api.*;
import org.dromara.sports.platform.core.*;
import org.springframework.stereotype.Service;
import java.math.BigDecimal;
import java.util.*;
import static org.dromara.sports.platform.core.BusinessSupport.*;
@Service @RequiredArgsConstructor
public class UnitActions implements CapabilityProvider {
 private final ScopedJdbc db;private final ObjectMapper json;private final EventRegistrationApi events;private final UnitMutationApi units;
 public List<CapabilityDefinition> capabilities(){return List.of(capability(json,"unit.create","按比赛类型创建项目、名额和初始费用","asp_competition_unit",true,true,Set.of("organizer"),"",Set.of("asp_event","asp_competition_type","asp_competition_unit","asp_sport","asp_capacity_pool","asp_fee_policy","asp_idempotency","asp_event_payment_config","asp_file"),Set.of("asp_competition_unit","asp_capacity_pool","asp_fee_policy","asp_idempotency"),"eventId","competitionTypeId","name","limitCount","charged","amount?","paymentMode?","payInstruction?","qrFileId?"));}
 public JsonNode preview(String code,JsonNode in){long event=id(in,"eventId");events.managedGate(event).orElseThrow(()->fail("赛事不在当前组织范围",403));var n=json.createObjectNode();n.set("event",safeJson(json,db.one("SELECT id,name,version,closure_status FROM asp_event WHERE id=?",event)));n.set("type",safeJson(json,type(id(in,"competitionTypeId"))));n.set("input",in);return n;}
 private Map<String,Object> type(long type){var t=db.one("SELECT id,name,entry_type,min_members,max_members,sport_id FROM asp_competition_type WHERE id=? AND status='active' AND capability_status='manual'",type);if(t==null)throw fail("该比赛类型尚未开放",409);return t;}
 public JsonNode execute(String code,JsonNode in){var t=type(id(in,"competitionTypeId"));int limit;try{limit=Integer.parseInt(text(in,"limitCount",8));}catch(Exception e){throw fail("请填写有效报名名额",400);}if(limit<1||limit>100000)throw fail("报名名额须为1至100000",400);boolean charged=in.path("charged").asBoolean();BigDecimal amount;try{amount=charged?new BigDecimal(text(in,"amount",24)).setScale(2,java.math.RoundingMode.UNNECESSARY):BigDecimal.ZERO;}catch(Exception e){throw fail("费用须为最多两位小数的人民币金额",400);}long unit=units.create(id(in,"eventId"),text(in,"name",200),t.get("entry_type").toString(),(int)number(t.get("min_members")),(int)number(t.get("max_members")),limit,ActionContext.current().requestKey(),charged,amount,charged?text(in,"paymentMode",32):"free",in.path("payInstruction").asText(""),optionalId(in,"qrFileId"));return reference(json,"unitId",unit,"open");}
}
