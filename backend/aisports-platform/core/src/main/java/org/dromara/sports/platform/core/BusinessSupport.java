package org.dromara.sports.platform.core;

import cn.hutool.core.util.IdUtil;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import java.util.*;

/** Small typed contract helpers. Actor fields are always obtained from verified server context. */
public final class BusinessSupport {
    private BusinessSupport() { }
    public static long nextId(){return IdUtil.getSnowflakeNextId();}
    public static long account(){
        var run=TrustedRunContext.current();
        if(run!=null && "platform".equals(run.actorType()))return run.actorId();
        if(!LoginHelper.isLogin() || LoginHelper.getUserType()!=UserType.PLATFORM_USER)throw fail("请使用本人参赛账号登录",403);
        return LoginHelper.getUserId();
    }
    public static ServiceException fail(String message,int status){return new ServiceException(message,status);}
    public static long id(JsonNode input,String name){
        String value=input.path(name).asText();
        if(!value.matches("[1-9][0-9]{0,18}"))throw fail("请选择有效的"+name,400);
        try{return Long.parseLong(value);}catch(NumberFormatException e){throw fail("编号超出范围",400);}
    }
    public static Long optionalId(JsonNode input,String name){return input.hasNonNull(name)?id(input,name):null;}
    public static long number(Object value){return ((Number)value).longValue();}
    public static String text(JsonNode input,String name,int max){
        String value=input.path(name).asText("").strip();
        if(value.isEmpty()||value.length()>max)throw fail("请填写"+name+"（最多"+max+"字）",400);
        return value;
    }
    public static ObjectNode reference(ObjectMapper json,String name,long id,String status){var n=json.createObjectNode();n.put(name,Long.toString(id));n.put("status",status);return n;}
    public static JsonNode safeJson(ObjectMapper json,Object value){
        if(value instanceof Long l)return json.getNodeFactory().textNode(l.toString());
        if(value instanceof Map<?,?> m){var n=json.createObjectNode();m.forEach((k,v)->n.set(k.toString(),safeJson(json,v)));return n;}
        if(value instanceof Collection<?> c){var n=json.createArrayNode();c.forEach(v->n.add(safeJson(json,v)));return n;}
        if(value instanceof java.time.temporal.TemporalAccessor||value instanceof java.sql.Timestamp||value instanceof java.util.Date)return json.getNodeFactory().textNode(value.toString());
        return json.valueToTree(value);
    }
    public static CapabilityDefinition capability(ObjectMapper json,String code,String title,String table,boolean agent,boolean confirmation,Set<String> actors,String permission,Set<String> reads,Set<String> writes,String... fields){
        var schema=json.createObjectNode();schema.put("type","object");schema.put("additionalProperties",false);var props=schema.putObject("properties");var required=schema.putArray("required");
        for(String field:fields){boolean optional=field.endsWith("?");String name=optional?field.substring(0,field.length()-1):field;props.putObject(name).put("type",Set.of("ready","publicVisible","charged").contains(name)?"boolean":name.equals("expectedVersion")?"integer":"string");if(!optional)required.add(name);}
        return new CapabilityDefinition(code,title,table,title,!writes.isEmpty(),agent,confirmation,actors,permission,reads,writes,schema);
    }
}
