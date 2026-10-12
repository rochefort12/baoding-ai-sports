package org.dromara.sports.tables.d10.honor;
import com.fasterxml.jackson.databind.*;
import com.fasterxml.jackson.databind.node.*;
import lombok.RequiredArgsConstructor;
import org.dromara.sports.api.*;
import org.dromara.sports.platform.core.*;
import org.springframework.stereotype.Service;
import org.springframework.web.bind.annotation.*;
import org.dromara.common.core.domain.R;
import cn.dev33.satoken.annotation.SaCheckLogin;
import java.util.*;
import static org.dromara.sports.platform.core.BusinessSupport.*;

/** One continuing claim per placing/registration; special awards retain independent history.
 * Event lock serializes result corrections, initial award and reissue. No automatic ranking. */
@Service @RequiredArgsConstructor
public class HonorRevisionService implements CapabilityProvider {
 private final ScopedJdbc db; private final ObjectMapper json;
 private final OrganizationSessionApi organizations; private final OrganizationQualificationApi qualifications;
 private static final Set<String> READS=Set.of("asp_honor","asp_event","asp_registration","asp_competition_unit","asp_stage","asp_match","asp_match_entry","asp_result_version","asp_roster_version","asp_roster_member","asp_account","asp_organization","asp_staff_grant","asp_account_tenant_principal");
 private static final Set<String> REVIEW=Set.of("verified","pending","suspended","revised");
 public List<CapabilityDefinition> capabilities(){return List.of(capability(json,"honor.resolve","核实赛事奖项并保留证明历史","asp_honor",false,true,Set.of("organizer"),"",READS,Set.of("asp_honor","asp_notification","asp_event"),"honorId","expectedVersion","decision","reason","title?","basisFingerprint?"));}
 private void owned(long event){var o=organizations.managedOrganization(BusinessIdentity.getUserId()).orElseThrow(()->fail("请进入主办方工作台",403));if(!qualifications.hasStaffAction(o.tenantId(),o.organizationId(),o.accountId(),"organize")||db.count("SELECT count(*) FROM asp_event WHERE id=? AND organization_id=? AND tenant_id=?",event,o.organizationId(),o.tenantId())==0)throw fail("证明不在当前岗位的赛事范围",403);}
 private Map<String,Object> load(long id){var h=db.one("SELECT *,source::text AS source_text FROM asp_honor WHERE id=? AND category='event'",id);if(h==null)throw fail("获奖证明不存在",404);owned(number(h.get("event_id")));return h;}
 private ObjectNode source(Map<String,Object> row){try{var n=json.readTree(row.get("source_text").toString());if(n instanceof ObjectNode o)return o;}catch(Exception ignored){}throw fail("原获奖依据无法读取，请联系平台核对",409);}
 private EventAwardLineage.Claim claim(Map<String,Object> r){return new EventAwardLineage.Claim(number(r.get("id")),number(r.get("registration_id")),number(r.get("person_id")),r.get("award_key").toString(),r.get("title").toString(),source(r),r.get("status").toString());}
 private List<Map<String,Object>> rows(long event){return db.list("SELECT *,source::text AS source_text FROM asp_honor WHERE event_id=? AND category='event' AND award_key IS NOT NULL ORDER BY id",event);}
 private List<Map<String,Object>> group(Map<String,Object> h,List<Map<String,Object>> rows){var claims=rows.stream().map(this::claim).toList();String key=EventAwardLineage.key(claim(h),claims);return rows.stream().filter(r->EventAwardLineage.key(claim(r),claims).equals(key)).toList();}
 private ArrayNode basis(Map<String,Object> h){
  var src=source(h);boolean placing=EventAwardLineage.kind(claim(h),rows(number(h.get("event_id"))).stream().map(this::claim).toList()).equals("placing");
  var results=db.list("SELECT m.id AS match_id,m.code,u.name AS unit_name,(SELECT string_agg(rm.person_snapshot->>'legalName','、' ORDER BY rm.id) FROM asp_match_entry me JOIN asp_roster_member rm ON rm.roster_version_id=me.roster_version_id WHERE me.match_id=m.id AND me.slot='A') AS side_a,(SELECT string_agg(rm.person_snapshot->>'legalName','、' ORDER BY rm.id) FROM asp_match_entry me JOIN asp_roster_member rm ON rm.roster_version_id=me.roster_version_id WHERE me.match_id=m.id AND me.slot='B') AS side_b,v.id AS result_id,v.revision,v.status,v.raw_performance::text AS performance FROM asp_match m JOIN asp_stage s ON s.id=m.stage_id JOIN asp_competition_unit u ON u.id=s.unit_id LEFT JOIN LATERAL(SELECT * FROM asp_result_version WHERE match_id=m.id AND status IN('confirmed','void') ORDER BY revision DESC LIMIT 1) v ON true WHERE u.event_id=? AND u.id=? AND m.status<>'cancelled' ORDER BY m.id",h.get("event_id"),src.path("unitId").asLong());
  ArrayNode out=json.createArrayNode();Set<Long> selected=new HashSet<>();for(JsonNode r:src.path("basisResults"))selected.add(r.path("matchId").asLong());
  for(var r:results){long match=number(r.get("match_id"));if(!placing&&(src.has("basisResults")?!selected.contains(match):db.count("SELECT count(*) FROM asp_match_entry WHERE match_id=? AND registration_id=?",match,h.get("registration_id"))==0))continue;
   var n=out.addObject().put("matchId",String.valueOf(match)).put("code",r.get("code").toString()).put("resultId",Objects.toString(r.get("result_id"),"")).put("revision",r.get("revision")==null?0:number(r.get("revision"))).put("status",Objects.toString(r.get("status"),"missing")).put("unitName",Objects.toString(r.get("unit_name"),"项目待核对")).put("sideA",Objects.toString(r.get("side_a"),"A 方参赛者")).put("sideB",Objects.toString(r.get("side_b"),"B 方参赛者"));
   try{n.set("performance",json.readTree(Objects.toString(r.get("performance"),"{}")));}catch(Exception e){throw fail("正式结果无法读取",409);}
  }
  if(!placing&&src.has("basisResults"))for(long m:selected)if(out.findValuesAsText("matchId").stream().noneMatch(id->id.equals(String.valueOf(m))))out.addObject().put("matchId",String.valueOf(m)).put("resultId","").put("revision",0).put("status","missing");
  return out;
 }
 public JsonNode pending(long event){return pending(event,false);}
 public JsonNode pending(long event,boolean includeVerified){
  owned(event);var rows=rows(event);var claims=rows.stream().map(this::claim).toList();Set<Long> latest=new HashSet<>(EventAwardLineage.latest(claims).stream().map(EventAwardLineage.Claim::id).toList());Map<String,Map<String,Object>> representatives=new LinkedHashMap<>();
  for(var r:rows)if(latest.contains(number(r.get("id")))&&REVIEW.contains(r.get("status")))representatives.merge(EventAwardLineage.key(claim(r),claims),r,(a,b)->number(a.get("id"))>number(b.get("id"))?a:b);
  ArrayNode out=json.createArrayNode();
  for(var h:representatives.values()){
   var group=group(h,rows);var current=group.stream().filter(r->latest.contains(number(r.get("id")))).toList();boolean pending=current.stream().anyMatch(r->!"verified".equals(r.get("status")));if(!includeVerified&&!pending)continue;
   var n=out.addObject().put("id",h.get("id").toString()).put("registration_id",h.get("registration_id").toString()).put("title",h.get("title").toString()).put("version",number(h.get("version"))).put("people_count",current.size()).put("history_count",group.size()-current.size()).put("status",pending?"suspended":"verified").put("award_kind",EventAwardLineage.kind(claim(h),claims)).put("basis_text",source(h).path("basis").asText());
   var unit=db.one("SELECT name FROM asp_competition_unit WHERE id=?",source(h).path("unitId").asLong());n.put("unit_name",unit==null?"项目待核对":Objects.toString(unit.get("name"),""));
   var names=db.list("SELECT rm.person_snapshot->>'legalName' AS name FROM asp_roster_member rm WHERE rm.roster_version_id=? ORDER BY rm.id",source(h).path("rosterVersionId").asLong());n.put("names",String.join("、",names.stream().map(r->Objects.toString(r.get("name"),"名单待核对")).toList()));
   var basis=basis(h);n.set("basis_results",basis);n.put("basis_fingerprint",EventAwardLineage.fingerprint(basis));
  }return out;
 }
 public JsonNode preview(String code,JsonNode in){var h=load(id(in,"honorId"));var out=json.createObjectNode();out.set("claim",safeJson(json,group(h,rows(number(h.get("event_id"))))));var basis=basis(h);out.set("basisResults",basis);out.put("basisFingerprint",EventAwardLineage.fingerprint(basis));return out;}
 public JsonNode execute(String code,JsonNode in){
  if(TrustedRunContext.current()!=null)throw fail("获奖依据须由责任人本人核实",403);var h=load(id(in,"honorId"));long event=number(h.get("event_id"));db.lock("event-fixtures:"+event);h=load(id(in,"honorId"));var all=rows(event);var claims=all.stream().map(this::claim).toList();
  if(number(h.get("version"))!=in.path("expectedVersion").asLong(-1)||!REVIEW.contains(h.get("status"))||EventAwardLineage.latest(claims).stream().noneMatch(c->c.id()==id(in,"honorId")))throw fail("证明状态已变化，请重新核对",409);
  String decision=text(in,"decision",16),reason=text(in,"reason",2000);if(!Set.of("reissue","revoke").contains(decision))throw fail("请选择重新签发或撤销",400);String title=decision.equals("reissue")?text(in,"title",200):h.get("title").toString();if(title.contains("运动员等级")||title.contains("官方认证"))throw fail("称号只写这场赛事里的名次或奖项",400);var basis=basis(h);
  if(decision.equals("reissue")){
   if(db.count("SELECT count(*) FROM asp_event WHERE id=? AND holding_status='normal'",event)==0)throw fail("取消赛事只保留历史证明，不再重新签发",409);
   if(basis.isEmpty()||java.util.stream.StreamSupport.stream(basis.spliterator(),false).anyMatch(r->!"confirmed".equals(r.path("status").asText())))throw fail("获奖依据中的场次缺少有效正式结果，请先核实赛果",409);
   if(!EventAwardLineage.fingerprint(basis).equals(in.path("basisFingerprint").asText()))throw fail("获奖依据已变化，请刷新并重新核对正式结果",409);
  }
  var group=group(h,all);Set<Long> latest=new HashSet<>(EventAwardLineage.latest(group.stream().map(this::claim).toList()).stream().map(EventAwardLineage.Claim::id).toList());String award=UUID.randomUUID().toString().replace("-","");long first=0;String kind=EventAwardLineage.kind(claim(h),claims),root=kind.equals("special")?EventAwardLineage.key(claim(h),claims).substring(("special:"+h.get("registration_id")+":").length()):source(h).path("awardRootKey").asText(h.get("award_key").toString());
  for(var old:group)if(REVIEW.contains(old.get("status"))){var archived=source(old).deepCopy();archived.put("revocationReason",reason).put("reviewDecision",decision);if(decision.equals("reissue"))archived.put("replacedByAwardKey",award);db.update("UPDATE asp_honor SET status='revoked',source=?::jsonb,version=version+1,update_time=CURRENT_TIMESTAMP WHERE id=?",archived.toString(),old.get("id"));}
  for(var old:group)if(latest.contains(number(old.get("id")))&&REVIEW.contains(old.get("status"))){
   if(decision.equals("reissue")){var src=source(old).deepCopy();src.remove(List.of("revocationReason","reviewDecision","replacedByAwardKey","reviewMatchId","reviewResultId"));src.put("awardKey",award).put("awardRootKey",root).put("awardKind",kind).put("basisScope",kind.equals("placing")?"unit":"matches").put("previousHonorId",old.get("id").toString()).put("correctionReason",reason).put("basis",reason);src.set("basisResults",basis.deepCopy());long newId=nextId();if(first==0)first=newId;db.update("INSERT INTO asp_honor(id,tenant_id,event_id,registration_id,person_id,team_id,award_key,category,title,source,status,awarded_at) VALUES (?,?,?,?,?,?,?,'event',?,?::jsonb,'verified',CURRENT_TIMESTAMP)",newId,old.get("tenant_id"),event,old.get("registration_id"),old.get("person_id"),old.get("team_id"),award,title,src.toString());}
   var a=db.one("SELECT id FROM asp_account WHERE person_id=? AND status='active'",old.get("person_id"));if(a!=null){var content=json.createObjectNode().put("title",decision.equals("reissue")?"获奖证明已重新核实":"原获奖证明已撤销").put("body",reason).put("target","/portal/proofs");db.update("INSERT INTO asp_notification(id,tenant_id,recipient_account_id,business_type,business_id,business_revision,purpose,content,dedupe_key) VALUES (?,?,?,'honor',?,?,'proof-review',?::jsonb,?)",nextId(),old.get("tenant_id"),a.get("id"),old.get("id"),number(old.get("version"))+1,content.toString(),"honor-review:"+old.get("id")+":"+(number(old.get("version"))+1));}
  }
  db.update("UPDATE asp_event SET closure_status='wrap_up',version=version+1,update_time=CURRENT_TIMESTAMP WHERE id=? AND closure_status='closed'",event);
  return reference(json,"honorId",first==0?id(in,"honorId"):first,decision.equals("reissue")?"verified":"revoked");
 }
 @RestController @SaCheckLogin @RequiredArgsConstructor @RequestMapping("/sports/proof-review")
 public static class Controller{private final HonorRevisionService service;@GetMapping("/events/{id}")public R<JsonNode> pending(@PathVariable long id,@RequestParam(defaultValue="false")boolean includeVerified){return R.ok(service.pending(id,includeVerified));}}
}




