package org.dromara.sports.platform.core;

import java.util.Set;

/** MCP authenticates a private run credential through this contract; models never choose the actor. */
public interface AgentRunAccess {
    RunPrincipal authorize(String token);
    default com.fasterxml.jackson.databind.JsonNode playbook(){return new com.fasterxml.jackson.databind.ObjectMapper().createObjectNode();}
    com.fasterxml.jackson.databind.JsonNode propose(String code,com.fasterxml.jackson.databind.JsonNode input);
    com.fasterxml.jackson.databind.JsonNode delegate(String agentCode,String goal);
    /** Bounded, currently authorized visible outcomes; neither method can choose an unrelated run. */
    default com.fasterxml.jackson.databind.JsonNode children(int waitSeconds){throw BusinessSupport.fail("此版本尚不支持委派结果读取",409);}
    default com.fasterxml.jackson.databind.JsonNode recovery(){throw BusinessSupport.fail("此版本尚不支持办理回执恢复",409);}
    void tool(String name,String status);
    default void tool(String name,String status,com.fasterxml.jackson.databind.JsonNode input,String requestKey){tool(name,status);}
    default String requestKey(String code,com.fasterxml.jackson.databind.JsonNode input,String suggested){return suggested;}
    default void toolCompleted(String name,String status) { }
    default void toolCompleted(String name,String status,com.fasterxml.jackson.databind.JsonNode input,
                               com.fasterxml.jackson.databind.JsonNode result,String requestKey){toolCompleted(name,status);}
    record RunPrincipal(Long runId, String actorType, Long actorId, String tenantId,
                        Long organizationId, Set<String> capabilities, String scopeJson) { }
}
