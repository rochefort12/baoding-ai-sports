package org.dromara.sports.tables.d13.agent_run;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.api.AgentMaterialApi;
import org.dromara.sports.platform.core.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import jakarta.annotation.PreDestroy;
import java.net.URI;
import java.net.http.*;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import static org.dromara.sports.platform.core.BusinessSupport.*;

/** Durable visible conversation. A run token is private to the two local services and is never returned to a browser. */
@Service
@RequiredArgsConstructor
public class AgentRuns implements AgentRunAccess {
    private final JdbcTemplate db;
    private final ObjectMapper json;
    private final ActionDispatcher actions;
    private final OrganizationSessionApi organizations;
    private final AgentMaterialApi materials;
    private final PlatformTransactionManager transactions;
    @Value("${aisports.ai.internal-token:}") private String internalToken;
    @Value("${aisports.ai.gateway-url:http://127.0.0.1:8091}") private String gateway;
    @Value("${server.port:8080}") private int backendPort;
    private final ThreadPoolExecutor workers=new ThreadPoolExecutor(2,2,0,TimeUnit.SECONDS,new ArrayBlockingQueue<>(32),r->{var t=new Thread(r,"sports-agent-visible");t.setDaemon(true);return t;});
    @PreDestroy void close(){workers.shutdownNow();}
    /** The run pins its instruction/skill/map version; every entry is intersected with live role/channel metadata. */
    @Override public JsonNode playbook(){
        var principal=TrustedRunContext.current();if(principal==null)throw fail("请先开始本人授权的助手任务",403);
        var row=db.queryForMap("SELECT v.revision,v.tool_catalog::text,v.skill_catalog::text,v.business_map::text,v.playbook_hash FROM asp_agent_run r JOIN asp_agent_version v ON v.id=r.agent_version_id WHERE r.id=?",principal.runId());
        var stored=json.createObjectNode();stored.set("tools",parse(row.get("tool_catalog").toString()));stored.set("skills",parse(row.get("skill_catalog").toString()));stored.set("businessMap",parse(row.get("business_map").toString()));
        return AgentPlaybookRules.filter(json,stored,row.get("playbook_hash").toString(),((Number)row.get("revision")).longValue(),principal.actorType(),actions.guidance(),parse(principal.scopeJson()).path("context"));
    }
    private void visibleStep(long id,String kind,String name,String status,JsonNode summary){new TransactionTemplate(transactions).executeWithoutResult(tx->{db.queryForObject("SELECT pg_advisory_xact_lock(?)",Object.class,id);int sequence=db.queryForObject("SELECT COALESCE(MAX(sequence),0)+1 FROM asp_agent_step WHERE run_id=?",Integer.class,id);db.update("INSERT INTO asp_agent_step(id,run_id,sequence,kind,name,status,summary) VALUES(?,?,?,?,?,?,?::jsonb)",nextId(),id,sequence,kind,name,status,summary.toString());});}
    public JsonNode list(){long actor=LoginHelper.getUserId();return safeJson(json,db.queryForList("SELECT id,goal,status,stop_reason,create_time FROM asp_agent_run WHERE actor_id=? AND actor_type "+typePredicate()+" AND parent_run_id IS NULL ORDER BY create_time DESC LIMIT 20",actor));}
    private String typePredicate(){return LoginHelper.getUserType()==UserType.PLATFORM_USER?"='platform'":"<>'platform'";}
    private Map<String,Object> own(long id){var rows=db.queryForList("SELECT * FROM asp_agent_run WHERE id=? AND actor_id=? AND actor_type "+typePredicate(),id,LoginHelper.getUserId());if(rows.isEmpty())throw fail("找不到本人的助手进度",404);return rows.get(0);}
    public JsonNode detail(long id){own(id);var live=principal(id);db.update("UPDATE asp_agent_run SET status='failed',stop_reason='MODEL_TIMEOUT',token_hash='',version=version+1 WHERE id=? AND status='running' AND expires_at<CURRENT_TIMESTAMP",id);var r=own(id);var n=json.createObjectNode();n.put("id",Long.toString(id));n.put("goal",r.get("goal").toString());n.put("status",r.get("status").toString());var definition=db.queryForMap("SELECT revision,playbook_hash FROM asp_agent_version WHERE id=?",r.get("agent_version_id"));n.put("playbookVersion",((Number)definition.get("revision")).longValue());n.put("sourceHash",definition.get("playbook_hash").toString());if(r.get("stop_reason")!=null)n.put("stopReason",r.get("stop_reason").toString());n.set("messages",safeJson(json,db.queryForList("SELECT id,role,content,blocks::text,create_time FROM asp_agent_message WHERE run_id=? ORDER BY create_time,id",id)));n.set("steps",safeJson(json,db.queryForList("SELECT sequence,kind,name,status,summary::text,create_time FROM asp_agent_step WHERE run_id=? ORDER BY sequence",id)));if(scopeShrank(r,live)){for(var entry:n.path("messages"))if(entry.path("role").asText().equals("assistant")){((ObjectNode)entry).put("content","当前授权已变化，旧办理结果不再展示。");((ObjectNode)entry).put("blocks","[]");}for(var step:n.path("steps"))((ObjectNode)step).put("summary","{}");}n.set("children",safeJson(json,db.queryForList("SELECT id,goal,status,stop_reason FROM asp_agent_run WHERE parent_run_id=? ORDER BY create_time",id)));return n;}
    public JsonNode start(JsonNode in){return start(in,List.of());}
    public JsonNode start(JsonNode in,List<AgentMaterialApi.Upload> uploads){if(!in.path("consent").asBoolean())throw fail("请先确认本次资料将交由DeepSeek用于协助办理",400);String goal=text(in,"goal",2000);String agent=in.path("agentCode").asText("platform");String type;String tenant=null;Long org=null;long actor=LoginHelper.getUserId(),materialOwner=actor;if(LoginHelper.getUserType()==UserType.PLATFORM_USER)type="platform";else if(LoginHelper.isSuperAdmin())type="admin";else{var o=organizations.managedOrganization(actor);type=o.isPresent()?"organizer":"government";if(o.isPresent()){tenant=o.get().tenantId();org=o.get().organizationId();materialOwner=o.get().accountId();}}
        var caps=actions.available().stream().filter(CapabilityDefinition::agent).map(CapabilityDefinition::code).toList();var scope=json.createObjectNode();scope.set("capabilities",json.valueToTree(caps));if(tenant!=null)scope.put("tenantId",tenant);if(org!=null)scope.put("organizationId",org.toString());scope.put("consentVersion","deepseek-v4.1-20261010");scope.put("materialOwner",Long.toString(materialOwner));scope.put("materialTenant",tenant==null?"000000":tenant);var context=json.createObjectNode();for(String key:List.of("eventId","roomId","registrationId")){String value=in.path("context").path(key).asText("");if(!value.isBlank()){if(!value.matches("[1-9][0-9]{0,18}"))throw fail("页面对象编号无效，请刷新页面",400);context.put(key,value);}}scope.set("context",context);
        var retained=uploads.isEmpty()?List.<AgentMaterialApi.Material>of():materials.retain(materialOwner,scope.path("materialTenant").asText(),uploads);long id;
        try{id=new TransactionTemplate(transactions).execute(tx->{long run=create(agent,goal,type,actor,scope,null,null,0);if(!context.isEmpty()){var hint=json.createArrayNode();hint.addObject().put("kind","context");message(run,"user","当前页面对象仅为办理提示，仍须逐项核对权限与状态："+context,hint);}if(!retained.isEmpty())materialMessage(run,retained);return run;});}catch(RuntimeException error){discardMaterials(retained,scope);throw error;}
        launch(id);return reference(json,"runId",id,"running");}

    private long create(String agent,String goal,String type,long actor,JsonNode inherited,Long parent,Long root,int depth) {
        var versions=db.queryForList("SELECT v.id,v.budget::text,a.id AS agent_id FROM asp_agent a JOIN asp_agent_version v ON v.agent_id=a.id WHERE a.code=? AND a.status='active' AND v.status='active' ORDER BY v.revision DESC LIMIT 1",agent);
        if(versions.isEmpty())throw fail("该助手尚未开放",409);
        var scope=(ObjectNode)inherited.deepCopy();
        var budget=AgentBudget.read(parse(versions.get(0).get("budget").toString()));
        if(parent!=null)budget=budget.narrow(AgentBudget.read(scope.path("budget")));
        if(depth>budget.maxDepth())throw fail("委派层级已达上限",409);
        scope.set("budget",budget.json(json));scope.remove("childVersions");scope.remove("lastCapabilities");
        long id=nextId();
        db.update("INSERT INTO asp_agent_run(id,agent_version_id,actor_type,actor_id,parent_run_id,root_run_id,scope,goal,status,depth,tool_count,tokens_used,token_hash,expires_at,started_at) VALUES(?,?,?,?,?,?,?::jsonb,?,'running',?,0,0,'',CURRENT_TIMESTAMP+make_interval(secs=>?),CURRENT_TIMESTAMP)",id,versions.get(0).get("id"),type,actor,parent,root==null?id:root,scope.toString(),goal,depth,budget.activeSeconds());
        message(id,"user",goal,json.createArrayNode());
        message(id,"assistant","我先核对这次要办的事，再列出需要补充的内容和下一步。",json.createArrayNode().add(json.createObjectNode().put("kind","guidance").put("title","开始核对").put("summary","正在读取本次办理指引和当前身份可用的入口")));
        return id;
    }
    public JsonNode answer(long id,JsonNode in){own(id);principal(id);String content=text(in,"message",10000);int n=db.update("UPDATE asp_agent_run SET status='running',stop_reason=NULL,tool_count=0,version=version+1 WHERE id=? AND status IN('waiting_input','failed') AND tokens_reserved=0",id);if(n!=1)throw fail("请等待本轮完成，或先处理待确认内容",409);message(id,"user",content,json.createArrayNode());launch(id);return detail(id);}
    public JsonNode answer(long id,JsonNode in,List<AgentMaterialApi.Upload> uploads){var row=own(id);principal(id);if(!Set.of("waiting_input","failed").contains(row.get("status").toString()))throw fail("请先等待本轮完成或处理确认卡",409);String content=text(in,"message",10000);var scope=parse(row.get("scope").toString());if(!scope.has("materialOwner"))throw fail("旧会话请创建新目标后上传资料",409);var retained=materials.retain(Long.parseLong(scope.path("materialOwner").asText()),scope.path("materialTenant").asText(),uploads);try{new TransactionTemplate(transactions).executeWithoutResult(tx->{int count=db.update("UPDATE asp_agent_run SET status='running',stop_reason=NULL,tool_count=0,version=version+1 WHERE id=? AND status IN('waiting_input','failed') AND tokens_reserved=0",id);if(count!=1)throw fail("本轮进度已变化，请刷新后继续",409);message(id,"user",content,json.createArrayNode());materialMessage(id,retained);});}catch(RuntimeException error){discardMaterials(retained,scope);throw error;}launch(id);return detail(id);}
    private void discardMaterials(List<AgentMaterialApi.Material> values,JsonNode scope){for(var value:values)try{materials.discard(Long.parseLong(value.fileId()),Long.parseLong(scope.path("materialOwner").asText()),scope.path("materialTenant").asText());}catch(RuntimeException ignored){/* Retention processing must retain diagnostics; do not expose filenames or object keys. */}}
    private void materialMessage(long id,List<AgentMaterialApi.Material> values){var blocks=json.createArrayNode();for(var value:values){var block=json.createObjectNode().put("kind","material").put("fileId",value.fileId()).put("name",value.name()).put("format",value.kind()).put("sha256",value.sha256()).put("coverage",value.coverage());if(value.pageCount()!=null)block.put("pageCount",value.pageCount());block.set("locations",json.valueToTree(value.sources().stream().map(AgentMaterialApi.Source::location).toList()));blocks.add(block);}message(id,"user","已保存原始资料。下面列出识别位置和覆盖范围，缺项及冲突仍需本人核对。",blocks);}
    private JsonNode loadMaterials(long run,JsonNode scope){var result=json.createArrayNode();if(!scope.has("materialOwner"))return result;var rows=db.queryForList("WITH RECURSIVE ancestors AS (SELECT id,parent_run_id,0 AS depth FROM asp_agent_run WHERE id=? UNION ALL SELECT r.id,r.parent_run_id,a.depth+1 FROM asp_agent_run r JOIN ancestors a ON r.id=a.parent_run_id WHERE a.depth<3) SELECT m.blocks::text FROM asp_agent_message m JOIN ancestors a ON a.id=m.run_id WHERE m.blocks @> '[{\"kind\":\"material\"}]'::jsonb ORDER BY m.create_time DESC,m.id DESC LIMIT 4",run);var seen=new HashSet<String>();for(var row:rows)for(var block:parse(row.get("blocks").toString())){if(!block.path("kind").asText().equals("material")||!seen.add(block.path("fileId").asText())||result.size()>=4)continue;var material=materials.read(Long.parseLong(block.path("fileId").asText()),Long.parseLong(scope.path("materialOwner").asText()),scope.path("materialTenant").asText(),block.path("name").asText());var item=(ObjectNode)json.valueToTree(material);item.set("images",json.createArrayNode());result.add(item);}return result;}

    private JsonNode authorizedMaterial(String token,long id,long file){
        var p=authorize(token);if(p.runId()!=id)throw fail("资料不属于本次运行",403);
        for(var item:loadMaterials(id,parse(p.scopeJson())))if(item.path("fileId").asText().equals(Long.toString(file)))return item;
        throw fail("资料不在当前任务范围",403);
    }
    public JsonNode materialBatch(String token,long id,long file,int offset){
        var item=authorizedMaterial(token,id,file);var visuals=item.path("visuals");
        if(offset<0||offset%6!=0||offset>=visuals.size())throw fail("资料批次无效",400);
        var scope=parse(authorize(token).scopeJson());var result=json.createObjectNode();var values=result.putArray("items");
        for(int i=offset;i<Math.min(offset+6,visuals.size());i++){
            var visual=(ObjectNode)visuals.get(i).deepCopy();
            var cache=db.queryForList("SELECT summary::text FROM asp_agent_step WHERE run_id=? AND name='material_image' AND status='succeeded' AND summary->>'fileId'=? AND summary->>'sha256'=? AND summary->>'index'=? ORDER BY sequence DESC LIMIT 1",id,Long.toString(file),visual.path("sha256").asText(),Integer.toString(i));
            if(!cache.isEmpty()){var saved=parse(cache.get(0).get("summary").toString());visual.set("cached",json.createObjectNode().put("status",saved.path("recognitionStatus").asText()).put("text",saved.path("text").asText()).put("role",saved.path("role").asText("other")).put("caption",saved.path("caption").asText()));}
            else if(!visual.path("kind").asText().equals("unsupported"))visual.put("url",materials.image(file,Long.parseLong(scope.path("materialOwner").asText()),scope.path("materialTenant").asText(),i));
            values.add(visual);
        }return result;
    }
    public void progress(String token,long id,JsonNode input){
        var p=authorize(token);if(p.runId()!=id)throw fail("进度不属于本次运行",403);
        String stage=input.path("stage").asText(),status=input.path("status").asText();
        if(!Set.of("material_read","vision_batch","material_image","answer_prepare").contains(stage)||!Set.of("started","succeeded","failed").contains(status))throw fail("进度类型无效",400);
        var summary=json.createObjectNode();
        if(stage.equals("material_image")){
            long file=input.path("fileId").asLong();int index=input.path("index").asInt(-1);var material=authorizedMaterial(token,id,file);
            if(index<0||index>=material.path("visuals").size()||!material.path("visuals").get(index).path("sha256").asText().equals(input.path("sha256").asText()))throw fail("图片依据已变化",409);
            String text=input.path("text").asText(),recognition=input.path("recognitionStatus").asText();
            if(text.length()>12000||!Set.of("read","unreadable").contains(recognition)||recognition.equals("read")&&text.isBlank())throw fail("图片转写无效",400);
            summary.put("fileId",Long.toString(file)).put("index",index).put("sha256",input.path("sha256").asText()).put("text",recognition.equals("read")?text:"").put("recognitionStatus",recognition);
            String role=input.path("role").asText("other");summary.put("role",Set.of("poster","photo","logo","table","qr","other").contains(role)?role:"other").put("caption",input.path("caption").asText().substring(0,Math.min(80,input.path("caption").asText().length())));
        }else {summary.put("completed",Math.max(0,Math.min(160,input.path("completed").asInt()))).put("total",Math.max(0,Math.min(160,input.path("total").asInt())));}
        visibleStep(id,"control",stage,status,summary);
    }

    /** Stop the selected subtree, including failed children that could otherwise be resumed. */
    public JsonNode stop(long id) {
        own(id);
        var ids=db.queryForList("WITH RECURSIVE tree AS (SELECT id FROM asp_agent_run WHERE id=? UNION ALL SELECT r.id FROM asp_agent_run r JOIN tree t ON r.parent_run_id=t.id) SELECT id FROM tree",Long.class,id);
        new TransactionTemplate(transactions).executeWithoutResult(tx->{
            for(long run:ids)db.update("UPDATE asp_agent_run SET status='stopped',token_hash='',ended_at=CURRENT_TIMESTAMP,version=version+1 WHERE id=? AND status IN('running','waiting_children','waiting_input','waiting_confirmation','failed')",run);
        });
        wakeParent(id);
        return reference(json,"runId",id,"stopped");
    }
    public JsonNode confirm(long id,long messageId,boolean accepted) {
        own(id);
        var rows=db.queryForList("SELECT blocks::text FROM asp_agent_message WHERE id=? AND run_id=? AND role='assistant'",messageId,id);
        if(rows.isEmpty())throw fail("找不到本次确认内容",404);
        var block=parse(rows.get(0).get("blocks").toString()).path(0);
        if(!block.path("kind").asText().equals("confirmation"))throw fail("该消息无需确认",409);
        return new TransactionTemplate(transactions).execute(tx->{
            var locked=db.queryForMap("SELECT * FROM asp_agent_run WHERE id=? FOR UPDATE",id);
            if(!"waiting_confirmation".equals(locked.get("status")))throw fail("本次确认已处理或已停止，请刷新",409);
            if(number(locked.getOrDefault("tokens_reserved",0))>0)throw fail("正在保存本轮核对结果，请稍后确认",409);
            var principal=principal(id);
            if(accepted) {
                String code=block.path("code").asText();var input=block.path("input");
                if(!principal.capabilities().contains(code))throw fail("该项委托已撤销，请重新核对当前权限",403);
                var previous=TrustedRunContext.current();
                Long confirmation;
                try {
                    TrustedRunContext.bind(principal);
                    if(!JsonFingerprint.hash(actions.preview(code,input)).equals(JsonFingerprint.hash(block.path("preview"))))
                        throw fail("确认卡中的名单、金额或状态已变化，请重新准备确认卡",409);
                    // Only the real browser session may issue human consent. Execution below is still Agent-scoped.
                    TrustedRunContext.clear();
                    if(!(actions instanceof HumanActionConfirmation issuer))throw fail("确认服务尚不可用",409);
                    confirmation=issuer.confirm(code,input);
                    db.update("UPDATE asp_action_confirmation SET run_id=? WHERE id=?",id,confirmation);
                    TrustedRunContext.bind(principal(id));
                    var receipt=actions.execute(code,input,"agent-confirm:"+id+":"+messageId,confirmation);
                    message(id,"assistant","办理结果已返回。",json.createArrayNode().add(json.createObjectNode().put("kind","receipt").put("code",code).set("receipt",receipt)));
                    visibleStep(id,"confirmation",code,"succeeded",json.createObjectNode().put("actionCode",code).put("requestKey","agent-confirm:"+id+":"+messageId).set("input",input.deepCopy()));
                } finally {if(previous==null)TrustedRunContext.clear();else TrustedRunContext.bind(previous);}
            } else message(id,"user","我暂不确认这项办理，请继续核对。",json.createArrayNode());
            db.update("UPDATE asp_agent_run SET status='running',stop_reason=NULL,tool_count=0,version=version+1 WHERE id=?",id);
            org.springframework.transaction.support.TransactionSynchronizationManager.registerSynchronization(new org.springframework.transaction.support.TransactionSynchronization(){public void afterCommit(){launch(id);}});
            return reference(json,"runId",id,"running");
        });
    }

    private AgentBudget budget(Map<String,Object> row) {
        var scope=parse(row.get("scope").toString());
        if(scope.has("budget"))return AgentBudget.read(scope.get("budget"));
        return AgentBudget.read(parse(db.queryForObject("SELECT budget::text FROM asp_agent_version WHERE id=?",String.class,row.get("agent_version_id"))));
    }
    private void launch(long id) {
        String token=UUID.randomUUID()+"."+UUID.randomUUID();
        try {
            // afterCommit still binds the old transaction resources. Commit a fresh lease
            // independently before the worker is allowed to authorize its token.
            var lease=new TransactionTemplate(transactions);
            lease.setPropagationBehavior(org.springframework.transaction.TransactionDefinition.PROPAGATION_REQUIRES_NEW);
            boolean reserved=Boolean.TRUE.equals(lease.execute(tx->{
                long root=db.queryForObject("SELECT root_run_id FROM asp_agent_run WHERE id=?",Long.class,id);
                db.queryForObject("SELECT pg_advisory_xact_lock(?)",Object.class,root);
                var row=db.queryForMap("SELECT * FROM asp_agent_run WHERE id=? FOR UPDATE",id);
                if(!"running".equals(row.get("status"))||number(row.getOrDefault("tokens_reserved",0))>0)return false;
                var b=budget(row);var rootBudget=budget(db.queryForMap("SELECT * FROM asp_agent_run WHERE id=?",root));
                long spent=db.queryForObject("SELECT COALESCE(SUM(tokens_used+tokens_reserved),0) FROM asp_agent_run WHERE root_run_id=?",Long.class,root);
                int allowance=(int)Math.min(b.maxTokensPerTurn(),rootBudget.maxTokensTotal()-spent);
                if(allowance<1000)throw fail("本次任务用量已达上限，请核对后新建任务",409);
                db.update("UPDATE asp_agent_run SET token_hash=?,round_key=?,tokens_reserved=?,expires_at=CURRENT_TIMESTAMP+make_interval(secs=>?),started_at=CURRENT_TIMESTAMP WHERE id=?",digest(token),digest(token),allowance,b.activeSeconds(),id);
                return true;
            }));
            if(reserved)workers.execute(()->run(id,token));
        }catch(RejectedExecutionException e){failRun(id,"BUSY",token);db.update("UPDATE asp_agent_run SET tokens_reserved=0 WHERE id=?",id);}
        catch(RuntimeException e){failRun(id,"BUDGET_LIMIT",null);}
    }
    private void run(long id,String token) {
        int used=0,allowance=0;boolean attempted=false,observed=false;
        try {
            if(internalToken.isBlank()){failRun(id,"INTERNAL_TOKEN_MISSING",token);return;}
            var principal=authorize(token);var row=db.queryForMap("SELECT r.*,v.instruction,v.model_name FROM asp_agent_run r JOIN asp_agent_version v ON v.id=r.agent_version_id WHERE r.id=?",id);
            var b=budget(row);TrustedRunContext.bind(principal);
            allowance=(int)number(row.get("tokens_reserved"));
            var currentPlaybook=playbook();var memory=recovery();var childResults=children(0);
            var childVersions=json.createObjectNode();for(var child:childResults.path("children"))childVersions.put(child.path("runId").asText(),child.path("version").asLong());
            db.update("UPDATE asp_agent_run SET scope=jsonb_set(scope,'{childVersions}',?::jsonb) WHERE id=?",childVersions.toString(),id);
            var body=json.createObjectNode().put("runId",Long.toString(id)).put("runToken",token).put("backendPort",backendPort).put("instruction",row.get("instruction").toString()).put("model",row.get("model_name").toString()).put("currentTime",OffsetDateTime.now(ZoneId.of("Asia/Shanghai")).toString());
            body.set("budget",b.json(json));body.put("tokenAllowance",((Number)row.get("tokens_reserved")).intValue());
            body.put("progressEnabled",true);
            body.put("goal",row.get("goal").toString());
            body.set("playbook",currentPlaybook);body.set("recovery",memory);body.set("children",childResults);
            body.set("materials",loadMaterials(id,parse(row.get("scope").toString())));
            // Upload receipts and page hints are system observations, never the user's latest request.
            var history=safeJson(json,db.queryForList("SELECT role,content FROM (SELECT id,role,content,create_time FROM asp_agent_message WHERE run_id=? AND NOT(blocks @> '[{\"kind\":\"material\"}]'::jsonb) AND NOT(blocks @> '[{\"kind\":\"context\"}]'::jsonb) ORDER BY create_time DESC,id DESC LIMIT 30) h ORDER BY create_time,id",id));
            if(scopeShrank(row,principal))for(var entry:history)if(entry.path("role").asText().equals("assistant"))((ObjectNode)entry).put("content","权限已变化，旧办理结果须按当前范围重新查询。");
            body.set("messages",history);
            db.update("UPDATE asp_agent_run SET scope=jsonb_set(scope,'{lastCapabilities}',?::jsonb) WHERE id=?",json.valueToTree(principal.capabilities()).toString(),id);
            TrustedRunContext.clear();
            String encoded=body.toString();
            if(encoded.getBytes(java.nio.charset.StandardCharsets.UTF_8).length>8*1024*1024){failRun(id,"MATERIAL_LIMIT",token);return;}
            visibleStep(id,"control","playbook","succeeded",json.createObjectNode().put("version",currentPlaybook.path("revision").asLong()).put("sourceHash",currentPlaybook.path("sourceHash").asText()));
            var request=HttpRequest.newBuilder(URI.create(gateway+"/internal/agent")).timeout(Duration.ofSeconds(b.activeSeconds()-2)).header("Content-Type","application/json").header("X-Ai-Internal-Token",internalToken).POST(HttpRequest.BodyPublishers.ofString(encoded)).build();
            visibleStep(id,"model","deepseek-flash","started",json.createObjectNode().put("stage","正在核对目标、办理回执和下一步"));
            attempted=true;
            var response=HttpClient.newHttpClient().send(request,HttpResponse.BodyHandlers.ofString());var out=parse(response.body());observed=true;
            used=Math.max(0,out.path("tokens").asInt(0));
            visibleStep(id,"model","deepseek-flash",out.path("ok").asBoolean()?"succeeded":"failed",json.createObjectNode().put("tokens",used));
            if(!out.path("ok").asBoolean()){failRun(id,out.path("errorCode").asText("MODEL_FAILED"),token);return;}
            var fresh=authorizeIfActive(token);
            if(fresh!=null) {
                if(!fresh.capabilities().equals(principal.capabilities())){failRun(id,"AUTH_REVOKED",token);return;}
                TrustedRunContext.bind(fresh);var finalBook=playbook();TrustedRunContext.clear();
                new TransactionTemplate(transactions).executeWithoutResult(tx->{
                    var current=db.queryForMap("SELECT status,token_hash FROM asp_agent_run WHERE id=? FOR UPDATE",id);
                    if(!"running".equals(current.get("status"))||!digest(token).equals(current.get("token_hash")))return;
                    String reply=out.path("reply").asText("请补充下一步需要的信息。");
                    message(id,"assistant",reply.substring(0,Math.min(reply.length(),10000)),AgentPlaybookRules.blocks(json,out.path("blocks"),finalBook));
                    int active=db.queryForObject("SELECT count(*) FROM asp_agent_run WHERE parent_run_id=? AND status IN('running','waiting_children')",Integer.class,id);
                    int unseen=db.queryForObject("SELECT count(*) FROM asp_agent_run c JOIN asp_agent_run p ON p.id=c.parent_run_id WHERE p.id=? AND c.status NOT IN('running','waiting_children') AND c.version<>COALESCE((p.scope->'childVersions'->>c.id::text)::bigint,-1)",Integer.class,id);
                    db.update("UPDATE asp_agent_run SET status=?,token_hash='',version=version+1 WHERE id=?",active>0||unseen>0?"waiting_children":"waiting_input",id);
                });
            }
        }catch(Exception e){failRun(id,e instanceof org.dromara.common.core.exception.ServiceException?"AUTH_REVOKED":"GATEWAY_UNAVAILABLE",token);}
        finally {
            TrustedRunContext.clear();
            // An unobserved provider response consumes its full reservation conservatively.
            // The round key prevents an expired worker from releasing a later round's allocation.
            final int charged=attempted&&!observed?allowance:used;
            new TransactionTemplate(transactions).executeWithoutResult(tx->{var root=db.queryForObject("SELECT root_run_id FROM asp_agent_run WHERE id=?",Long.class,id);db.queryForObject("SELECT pg_advisory_xact_lock(?)",Object.class,root);db.update("UPDATE asp_agent_run SET tokens_used=tokens_used+?,tokens_reserved=0,round_key='' WHERE id=? AND round_key=?",charged,id,digest(token));});
            wakeParent(id);resumeReadyChildren(id);
        }
    }
    private RunPrincipal authorizeIfActive(String token){
        if(db.queryForObject("SELECT count(*) FROM asp_agent_run WHERE token_hash=? AND status='running'",Integer.class,digest(token))==0)return null;
        return authorize(token);
    }
    private void failRun(long id,String code,String token) {
        String safe=Set.of("KEY_ABSENT","MODEL_TIMEOUT","MODEL_FAILED","GATEWAY_UNAVAILABLE","INTERNAL_TOKEN_MISSING","BUSY","TOOL_LIMIT","PLAYBOOK_UNAVAILABLE","MODEL_QUOTA","MODEL_OUTPUT_INVALID","BUDGET_LIMIT","AUTH_REVOKED","MATERIAL_LIMIT").contains(code)?code:"MODEL_FAILED";
        int changed=db.update("UPDATE asp_agent_run SET status='failed',stop_reason=?,token_hash='',ended_at=CURRENT_TIMESTAMP,version=version+1 WHERE id=? AND status='running'"+(token==null?"":" AND token_hash=?"),token==null?new Object[]{safe,id}:new Object[]{safe,id,digest(token)});
        if(changed>0)db.update("UPDATE asp_agent_step SET status='failed',summary=?::jsonb,update_time=CURRENT_TIMESTAMP WHERE run_id=? AND kind='model' AND status='started'",json.createObjectNode().put("errorCode",safe).toString(),id);
    }
    private void wakeParent(long child) {
        var rows=db.queryForList("SELECT parent_run_id FROM asp_agent_run WHERE id=?",child);
        if(!rows.isEmpty()&&rows.get(0).get("parent_run_id")!=null)resumeReadyChildren(number(rows.get(0).get("parent_run_id")));
    }
    /** A child finish wakes only its waiting parent. The next model round reauthorizes and reads visible results. */
    private void resumeReadyChildren(long parent) {
        try {
            boolean resume=Boolean.TRUE.equals(new TransactionTemplate(transactions).execute(tx->{
                var row=db.queryForMap("SELECT status,scope::text,tokens_reserved FROM asp_agent_run WHERE id=? FOR UPDATE",parent);
                if(!"waiting_children".equals(row.get("status"))||number(row.getOrDefault("tokens_reserved",0))>0)return false;
                var seen=parse(row.get("scope").toString()).path("childVersions");
                var ready=db.queryForList("SELECT id,version FROM asp_agent_run WHERE parent_run_id=? AND status NOT IN('running','waiting_children')",parent);
                boolean unseen=ready.stream().anyMatch(c->seen.path(c.get("id").toString()).asLong(-1)!=number(c.get("version")));
                if(!unseen)return false;
                db.update("UPDATE asp_agent_run SET status='running',tool_count=0,version=version+1 WHERE id=?",parent);
                return true;
            }));
            if(resume)launch(parent);
        }catch(RuntimeException ignored){/* A stopped or inaccessible parent is never resurrected. */}
    }
    private boolean scopeShrank(Map<String,Object> row,RunPrincipal live){
        for(var code:parse(row.get("scope").toString()).path("lastCapabilities"))if(!live.capabilities().contains(code.asText()))return true;
        return false;
    }
    @org.springframework.scheduling.annotation.Scheduled(fixedDelay=10000)
    public void recoverInterruptedChildren(){
        for(long run:db.queryForList("SELECT id FROM asp_agent_run WHERE (status='running' OR tokens_reserved>0) AND expires_at<CURRENT_TIMESTAMP LIMIT 32",Long.class)){
            new TransactionTemplate(transactions).executeWithoutResult(tx->{long root=db.queryForObject("SELECT root_run_id FROM asp_agent_run WHERE id=?",Long.class,run);db.queryForObject("SELECT pg_advisory_xact_lock(?)",Object.class,root);db.update("UPDATE asp_agent_run SET status=CASE WHEN status='running' THEN 'failed' ELSE status END,stop_reason=CASE WHEN status='running' THEN 'MODEL_TIMEOUT' ELSE stop_reason END,token_hash='',tokens_used=tokens_used+tokens_reserved,tokens_reserved=0,round_key='',version=version+1 WHERE id=? AND expires_at<CURRENT_TIMESTAMP",run);});
            wakeParent(run);
        }
        for(long run:db.queryForList("SELECT id FROM asp_agent_run WHERE status='waiting_children' LIMIT 32",Long.class))resumeReadyChildren(run);
    }
    private RunPrincipal principal(long id) {
        var rows=db.queryForList("SELECT r.*,a.id AS agent_id FROM asp_agent_run r JOIN asp_agent_version v ON v.id=r.agent_version_id AND v.status='active' JOIN asp_agent a ON a.id=v.agent_id AND a.status='active' WHERE r.id=?",id);
        if(rows.isEmpty())throw fail("运行版本或授权已撤销",403);
        var r=rows.get(0);var scope=(ObjectNode)parse(r.get("scope").toString());
        long actor=number(r.get("actor_id"));String type=r.get("actor_type").toString();
        String tenant=scope.path("tenantId").isTextual()?scope.path("tenantId").asText():null;
        Long org=scope.has("organizationId")?Long.valueOf(scope.path("organizationId").asText()):null;
        if(type.equals("platform")){if(db.queryForObject("SELECT count(*) FROM asp_account WHERE id=? AND status='active'",Integer.class,actor)!=1)throw fail("账号不可用",403);}
        else {
            if(db.queryForObject("SELECT count(*) FROM sys_user WHERE user_id=? AND status='0' AND del_flag='0'",Integer.class,actor)!=1)throw fail("岗位账号不可用",403);
            if(org!=null&&organizations.managedOrganization(actor).filter(o->o.organizationId().equals(org)&&Objects.equals(o.tenantId(),tenant)).isEmpty())throw fail("主办方权限已撤销",403);
        }
        Set<String> snapshot=new HashSet<>();scope.path("capabilities").forEach(c->snapshot.add(c.asText()));
        snapshot.retainAll(new HashSet<>(db.queryForList("SELECT capability_code FROM asp_agent_grant WHERE agent_id=? AND status='active' AND scope=jsonb_build_object('inheritActorScope',true)",String.class,r.get("agent_id"))));
        Set<String> perms=Set.of();
        if(!type.equals("platform")&&!type.equals("admin"))perms=new HashSet<>(db.queryForList("SELECT DISTINCT m.perms FROM sys_user_role ur JOIN sys_role ro ON ro.role_id=ur.role_id AND ro.status='0' AND ro.del_flag='0' JOIN sys_role_menu rm ON rm.role_id=ro.role_id JOIN sys_menu m ON m.menu_id=rm.menu_id WHERE ur.user_id=?",String.class,actor));
        scope.set("runtimePermissions",json.valueToTree(perms));final Set<String> currentPermissions=perms;
        snapshot.removeIf(c->{
            var defs=db.queryForList("SELECT v.definition->>'permission' AS permission FROM asp_capability_activation ac JOIN asp_capability_version v ON v.id=ac.capability_version_id AND v.code=ac.code WHERE ac.code=? AND ac.channel='agent' AND ac.enabled AND v.status='published'",String.class,c);
            return defs.isEmpty()||(!type.equals("platform")&&!type.equals("admin")&&!defs.get(0).isBlank()&&!currentPermissions.contains(defs.get(0))&&!currentPermissions.contains("*:*:*"));
        });
        if(r.get("parent_run_id")!=null){
            if(db.queryForObject("SELECT status FROM asp_agent_run WHERE id=?",String.class,r.get("parent_run_id")).equals("stopped"))throw fail("父任务已停止",403);
            var parent=principal(number(r.get("parent_run_id")));
            if(!parent.actorId().equals(actor)||!parent.actorType().equals(type)||!Objects.equals(parent.organizationId(),org))throw fail("委派身份范围不一致",403);
            snapshot.retainAll(parent.capabilities());
            int allowed=db.queryForObject("SELECT count(*) FROM asp_agent_grant g JOIN asp_agent_version v ON v.agent_id=g.agent_id WHERE v.id=(SELECT agent_version_id FROM asp_agent_run WHERE id=?) AND g.capability_code=(SELECT 'delegate:'||a2.code FROM asp_agent a2 WHERE a2.id=?) AND g.status='active' AND g.scope=jsonb_build_object('inheritActorScope',true)",Integer.class,r.get("parent_run_id"),r.get("agent_id"));
            if(allowed!=1)throw fail("该职能委派已撤销",403);
        }
        return new RunPrincipal(id,type,actor,tenant,org,Set.copyOf(snapshot),scope.toString());
    }

    public RunPrincipal authorize(String token) {
        if(token==null||token.length()>150)throw fail("运行身份无效",403);
        var ids=db.queryForList("SELECT id FROM asp_agent_run WHERE token_hash=? AND status='running' AND expires_at>CURRENT_TIMESTAMP",Long.class,digest(token));
        if(ids.isEmpty())throw fail("运行已结束或授权已撤销",403);
        return principal(ids.get(0));
    }

    public void tool(String name,String status){tool(name,status,json.createObjectNode(),null);}
    @Override public void tool(String name,String status,JsonNode input,String requestKey) {
        var p=TrustedRunContext.current();if(p==null)throw fail("运行身份缺失",403);
        var b=AgentBudget.read(parse(p.scopeJson()).path("budget"));
        int n=db.update("UPDATE asp_agent_run SET tool_count=tool_count+1 WHERE id=? AND status='running' AND tool_count<? AND expires_at>CURRENT_TIMESTAMP",p.runId(),b.maxToolsPerTurn());
        if(n!=1)throw fail("本轮调用已达上限，请分步补充",409);
        var summary=json.createObjectNode().put("actionCode",name);
        if(input.toString().length()<=12000)summary.set("input",input.deepCopy());
        if(requestKey!=null)summary.put("requestKey",requestKey);
        visibleStep(p.runId(),"tool",name,status,summary);
    }
    @Override public String requestKey(String code,JsonNode input,String suggested) {
        var p=TrustedRunContext.current();if(p==null)throw fail("运行身份缺失",403);
        long root=db.queryForObject("SELECT root_run_id FROM asp_agent_run WHERE id=?",Long.class,p.runId());
        return "agent:"+root+":"+digest(code+":"+JsonFingerprint.hash(input)).substring(0,40);
    }
    public JsonNode propose(String code,JsonNode input){var p=TrustedRunContext.current();if(p==null||!p.capabilities().contains(code))throw fail("没有该项委托",403);var d=actions.available().stream().filter(c->c.code().equals(code)).findFirst().orElseThrow(()->fail("能力已关闭",403));if(!d.confirmation())throw fail("此能力无需确认，可直接办理",400);var preview=actions.preview(code,input);var block=json.createObjectNode();block.put("kind","confirmation");block.put("code",code);block.put("title",d.title());block.set("input",input.deepCopy());block.set("preview",preview);message(p.runId(),"assistant","请核对这项办理的具体内容，确认后才会执行。",json.createArrayNode().add(block));db.update("UPDATE asp_agent_run SET status='waiting_confirmation',token_hash='',version=version+1 WHERE id=? AND status='running'",p.runId());return block;}

    public JsonNode delegate(String agentCode,String goal) {
        var p=TrustedRunContext.current();if(p==null||goal.length()>2000||goal.isBlank())throw fail("请描述具体的委派目标",400);
        long child=new TransactionTemplate(transactions).execute(tx->{
            long root=db.queryForObject("SELECT root_run_id FROM asp_agent_run WHERE id=?",Long.class,p.runId());
            db.queryForObject("SELECT pg_advisory_xact_lock(?)",Object.class,root);
            var row=db.queryForMap("SELECT depth,root_run_id,agent_version_id FROM asp_agent_run WHERE id=? FOR UPDATE",p.runId());
            var b=AgentBudget.read(parse(p.scopeJson()).path("budget"));
            int count=db.queryForObject("SELECT count(*) FROM asp_agent_run WHERE root_run_id=? AND parent_run_id IS NOT NULL",Integer.class,row.get("root_run_id"));
            if(count>=b.maxChildren())throw fail("本次委派数量已达上限",409);
            int grant=db.queryForObject("SELECT count(*) FROM asp_agent_grant g JOIN asp_agent_version v ON v.agent_id=g.agent_id WHERE v.id=? AND g.capability_code=? AND g.status='active' AND g.scope=jsonb_build_object('inheritActorScope',true)",Integer.class,row.get("agent_version_id"),"delegate:"+agentCode);
            if(grant!=1)throw fail("该职能助手尚未授权",403);
            var scope=(ObjectNode)parse(p.scopeJson());scope.set("capabilities",json.valueToTree(p.capabilities()));
            return create(agentCode,goal,p.actorType(),p.actorId(),scope,p.runId(),number(row.get("root_run_id")),((Number)row.get("depth")).intValue()+1);
        });
        visibleStep(p.runId(),"delegate",agentCode,"succeeded",json.createObjectNode().put("childRunId",Long.toString(child)));
        launch(child);return reference(json,"childRunId",child,"running");
    }
    @Override public JsonNode children(int waitSeconds) {
        var p=TrustedRunContext.current();if(p==null||waitSeconds<0||waitSeconds>10)throw fail("委派读取范围或等待时间无效",400);
        long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(waitSeconds);
        com.fasterxml.jackson.databind.node.ArrayNode values;
        do {
            values=json.createArrayNode();
            for(var row:db.queryForList("SELECT id,status,goal,version,stop_reason FROM asp_agent_run WHERE parent_run_id=? ORDER BY create_time,id LIMIT 8",p.runId())){
                long id=number(row.get("id"));var value=json.createObjectNode().put("runId",Long.toString(id)).put("status",row.get("status").toString()).put("goal",row.get("goal").toString()).put("version",number(row.get("version")));
                try {
                    var child=principal(id);
                    if(!child.actorId().equals(p.actorId())||!p.capabilities().containsAll(child.capabilities()))throw fail("范围已变化",403);
                    var replies=db.queryForList("SELECT content FROM asp_agent_message WHERE run_id=? AND role='assistant' ORDER BY create_time DESC,id DESC LIMIT 1",id);
                    var childRow=db.queryForMap("SELECT scope::text FROM asp_agent_run WHERE id=?",id);
                    if(scopeShrank(childRow,child))value.put("status","denied").put("errorCode","AUTH_REVOKED");
                    else if(!replies.isEmpty()&&!"running".equals(row.get("status")))value.put("reply",replies.get(0).get("content").toString());
                    if(row.get("stop_reason")!=null)value.put("errorCode",row.get("stop_reason").toString());
                }catch(RuntimeException revoked){value.put("status","denied");value.put("errorCode","AUTH_REVOKED");}
                values.add(value);
            }
            if(values.isEmpty()||!java.util.stream.StreamSupport.stream(values.spliterator(),false).anyMatch(c->Set.of("running","waiting_children").contains(c.path("status").asText()))||System.nanoTime()>=deadline)break;
            try{Thread.sleep(200);}catch(InterruptedException stopped){Thread.currentThread().interrupt();break;}
            principal(p.runId());
        }while(true);
        // This version marker records which child state was actually delivered to the model.
        // A child finishing between its last read and the parent's final reply must wake the parent.
        var consumed=json.createObjectNode();for(var value:values)consumed.put(value.path("runId").asText(),value.path("version").asLong());
        db.update("UPDATE asp_agent_run SET scope=jsonb_set(scope,'{childVersions}',?::jsonb) WHERE id=?",consumed.toString(),p.runId());
        return json.createObjectNode().set("children",values);
    }
    @Override public JsonNode recovery() {
        var p=TrustedRunContext.current();if(p==null)throw fail("运行身份缺失",403);
        var result=json.createArrayNode();var allowed=new HashMap<String,CapabilityDefinition>();
        actions.available().forEach(a->allowed.put(a.code(),a));
        for(var row:db.queryForList("SELECT name,status,summary::text FROM asp_agent_step WHERE run_id=? AND kind IN('tool','confirmation') ORDER BY sequence DESC LIMIT 30",p.runId())){
            String code=row.get("name").toString();if(!allowed.containsKey(code))continue;
            var saved=parse(row.get("summary").toString());if(!saved.has("input"))continue;
            try {
                var current=actions.preview(code,saved.get("input")); // Re-check both capability and current object access.
                var item=(ObjectNode)saved.deepCopy();item.put("status",row.get("status").toString());
                if(!allowed.get(code).mutation())item.set("result",current); // Reads have no mutation receipt and stale reads are refreshed.
                else if(saved.has("requestKey"))item.set("receipt",actions.lookup(code,saved.path("requestKey").asText()));
                result.add(item);
            }catch(RuntimeException noLongerVisible){/* No cached fact overrides current row or capability authorization. */}
            if(result.size()>=20)break;
        }
        return json.createObjectNode().set("records",result);
    }
    private void message(long run,String role,String content,JsonNode blocks){db.update("INSERT INTO asp_agent_message(id,run_id,role,content,blocks) VALUES(?,?,?,?,?::jsonb)",nextId(),run,role,content,blocks.toString());}
    private JsonNode parse(String value){try{return json.readTree(value);}catch(Exception e){throw fail("进度数据无法读取",409);}}
    private static String digest(String v){try{return HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(v.getBytes(java.nio.charset.StandardCharsets.UTF_8)));}catch(Exception e){throw new IllegalStateException(e);}}

    @Override public void toolCompleted(String name,String status){toolCompleted(name,status,json.createObjectNode(),json.createObjectNode(),null);}
    @Override public void toolCompleted(String name,String status,JsonNode input,JsonNode result,String requestKey) {
        var p=TrustedRunContext.current();if(p==null)throw fail("运行身份缺失",403);
        if(!Set.of("succeeded","failed").contains(status))throw fail("工具状态无效",400);
        var summary=json.createObjectNode().put("actionCode",name);
        if(input.toString().length()<=12000)summary.set("input",input.deepCopy());
        if(requestKey!=null)summary.put("requestKey",requestKey);
        if(result.toString().length()<=40000)summary.set("result",result.deepCopy());
        else summary.put("resultHash",JsonFingerprint.hash(result)).put("coverage","结果较长，继续办理须重新读取");
        db.update("UPDATE asp_agent_step SET status=?,summary=?::jsonb,update_time=CURRENT_TIMESTAMP WHERE id=(SELECT id FROM asp_agent_step WHERE run_id=? AND name=? AND status='started' ORDER BY sequence DESC LIMIT 1)",status,summary.toString(),p.runId(),name);
    }

}
