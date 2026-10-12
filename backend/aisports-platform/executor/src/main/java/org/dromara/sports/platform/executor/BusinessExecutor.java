package org.dromara.sports.platform.executor;

import cn.hutool.core.util.IdUtil;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.platform.authz.ActionAuthorization;
import org.dromara.sports.platform.core.*;
import org.dromara.sports.platform.registry.CapabilityRegistry;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.OffsetDateTime;
import java.util.*;

/** All new business channels share live authorization, transactional idempotency and durable receipts. */
@Service
@RequiredArgsConstructor
public class BusinessExecutor implements ActionDispatcher,HumanActionConfirmation {
    private final CapabilityRegistry registry;
    private final ActionAuthorization authz;
    private final JdbcTemplate jdbc;
    private final PlatformTransactionManager transactions;
    private final ObjectMapper json;
    @FunctionalInterface public interface LegacyCall {Object execute() throws Throwable;}
    /** Compatible HTTP routes use this same executor; existing services retain their business guards. */
    public Object legacy(SportsAction action,LegacyCall call)throws Throwable {
        if(ActionContext.current()!=null)return call.execute();
        if(TrustedRunContext.current()!=null)throw new ServiceException("助手须通过已注册的业务能力办理",403);
        if(!action.capability().isBlank()){
            var definition=registry.definition(action.capability());authz.check(definition);
            if(!registry.open(definition.code(),"ui"))throw new ServiceException("该兼容入口对应的能力尚未开放",409);
        }
        var actor=org.dromara.common.satoken.utils.LoginHelper.isLogin()?authz.actor():new ActionAuthorization.Actor("bootstrap",0L,null,null);
        String key=UUID.randomUUID().toString();var context=new ActionContext(action.value(),actor.type(),actor.id(),actor.tenantId(),"ui",key,"legacy",null,Set.of(action.reads()),Set.of(action.writes()));
        try{return new TransactionTemplate(transactions).execute(tx->{ActionContext.bind(context);try{Object result=call.execute();jdbc.update("INSERT INTO asp_action_execution(id,action_code,actor_type,actor_id,tenant_scope,channel,request_key,payload_hash,status,result_reference,occurred_at) VALUES(?,?,?,?,?,'ui',?,'legacy','succeeded','{}'::jsonb,CURRENT_TIMESTAMP)",IdUtil.getSnowflakeNextId(),action.value(),actor.type(),actor.id(),actor.tenantId(),key);return result;}catch(Throwable cause){throw new LegacyFailure(cause);}finally{ActionContext.clear();}});}
        catch(RuntimeException failure){var tx=new TransactionTemplate(transactions);tx.setPropagationBehavior(org.springframework.transaction.TransactionDefinition.PROPAGATION_REQUIRES_NEW);tx.execute(s->{jdbc.update("INSERT INTO asp_action_execution(id,action_code,actor_type,actor_id,tenant_scope,channel,request_key,payload_hash,status,result_reference,error_code,occurred_at) VALUES(?,?,?,?,?,'ui',?,'legacy','failed','{}'::jsonb,'LEGACY_ACTION_REJECTED',CURRENT_TIMESTAMP)",IdUtil.getSnowflakeNextId(),action.value(),actor.type(),actor.id(),actor.tenantId(),key);return null;});throw failure instanceof LegacyFailure?failure.getCause():failure;}
    }
    private static class LegacyFailure extends RuntimeException {LegacyFailure(Throwable cause){super(cause);}}
    public List<CapabilityDefinition> available() {
        String channel=TrustedRunContext.current()==null?"ui":"agent";
        return registry.definitions().stream().filter(authz::allowed).filter(d->registry.open(d.code(),channel)).toList();
    }
    @Override public JsonNode guidance(){
        var result=json.createArrayNode();var run=TrustedRunContext.current();
        for(var definition:registry.definitions())if(authz.guidanceAllowed(definition)){
            boolean ui=registry.open(definition.code(),"ui"),agent=definition.agent()&&registry.open(definition.code(),"agent")&&(run==null||run.capabilities().contains(definition.code()));
            if(!ui&&!agent)continue;
            var item=(ObjectNode)json.valueToTree(definition);item.put("uiEnabled",ui);item.put("agentEnabled",agent);item.put("sourceHash",registry.fingerprint(definition));result.add(item);
        }return result;
    }
    public JsonNode preview(String code,JsonNode input) {
        var d=registry.definition(code); authz.check(d); validate(d,input);
        if(!registry.open(code,TrustedRunContext.current()==null?"ui":"agent"))throw new ServiceException("该能力尚未开放",409);
        return scopedRead(d,()->registry.provider(code).preview(code,input));
    }
    public JsonNode execute(String code,JsonNode input,String key,Long confirmationId) {
        var d=registry.definition(code); var actor=authz.actor(); String channel=TrustedRunContext.current()==null?"ui":"agent";
        if(key==null || !key.matches("[a-zA-Z0-9:_.-]{1,128}")) throw new ServiceException("请使用有效的请求编号",400);
        String hash=hash(input); Long runId=TrustedRunContext.current()==null?null:TrustedRunContext.current().runId();
        try {
            authz.check(d); validate(d,input);
            if(!registry.open(code,channel)) throw new ServiceException("该能力尚未开放，请使用当前可用入口",409);
            if(!d.mutation()) return scopedRead(d,()->registry.provider(code).execute(code,input));
            return new TransactionTemplate(transactions).execute(status->{
                jdbc.queryForObject("SELECT pg_advisory_xact_lock(hashtextextended(?,0))",Object.class,actor.type()+":"+actor.id()+":"+code+":"+key);
                var previous=jdbc.queryForList("SELECT id,payload_hash,result_reference::text FROM asp_action_execution WHERE actor_type=? AND actor_id=? AND action_code=? AND request_key=? AND status='succeeded'",actor.type(),actor.id(),code,key);
                if(!previous.isEmpty()) {
                    if(!hash.equals(previous.get(0).get("payload_hash"))) throw new ServiceException("该请求编号已用于不同内容",409);
                    return receipt(previous.get(0).get("id"),code,true,parse(previous.get(0).get("result_reference").toString()));
                }
                if(d.confirmation()) consumeConfirmation(code,input,hash,actor,confirmationId);
                var old=ActionContext.current();
                ActionContext.bind(new ActionContext(code,actor.type(),actor.id(),actor.tenantId(),channel,key,hash,runId,d.reads(),d.writes()));
                try {
                    JsonNode result=registry.provider(code).execute(code,input);
                    long id=IdUtil.getSnowflakeNextId();
                    jdbc.update("INSERT INTO asp_action_execution(id,action_code,actor_type,actor_id,tenant_scope,channel,request_key,payload_hash,status,result_reference,run_id,occurred_at) VALUES (?,?,?,?,?,?,?,?,'succeeded',?::jsonb,?,CURRENT_TIMESTAMP)",id,code,actor.type(),actor.id(),actor.tenantId(),channel,key,hash,result.toString(),runId);
                    return receipt(id,code,false,result);
                } finally { if(old==null)ActionContext.clear();else ActionContext.bind(old); }
            });
        } catch(RuntimeException e) {
            var tx=new TransactionTemplate(transactions); tx.setPropagationBehavior(org.springframework.transaction.TransactionDefinition.PROPAGATION_REQUIRES_NEW);
            tx.execute(s->{jdbc.update("INSERT INTO asp_action_execution(id,action_code,actor_type,actor_id,tenant_scope,channel,request_key,payload_hash,status,result_reference,error_code,run_id,occurred_at) VALUES (?,?,?,?,?,?,?,?,?,'{}'::jsonb,?,?,CURRENT_TIMESTAMP)",IdUtil.getSnowflakeNextId(),code,actor.type(),actor.id(),actor.tenantId(),channel,key,hash,e instanceof ServiceException?"denied":"failed",e instanceof ServiceException?"BUSINESS_REJECTED":"EXECUTION_FAILED",runId);return null;});
            throw e;
        }
    }
    private JsonNode scopedRead(CapabilityDefinition definition,java.util.function.Supplier<JsonNode> read) {
        var actor=authz.actor();var old=ActionContext.current();var run=TrustedRunContext.current();
        return new TransactionTemplate(transactions).execute(tx->{
            ActionContext.bind(new ActionContext(definition.code(),actor.type(),actor.id(),actor.tenantId(),run==null?"ui":"agent","read","read",run==null?null:run.runId(),definition.reads(),Set.of()));
            try{return read.get();}finally{if(old==null)ActionContext.clear();else ActionContext.bind(old);}
        });
    }
    public Long confirm(String code,JsonNode input) {
        if(TrustedRunContext.current()!=null) throw new ServiceException("请由本人在页面核对并确认",403);
        var d=registry.definition(code);authz.check(d);validate(d,input);var a=authz.actor();long id=IdUtil.getSnowflakeNextId();
        var binding=json.createObjectNode();binding.put("previewHash",hash(preview(code,input)));
        if(input.has("expectedVersion"))binding.set("expectedVersion",input.get("expectedVersion"));
        jdbc.update("INSERT INTO asp_action_confirmation(id,actor_type,actor_id,action_code,payload_hash,object_versions,status,expires_at,confirmed_at) VALUES (?,?,?,?,?,?::jsonb,'confirmed',CURRENT_TIMESTAMP+INTERVAL '5 minutes',CURRENT_TIMESTAMP)",id,a.type(),a.id(),code,hash(input),binding.toString());
        return id;
    }
    public JsonNode lookup(String code,String key) {
        var actor=authz.actor();var d=registry.definition(code);authz.check(d);
        if(!registry.open(code,TrustedRunContext.current()==null?"ui":"agent"))throw new ServiceException("该回执对应能力已关闭",403);
        var rows=jdbc.queryForList("SELECT id,status,error_code,result_reference::text FROM asp_action_execution WHERE actor_type=? AND actor_id=? AND action_code=? AND request_key=? ORDER BY occurred_at DESC LIMIT 1",actor.type(),actor.id(),code,key);
        if(rows.isEmpty())throw new ServiceException("尚未找到本次办理回执，可使用原请求编号重试",404);
        var row=rows.get(0);var node=json.createObjectNode();node.put("receiptId",row.get("id").toString());node.put("status",row.get("status").toString());node.put("actionCode",code);node.set("result",parse(row.get("result_reference").toString()));if(row.get("error_code")!=null)node.put("errorCode",row.get("error_code").toString());return node;
    }
    private void consumeConfirmation(String code,JsonNode input,String hash,ActionAuthorization.Actor a,Long id) {
        if(id==null) throw new ServiceException("请核对内容并明确确认后继续",409);
        var bindings=jdbc.queryForList("SELECT object_versions::text AS binding FROM asp_action_confirmation WHERE id=? AND actor_type=? AND actor_id=? FOR UPDATE",id,a.type(),a.id());
        if(bindings.isEmpty()||!hash(preview(code,input)).equals(parse(bindings.get(0).get("binding").toString()).path("previewHash").asText()))
            throw new ServiceException("名单、金额或待办内容已变化，请重新核对后确认",409);
        int n=jdbc.update("UPDATE asp_action_confirmation SET status='consumed',update_time=CURRENT_TIMESTAMP WHERE id=? AND actor_type=? AND actor_id=? AND action_code=? AND payload_hash=? AND status='confirmed' AND expires_at>CURRENT_TIMESTAMP",id,a.type(),a.id(),code,hash);
        if(n!=1) throw new ServiceException("确认已过期或内容发生变化，请重新核对",409);
    }
    private ObjectNode receipt(Object id,String code,boolean replayed,JsonNode result) {
        var value=json.createObjectNode();value.put("receiptId",id.toString());value.put("actionCode",code);value.put("status","succeeded");value.put("replayed",replayed);value.set("result",result);return value;
    }
    public static String hash(JsonNode input) {
        try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(canonical(input).getBytes(StandardCharsets.UTF_8))); }
        catch(Exception e){throw new IllegalStateException(e);}
    }
    private static String canonical(JsonNode n) {
        if(n==null)return "null";
        if(n.isObject()){var keys=new TreeSet<String>();n.fieldNames().forEachRemaining(keys::add);var parts=new ArrayList<String>();for(String k:keys)parts.add(com.fasterxml.jackson.databind.node.TextNode.valueOf(k).toString()+":"+canonical(n.get(k)));return "{"+String.join(",",parts)+"}";}
        if(n.isArray()){var parts=new ArrayList<String>();n.forEach(v->parts.add(canonical(v)));return "["+String.join(",",parts)+"]";}return n.toString();
    }
    private JsonNode parse(String value){try{return json.readTree(value);}catch(Exception e){throw new IllegalStateException("Invalid receipt");}}
    private void validate(CapabilityDefinition d,JsonNode input) {
        if(input==null||!input.isObject())throw new ServiceException("请填写办理内容",400);
        var schema=d.inputSchema();var props=schema.path("properties");
        if(!schema.path("additionalProperties").asBoolean(true))input.fieldNames().forEachRemaining(k->{if(!props.has(k))throw new ServiceException("办理内容包含不支持的字段："+k,400);});
        for(var required:schema.path("required"))if(!input.hasNonNull(required.asText()))throw new ServiceException("还缺少："+required.asText(),400);
        input.fields().forEachRemaining(e->{var field=props.path(e.getKey());var value=e.getValue();if(value.isNull())return;boolean valid=switch(field.path("type").asText()){case "string"->value.isTextual();case "boolean"->value.isBoolean();case "integer"->value.isIntegralNumber()&&value.canConvertToInt()&&value.intValue()>=0;case "object"->value.isObject();case "array"->value.isArray();default->false;};if(!valid)throw new ServiceException("填写格式不正确："+e.getKey(),400);if(value.isTextual()&&value.textValue().length()>10000)throw new ServiceException("内容过长，请分次补充",400);});
    }
}
