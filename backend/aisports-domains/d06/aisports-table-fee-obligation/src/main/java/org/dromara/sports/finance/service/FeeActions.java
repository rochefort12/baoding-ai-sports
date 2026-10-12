package org.dromara.sports.finance.service;
import com.fasterxml.jackson.databind.*;
import lombok.RequiredArgsConstructor;
import org.dromara.sports.api.EventRegistrationApi;
import org.dromara.sports.platform.core.*;
import org.springframework.stereotype.Service;
import java.math.BigDecimal;
import java.util.*;
import static org.dromara.sports.platform.core.BusinessSupport.*;
@Service @RequiredArgsConstructor
public class FeeActions implements CapabilityProvider {
 private final FinanceService finance;private final ScopedJdbc db;private final ObjectMapper json;private final EventRegistrationApi events;
 public List<CapabilityDefinition> capabilities(){return List.of(capability(json,"fee.units","核对赛事各项目费用与收款指引","asp_fee_obligation",true,false,Set.of("organizer"),"",Set.of("asp_competition_unit","asp_fee_policy","asp_event","asp_event_payment_config"),Set.of(),"eventId"),capability(json,"fee.configure","核对后更新未冻结项目收费版本","asp_fee_obligation",true,true,Set.of("organizer"),"",Set.of("asp_competition_unit","asp_fee_policy","asp_event","asp_event_payment_config","asp_file"),Set.of("asp_fee_policy"),"unitId","expectedVersion","amount","paymentMode","payInstruction?","qrFileId?"));}
 private Map<String,Object> owned(long unit){var u=db.one("SELECT id,event_id,version FROM asp_competition_unit WHERE id=?",unit);if(u==null)throw fail("项目不存在",404);events.managedGate(number(u.get("event_id"))).orElseThrow(()->fail("项目不在当前组织范围",403));return u;}
 public JsonNode preview(String code,JsonNode in){if(in.has("eventId"))return json.valueToTree(finance.units(id(in,"eventId")));var u=owned(id(in,"unitId"));var n=json.createObjectNode();n.set("unit",safeJson(json,u));n.set("policy",safeJson(json,db.one("SELECT revision,amount,payment_mode,pay_instruction,qr_file_id FROM asp_fee_policy WHERE unit_id=? AND status='active'",id(in,"unitId"))));n.set("fees",json.valueToTree(finance.units(number(u.get("event_id")))));return n;}
 public JsonNode execute(String code,JsonNode in){if(code.equals("fee.units"))return preview(code,in);long unit=id(in,"unitId");db.lock("fee-policy:"+unit);var u=owned(unit);var active=db.one("SELECT revision FROM asp_fee_policy WHERE unit_id=? AND status='active'",unit);if(active==null||number(active.get("revision"))!=in.path("expectedVersion").asLong(-1))throw fail("收费版本已变化，请重新核对",409);if(!events.acceptsNewBusiness(number(u.get("event_id"))))throw fail("赛事进入收尾或资格暂停后不再修改新增收费",409);BigDecimal amount;try{amount=new BigDecimal(text(in,"amount",24));}catch(Exception e){throw fail("请填写有效人民币金额",400);}finance.publish(unit,amount,text(in,"paymentMode",32),in.path("payInstruction").asText(""),optionalId(in,"qrFileId"));return reference(json,"unitId",unit,"configured");}
}
