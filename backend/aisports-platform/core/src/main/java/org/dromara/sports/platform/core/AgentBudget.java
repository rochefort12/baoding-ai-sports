package org.dromara.sports.platform.core;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/** Locked run limits. Malformed configuration fails closed; descendants never enlarge a parent's limits. */
public record AgentBudget(int maxDepth, int maxToolsPerTurn, int activeSeconds,
                          int maxTokensPerTurn, int maxTokensTotal, int maxChildren) {
    public static AgentBudget read(JsonNode value) {
        return new AgentBudget(limit(value,"maxDepth",3,0,3),limit(value,"maxToolsPerTurn",30,2,30),
            limit(value,"activeSeconds",300,30,300),limit(value,"maxTokensPerTurn",30000,1000,60000),
            limit(value,"maxTokensTotal",120000,1000,300000),limit(value,"maxChildren",4,0,8));
    }
    private static int limit(JsonNode value,String name,int fallback,int min,int max) {
        if(!value.has(name))return fallback;
        var n=value.get(name);
        if(!n.isIntegralNumber()||!n.canConvertToInt()||n.intValue()<min||n.intValue()>max)
            throw BusinessSupport.fail("助手预算配置无效，请联系平台核对",409);
        return n.intValue();
    }
    public AgentBudget narrow(AgentBudget parent) {
        return new AgentBudget(Math.min(maxDepth,parent.maxDepth),Math.min(maxToolsPerTurn,parent.maxToolsPerTurn),
            Math.min(activeSeconds,parent.activeSeconds),Math.min(maxTokensPerTurn,parent.maxTokensPerTurn),
            Math.min(maxTokensTotal,parent.maxTokensTotal),Math.min(maxChildren,parent.maxChildren));
    }
    public JsonNode json(ObjectMapper mapper){return mapper.valueToTree(this);}
}
