package org.dromara.sports.tables.d10.honor;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import lombok.RequiredArgsConstructor;
import org.dromara.sports.api.HonorDisplayApi;
import org.dromara.sports.api.StoredObjectApi;
import org.dromara.sports.platform.core.*;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.ObjectProvider;
import java.time.OffsetDateTime;
import java.util.*;
import static org.dromara.sports.platform.core.BusinessSupport.*;

/** Manual external award certification. No path in this service changes results or growth points. */
@Service @RequiredArgsConstructor
public class HonorCertificationService implements CapabilityProvider, HonorDisplayApi {
    private final ScopedJdbc db;
    private final ObjectMapper json;
    private final StoredObjectApi objects;
    // Resolve lazily: the dispatcher itself discovers all providers through the registry.
    private final ObjectProvider<ActionDispatcher> actions;
    private static final Set<String> READS=Set.of("asp_honor","asp_account","asp_person","asp_sport","asp_file","asp_profile_display");
    private static final String SELECT="SELECT h.*,h.certification_details::text AS details_text,h.verified_snapshot::text AS verified_text,h.certification_history::text AS history_text FROM asp_honor h WHERE h.id=? AND h.certification_status IS NOT NULL";
    public List<CapabilityDefinition> capabilities() {
        Set<String> own=Set.of("platform"),write=Set.of("asp_honor","asp_audit_event");
        return List.of(
            capability(json,"honor.certification.save","保存本人荣誉认证申请","asp_honor",false,false,own,"",READS,write,"honorId?","expectedVersion","detailsJson"),
            capability(json,"honor.certification.submit","提交本人荣誉认证材料","asp_honor",false,true,own,"",READS,write,"honorId","expectedVersion"),
            capability(json,"honor.certification.review","核实外部荣誉认证","asp_honor",false,true,Set.of("admin"),"sports:platform:manage",READS,Set.of("asp_honor","asp_audit_event","asp_notification"),"honorId","expectedVersion","decision","reason","verifiedDetailsJson?","expectedPersonVersion?"),
            capability(json,"honor.certification.wear","佩戴本人已认证荣誉","asp_honor",false,false,own,"",READS,write,"honorId","expectedVersion","ready"),
            capability(json,"honor.certification.visibility","设置本人认证荣誉公开范围","asp_honor",false,false,own,"",READS,write,"honorId","expectedVersion","publicVisible"),
            capability(json,"honor.certification.proof.upload","上传本人荣誉认证证明","asp_honor",false,false,own,"",READS,Set.of("asp_honor","asp_file","asp_audit_event"),"honorId","expectedVersion")
        );
    }
    private static void manual() {if(TrustedRunContext.current()!=null)throw fail("荣誉认证须由本人或平台责任人办理",403);}
    private long owner() {manual();long a=account();if(db.count("SELECT count(*) FROM asp_account WHERE id=? AND status='active'",a)!=1)throw fail("当前账号不可办理荣誉认证",403);return a;}
    private static void reviewer() {manual();if(!BusinessIdentity.isSuperAdmin())throw fail("仅平台负责人可以核实外部荣誉认证",403);}
    private Map<String,Object> load(long id,boolean lock) {
        var row=db.one(SELECT+(lock?" FOR UPDATE":""),id);
        if(row==null)throw fail("认证申请不存在",404);return row;
    }
    private Map<String,Object> owned(long id,boolean lock) {long a=owner();var h=load(id,lock);if(number(h.get("applicant_account_id"))!=a)throw fail("只能办理本人的认证申请",403);return h;}
    private void version(Map<String,Object> h,JsonNode in) {if(!in.path("expectedVersion").canConvertToInt()||in.path("expectedVersion").asInt(-1)<0||number(h.get("version"))!=in.path("expectedVersion").asInt())throw fail("认证申请已变化，请刷新后重新核对",409);}
    private ObjectNode details(Map<String,Object> h) {return parseObject(h,"details_text");}
    private ObjectNode parseObject(Map<String,Object> h,String key) {try{return (ObjectNode)json.readTree(String.valueOf(h.get(key)));}catch(Exception e){throw fail("认证历史无法读取，请联系平台",409);}}
    private ArrayNode history(Map<String,Object> h) {try{return (ArrayNode)json.readTree(String.valueOf(h.get("history_text")));}catch(Exception e){throw fail("认证历史无法读取，请联系平台",409);}}
    private Map<String,Object> sport(long id) {var s=db.one("SELECT id,name FROM asp_sport WHERE id=? AND status='active'",id);if(s==null)throw fail("请选择有效的运动项目",400);return s;}
    private void proofs(ObjectNode claim,long a,boolean required) {
        if(required&&claim.path("proofFileIds").isEmpty())throw fail("请上传至少一份能核对赛事、本人和名次的证明",400);
        for(var f:claim.path("proofFileIds"))if(db.count("SELECT count(*) FROM asp_file WHERE id=? AND owner_account_id=? AND owning_tenant_id='000000' AND purpose='honor-proof' AND status='active'",f.asLong(),a)!=1)throw fail("证明材料归属或用途不正确，请重新上传",403);
    }
    public JsonNode mine() {long a=owner();var out=json.createArrayNode();for(var h:db.list("SELECT h.*,h.certification_details::text AS details_text,h.verified_snapshot::text AS verified_text,h.certification_history::text AS history_text FROM asp_honor h WHERE h.applicant_account_id=? AND h.certification_status IS NOT NULL ORDER BY h.update_time DESC,h.id DESC",a))out.add(view(h));return out;}
    public JsonNode detail(long id) {manual();var h=BusinessIdentity.isSuperAdmin()?load(id,false):owned(id,false);return view(h);}
    public JsonNode queue(String state) {reviewer();if(state!=null&&!state.isBlank()&&!Set.of("submitted","correction","approved","rejected","revoked","draft").contains(state))throw fail("认证状态无效",400);var out=json.createArrayNode();for(var h:db.list("SELECT h.*,h.certification_details::text AS details_text,h.verified_snapshot::text AS verified_text,h.certification_history::text AS history_text,d.nickname FROM asp_honor h LEFT JOIN asp_profile_display d ON d.account_id=h.applicant_account_id WHERE h.certification_status IS NOT NULL AND (?='' OR h.certification_status=?) ORDER BY h.update_time DESC,h.id DESC LIMIT 200",state==null?"":state,state==null?"":state))out.add(view(h));return out;}
    private ObjectNode view(Map<String,Object> h) {
        var n=json.createObjectNode();n.put("honorId",h.get("id").toString());n.put("title",String.valueOf(h.get("title")));n.put("status",String.valueOf(h.get("certification_status")));n.put("version",number(h.get("version")));n.put("publicVisible",Boolean.TRUE.equals(h.get("certification_public")));n.put("worn",Boolean.TRUE.equals(h.get("certification_worn")));n.put("nickname",Objects.toString(h.get("nickname"),"申请人"));n.set("details",details(h));n.set("verified",parseObject(h,"verified_text"));n.set("history",history(h));n.set("applicantIdentity",identity(h));return n;
    }
    /** Only owner/reviewer detail and confirmation previews call this; it never enters public DTOs or Agent context. */
    private ObjectNode identity(Map<String,Object> h) {return identity(h,false);}
    private ObjectNode identity(Map<String,Object> h,boolean lock) {
        var person=db.one("SELECT p.id,p.legal_name,p.id_doc_type,p.verification_status,p.status AS person_status,p.version,EXTRACT(YEAR FROM p.birth_date)::integer AS birth_year,(p.identity_hash IS NOT NULL) AS has_identity_document,a.status AS account_status FROM asp_account a JOIN asp_person p ON p.id=a.person_id WHERE a.id=? AND p.id=?"+(lock?" FOR UPDATE OF p,a":""),h.get("applicant_account_id"),h.get("person_id"));
        if(person==null)throw fail("申请人与本人档案绑定已变化，请先核对身份",409);
        var n=json.createObjectNode().put("accountId",h.get("applicant_account_id").toString()).put("personId",person.get("id").toString()).put("legalName",String.valueOf(person.get("legal_name"))).put("personVersion",number(person.get("version"))).put("hasIdentityDocument",Boolean.TRUE.equals(person.get("has_identity_document"))).put("profileVerificationStatus",String.valueOf(person.get("verification_status"))).put("personStatus",String.valueOf(person.get("person_status"))).put("accountStatus",String.valueOf(person.get("account_status")));
        if(person.get("birth_year")!=null)n.put("birthYear",number(person.get("birth_year")));if(person.get("id_doc_type")!=null)n.put("documentType",person.get("id_doc_type").toString());return n;
    }
    private void identityVersion(ObjectNode bound,JsonNode in) {if(!Long.toString(bound.path("personVersion").asLong()).equals(in.path("expectedPersonVersion").asText()))throw fail("本人档案已变化，请重新核对归属后确认",409);}
    public JsonNode preview(String code,JsonNode in) {
        manual();
        if(code.equals("honor.certification.save")) {
            long a=owner();var d=HonorCertificationRules.claim(json,text(in,"detailsJson",6000));sport(id(d,"sportId"));proofs(d,a,false);
            var n=json.createObjectNode();if(in.hasNonNull("honorId")){var h=owned(id(in,"honorId"),false);version(h,in);HonorCertificationRules.editable(h.get("certification_status").toString());n.set("current",view(h));}else if(in.path("expectedVersion").asInt(-1)!=0)throw fail("新申请的版本应为0",409);n.set("proposed",d);return n;
        }
        var h=code.equals("honor.certification.review")?reviewLoad(id(in,"honorId"),false):owned(id(in,"honorId"),false);version(h,in);
        var n=view(h);if(code.equals("honor.certification.review")){String decision=text(in,"decision",16);checkReview(h,decision);HonorCertificationRules.plain(in,"reason",2000);if(decision.equals("approve")){identityVersion((ObjectNode)n.path("applicantIdentity"),in);var v=verifiedInput(in);n.set("confirmedFacts",v);n.put("derivedTitle",HonorCertificationRules.title(v,sport(id(v,"sportId")).get("name").toString()));}}
        else if(code.equals("honor.certification.submit")){HonorCertificationRules.editable(h.get("certification_status").toString());proofs(details(h),number(h.get("applicant_account_id")),true);}
        else if(code.equals("honor.certification.wear")||code.equals("honor.certification.visibility"))HonorCertificationRules.wearable(h.get("certification_status").toString(),h.get("status").toString());
        else if(code.equals("honor.certification.proof.upload"))HonorCertificationRules.editable(h.get("certification_status").toString());
        else throw fail("认证动作不存在",404);
        return n;
    }
    public JsonNode execute(String code,JsonNode in) {
        manual();return switch(code){
            case "honor.certification.save" -> save(in);
            case "honor.certification.submit" -> submit(in);
            case "honor.certification.review" -> review(in);
            case "honor.certification.wear" -> wear(in);
            case "honor.certification.visibility" -> visibility(in);
            case "honor.certification.proof.upload" -> throw fail("请使用认证申请中的证明上传入口",400);
            default -> throw fail("认证动作不存在",404);
        };
    }
    private JsonNode save(JsonNode in) {
        long a=owner();var d=HonorCertificationRules.claim(json,text(in,"detailsJson",6000));var s=sport(id(d,"sportId"));proofs(d,a,false);
        Long honor=optionalId(in,"honorId");long v;
        if(honor==null) {
            if(in.path("expectedVersion").asInt(-1)!=0)throw fail("新申请的版本应为0",409);
            var person=db.one("SELECT person_id FROM asp_account WHERE id=? AND status='active'",a);if(person==null||person.get("person_id")==null)throw fail("请先完善本人参赛档案",409);
            honor=nextId();v=0;var source=json.createObjectNode().put("kind","external-certification").put("awardDatePrecision","year").put("createdAt",OffsetDateTime.now().toString());
            db.update("INSERT INTO asp_honor(id,tenant_id,person_id,category,title,source,status,awarded_at,sport_id,applicant_account_id,certification_status,certification_details) VALUES (?,'000000',?,'self_reported',?,?::jsonb,'pending',CURRENT_TIMESTAMP,?,?,'draft',?::jsonb)",honor,person.get("person_id"),"待认证 · "+d.path("eventName").asText(),source.toString(),s.get("id"),a,d.toString());
        } else {
            var h=owned(honor,true);version(h,in);HonorCertificationRules.editable(h.get("certification_status").toString());v=number(h.get("version"))+1;
            var hist=append(h,"draft_saved","",details(h),null);
            db.update("UPDATE asp_honor SET title=?,sport_id=?,certification_status='draft',certification_details=?::jsonb,certification_history=?::jsonb,version=version+1,update_time=CURRENT_TIMESTAMP WHERE id=?", "待认证 · "+d.path("eventName").asText(),s.get("id"),d.toString(),hist.toString(),honor);
        }
        audit(honor,a,"certification.save",v,null);return receipt(honor,"draft",v);
    }
    private JsonNode submit(JsonNode in) {
        var h=owned(id(in,"honorId"),true);version(h,in);HonorCertificationRules.editable(h.get("certification_status").toString());var d=HonorCertificationRules.claim(json,details(h).toString());sport(id(d,"sportId"));proofs(d,number(h.get("applicant_account_id")),true);
        var hist=append(h,"submitted","",d,null);long v=number(h.get("version"))+1;
        db.update("UPDATE asp_honor SET certification_status='submitted',certification_history=?::jsonb,version=version+1,update_time=CURRENT_TIMESTAMP WHERE id=?",hist.toString(),h.get("id"));audit(number(h.get("id")),number(h.get("applicant_account_id")),"certification.submit",v,null);return receipt(number(h.get("id")),"submitted",v);
    }
    private Map<String,Object> reviewLoad(long id,boolean lock) {reviewer();return load(id,lock);}
    private static void checkReview(Map<String,Object> h,String decision) {
        String state=h.get("certification_status").toString();
        if((decision.equals("revoke")&&state.equals("approved"))||(Set.of("approve","correction","reject").contains(decision)&&state.equals("submitted")))return;
        throw fail("该状态不可作此审核决定，请刷新后核对",409);
    }
    private ObjectNode verifiedInput(JsonNode in) {return HonorCertificationRules.verified(json,text(in,"verifiedDetailsJson",6000));}
    private JsonNode review(JsonNode in) {
        var h=reviewLoad(id(in,"honorId"),true);version(h,in);String decision=text(in,"decision",16),reason=HonorCertificationRules.plain(in,"reason",2000);checkReview(h,decision);
        var snapshot=parseObject(h,"verified_text");String state= switch(decision){case "approve"->"approved";case "revoke"->"revoked";case "reject"->"rejected";default->"correction";};String status=decision.equals("approve")?"verified":decision.equals("revoke")?"revoked":"pending";String title=h.get("title").toString();Object sportId=h.get("sport_id");
        if(decision.equals("approve")) {
            var bound=identity(h,true);identityVersion(bound,in);if(!"active".equals(bound.path("personStatus").asText())||!"active".equals(bound.path("accountStatus").asText()))throw fail("申请人档案或账号当前不可认证",409);
            proofs(details(h),number(h.get("applicant_account_id")),true);snapshot=verifiedInput(in);var s=sport(id(snapshot,"sportId"));sportId=s.get("id");title=HonorCertificationRules.title(snapshot,s.get("name").toString());snapshot.put("sportName",s.get("name").toString());snapshot.put("reviewerUserId",BusinessIdentity.getUserIdStr());snapshot.put("verifiedAt",OffsetDateTime.now().toString());snapshot.set("applicantIdentity",bound);
        }
        var hist=append(h,state,reason,details(h),snapshot);long v=number(h.get("version"))+1;
        db.update("UPDATE asp_honor SET title=?,sport_id=?,status=?,certification_status=?,verified_snapshot=?::jsonb,certification_history=?::jsonb,certification_worn=false,certification_public=false,version=version+1,update_time=CURRENT_TIMESTAMP WHERE id=?",title,sportId,status,state,snapshot.toString(),hist.toString(),h.get("id"));
        audit(number(h.get("id")),null,"certification."+state,v,BusinessIdentity.getUserIdStr());
        var content=json.createObjectNode().put("title",switch(state){case "approved"->"荣誉认证已通过";case "correction"->"荣誉认证需要补充材料";case "revoked"->"荣誉认证已撤销";default->"荣誉认证未通过";}).put("body",reason).put("target","/portal/profile?tab=certification");
        db.update("INSERT INTO asp_notification(id,tenant_id,recipient_account_id,business_type,business_id,business_revision,purpose,content,dedupe_key) VALUES (?,'000000',?,'honor',?,?,'honor-certification',?::jsonb,?)",nextId(),h.get("applicant_account_id"),h.get("id"),v,content.toString(),"honor-certification:"+h.get("id")+":"+v);
        return receipt(number(h.get("id")),state,v);
    }
    private JsonNode wear(JsonNode in) {
        // Lock the per-sport slot before the row so concurrent equipment changes cannot deadlock each other.
        var initial=owned(id(in,"honorId"),false);db.lock("certified-honor:"+initial.get("person_id")+":"+initial.get("sport_id"));
        var h=owned(id(in,"honorId"),true);version(h,in);HonorCertificationRules.wearable(h.get("certification_status").toString(),h.get("status").toString());boolean ready=in.path("ready").asBoolean();
        if(ready)db.update("UPDATE asp_honor SET certification_worn=false,version=version+1,update_time=CURRENT_TIMESTAMP WHERE person_id=? AND sport_id=? AND certification_worn AND id<>?",h.get("person_id"),h.get("sport_id"),h.get("id"));
        db.update("UPDATE asp_honor SET certification_worn=?,version=version+1,update_time=CURRENT_TIMESTAMP WHERE id=?",ready,h.get("id"));long v=number(h.get("version"))+1;audit(number(h.get("id")),number(h.get("applicant_account_id")),"certification.wear",v,null);return receipt(number(h.get("id")),ready?"worn":"removed",v);
    }
    private JsonNode visibility(JsonNode in) {
        var h=owned(id(in,"honorId"),true);version(h,in);HonorCertificationRules.wearable(h.get("certification_status").toString(),h.get("status").toString());boolean visible=in.path("publicVisible").asBoolean();
        db.update("UPDATE asp_honor SET certification_public=?,version=version+1,update_time=CURRENT_TIMESTAMP WHERE id=?",visible,h.get("id"));long v=number(h.get("version"))+1;audit(number(h.get("id")),number(h.get("applicant_account_id")),"certification.visibility",v,null);return receipt(number(h.get("id")),visible?"public-consented":"private",v);
    }
    private ArrayNode append(Map<String,Object> h,String state,String reason,ObjectNode claim,ObjectNode verified) {
        var hist=history(h);var entry=json.createObjectNode().put("state",state).put("reason",reason).put("at",OffsetDateTime.now().toString()).put("previousVersion",number(h.get("version")));
        entry.set("details",claim.deepCopy());if(verified!=null)entry.set("verified",verified.deepCopy());hist.add(entry);return hist;
    }
    private void audit(long honor,Long actor,String action,long version,String reviewerId) {
        var summary=json.createObjectNode().put("version",version);if(reviewerId!=null)summary.put("reviewerUserId",reviewerId);
        db.update("INSERT INTO asp_audit_event(id,tenant_id,actor_account_id,action,object_type,object_id,request_id,occurred_at,summary) VALUES (?,'000000',?,?,'honor',?,?,CURRENT_TIMESTAMP,?::jsonb)",nextId(),actor,action,honor,UUID.randomUUID().toString(),summary.toString());
    }
    private ObjectNode receipt(long honor,String state,long version) {var n=reference(json,"honorId",honor,state);n.put("version",version);return n;}

    /** Multipart uses the executor's compatibility transaction, with its live UI gate and owner guard. */
    @SportsAction(value="honor.certification.proof.upload",title="上传本人荣誉认证证明",reads={"asp_honor","asp_account","asp_file"},writes={"asp_honor","asp_file","asp_audit_event"})
    public JsonNode upload(long honor,long expectedVersion,byte[] bytes) {
        var h=owned(honor,true);var in=json.createObjectNode().put("expectedVersion",expectedVersion);version(h,in);HonorCertificationRules.editable(h.get("certification_status").toString());
        if(actions.getObject().available().stream().noneMatch(c->c.code().equals("honor.certification.proof.upload")))throw fail("认证证明上传尚未开放",403);
        var d=details(h);if(d.path("proofFileIds").size()>=8)throw fail("最多保留8份证明，请在申请草稿中移除不需要的材料",400);
        if(bytes==null||bytes.length==0||bytes.length>5*1024*1024)throw fail("请选择不超过5MB的图片或PDF证明",400);
        long file=objects.keepHonorProof(number(h.get("applicant_account_id")),bytes);((ArrayNode)d.withArray("proofFileIds")).add(Long.toString(file));long v=number(h.get("version"))+1;
        db.update("UPDATE asp_honor SET certification_details=?::jsonb,version=version+1,update_time=CURRENT_TIMESTAMP WHERE id=?",d.toString(),honor);audit(honor,number(h.get("applicant_account_id")),"certification.proof.upload",v,null);var r=receipt(honor,h.get("certification_status").toString(),v);r.put("fileId",Long.toString(file));return r;
    }
    @SportsAction(value="honor.certification.proof.read",title="查看受控荣誉认证证明",reads={"asp_honor","asp_account","asp_file"},writes={"asp_audit_event"})
    public StoredObjectApi.DocumentBody proof(long honor,long file) {
        manual();boolean admin=BusinessIdentity.isSuperAdmin();var h=admin?load(honor,false):owned(honor,false);boolean attached=false;
        for(var f:details(h).path("proofFileIds"))if(f.asLong()==file)attached=true;
        for(var entry:history(h))for(var f:entry.path("details").path("proofFileIds"))if(f.asLong()==file)attached=true;
        if(!attached)throw fail("证明不在该认证申请的材料中",403);
        var body=objects.readHonorProof(file,number(h.get("applicant_account_id")));audit(honor,admin?null:number(h.get("applicant_account_id")),"certification.proof.read",number(h.get("version")),admin?BusinessIdentity.getUserIdStr():null);return body;
    }
    public List<CertifiedHonor> publicHonors(long a,Long sportId) {
        return display(a,sportId,true);
    }
    public List<CertifiedHonor> myHonors(Long sportId) {return display(owner(),sportId,false);}
    private List<CertifiedHonor> display(long a,Long sportId,boolean publicOnly) {
        List<CertifiedHonor> out=new ArrayList<>();
        for(var h:db.list("SELECT h.id,h.title,h.sport_id,h.certification_worn,h.certification_public,h.verified_snapshot::text AS verified_text FROM asp_honor h JOIN asp_account a ON a.id=h.applicant_account_id LEFT JOIN asp_profile_display d ON d.account_id=a.id WHERE a.id=? AND a.status='active' AND h.certification_status='approved' AND h.status='verified' AND (?::bigint IS NULL OR h.sport_id=?) AND (NOT ? OR (h.certification_public AND d.public_visible)) ORDER BY h.certification_worn DESC,h.id DESC",a,sportId,sportId,publicOnly)) {
            var v=parseObject(h,"verified_text");out.add(new CertifiedHonor(h.get("id").toString(),h.get("title").toString(),v.path("eventYear").asInt(),v.path("eventName").asText(),h.get("sport_id").toString(),v.path("sportName").asText(),v.path("place").asInt(),Boolean.TRUE.equals(h.get("certification_worn")),Boolean.TRUE.equals(h.get("certification_public"))));
        }return out;
    }
}
