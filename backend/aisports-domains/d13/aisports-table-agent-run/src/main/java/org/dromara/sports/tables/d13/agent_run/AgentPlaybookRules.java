package org.dromara.sports.tables.d13.agent_run;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.dromara.sports.platform.core.JsonFingerprint;
import java.util.*;
import static org.dromara.sports.platform.core.BusinessSupport.fail;

/** Trusted, versioned knowledge can guide a role; only the live executor grants a business operation. */
public final class AgentPlaybookRules {
    private AgentPlaybookRules(){}
    static final Set<String> TOOLS=Set.of("sports_playbook","sports_capabilities","sports_preview","sports_execute","sports_propose","sports_delegate","sports_children","sports_recovery");
    public static ObjectNode filter(ObjectMapper json,JsonNode stored,String expectedHash,long revision,String actor,JsonNode actions,JsonNode context){
        if(!expectedHash.isBlank()&&!JsonFingerprint.hash(stored).equals(expectedHash))throw fail("助手办理指引版本不一致，请联系平台核对",409);
        var out=json.createObjectNode().put("revision",revision).put("sourceHash",expectedHash);
        var toolCatalog=json.createObjectNode().put("schemaVersion",1);var tools=toolCatalog.putArray("entries");
        for(var tool:stored.path("tools").path("entries"))if(TOOLS.contains(tool.path("name").asText())&&tool.path("agentAllowed").asBoolean(true))tools.add(tool.deepCopy());out.set("toolCatalog",toolCatalog);
        var available=json.createArrayNode();var byCode=new HashMap<String,JsonNode>();
        for(var action:actions)if(action.path("uiEnabled").asBoolean()||action.path("agentEnabled").asBoolean()){var visible=json.createObjectNode();for(String key:List.of("code","title","description","mutation","confirmation","inputSchema","uiEnabled","agentEnabled","sourceHash"))if(action.has(key))visible.set(key,action.get(key).deepCopy());available.add(visible);byCode.put(action.path("code").asText(),action);}
        out.set("actions",available);out.set("context",context.deepCopy());
        var businessMap=json.createObjectNode().put("schemaVersion",1).put("code",stored.path("businessMap").path("code").asText()).put("title",stored.path("businessMap").path("title").asText());var flows=businessMap.putArray("flows");
        for(var flow:stored.path("businessMap").path("flows"))if(role(flow,actor)){
            var selected=(ObjectNode)flow.deepCopy();var steps=json.createArrayNode();
            for(var step:flow.path("steps"))if(!step.has("actors")||role(step,actor)){
                var item=(ObjectNode)step.deepCopy();var codes=json.createArrayNode();boolean manual=false,agent=false;
                for(var code:step.path("capabilities")){var d=byCode.get(code.asText());if(d!=null){codes.add(code.asText());manual|=d.path("uiEnabled").asBoolean();agent|=d.path("agentEnabled").asBoolean();}}
                item.set("capabilities",codes);item.put("uiEnabled",manual);item.put("agentEnabled",agent);
                String path=resolvePath(step.path("path").asText(),context);if(path==null||!manual)item.remove("path");else item.put("path",path);steps.add(item);
            }selected.set("steps",steps);flows.add(selected);
        }out.set("businessMap",businessMap);var skills=out.putArray("skills");
        for(var skill:stored.path("skills").path("entries"))if(role(skill,actor))skills.add(skill.deepCopy());return out;
    }
    private static boolean role(JsonNode item,String actor){for(var type:item.path("actors"))if(type.asText().equals(actor))return true;return false;}
    private static String resolvePath(String path,JsonNode context){
        if(!path.startsWith("/")||path.startsWith("//")||path.contains(":")||path.contains("\\")||path.length()>250)return null;
        for(String key:List.of("eventId","roomId","registrationId")){String token="{"+key+"}";if(path.contains(token)){String value=context.path(key).asText();if(!value.matches("[1-9][0-9]{0,18}"))return null;path=path.replace(token,value);}}
        return path.contains("{")||path.contains("}")?null:path;
    }
    /** Model blocks are candidates. Paths, authority and completion markers are never taken from model output. */
    public static ArrayNode blocks(ObjectMapper json,JsonNode candidates,JsonNode playbook){
        var out=json.createArrayNode();if(!candidates.isArray())return out;int questions=0;
        for(var candidate:candidates){if(out.size()>=8)break;String kind=candidate.path("kind").asText();if(kind.equals("question")&&questions++>=3)continue;var item=json.createObjectNode().put("kind",kind);
            if(kind.equals("guidance")){item.put("title",bounded(candidate,"title",80,"下一步"));item.put("summary",bounded(candidate,"summary",800,""));item.put("version",playbook.path("revision").asLong());item.put("sourceHash",playbook.path("sourceHash").asText());item.put("workflowCode",bounded(candidate,"workflowCode",80,""));}
            else if(kind.equals("question")){item.put("key",bounded(candidate,"key",80,"next"));item.put("label",bounded(candidate,"label",200,"请补充这一步需要的信息"));item.put("hint",bounded(candidate,"hint",400,""));var options=item.putArray("options");for(var option:candidate.path("options"))if(options.size()<4&&option.isTextual()&&option.asText().length()<=80)options.add(option.asText());}
            else if(kind.equals("checklist")){item.put("title",bounded(candidate,"title",80,"待办"));var values=item.putArray("items");for(var entry:candidate.path("items"))if(values.size()<10){var row=json.createObjectNode().put("label",bounded(entry,"label",200,"待核对"));row.put("state","pending".equals(entry.path("state").asText())?"pending":"todo");values.add(row);}}
            else if(kind.equals("navigation")){String code=candidate.path("code").asText(),path=null;for(var flow:playbook.path("businessMap").path("flows"))for(var step:flow.path("steps"))if(step.path("uiEnabled").asBoolean()&&step.has("path"))for(var action:step.path("capabilities"))if(action.asText().equals(code))path=step.path("path").asText();if(path==null)continue;item.put("code",code);item.put("path",path);item.put("label",bounded(candidate,"label",80,"继续这一步"));}
            else continue;
            out.add(item);
        }return out;
    }
    private static String bounded(JsonNode node,String key,int max,String fallback){String value=node.path(key).asText(fallback).strip();return value.length()>max?value.substring(0,max):value;}
}
