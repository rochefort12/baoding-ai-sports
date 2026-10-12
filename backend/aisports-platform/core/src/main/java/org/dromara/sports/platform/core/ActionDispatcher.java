package org.dromara.sports.platform.core;

import com.fasterxml.jackson.databind.JsonNode;
import java.util.List;

/** Server derives actor/channel. Browser only supplies business input and a stable retry key. */
public interface ActionDispatcher {
    List<CapabilityDefinition> available();
    /** Metadata for current-role guidance; this does not grant an Agent channel or execute a business query. */
    default JsonNode guidance(){return new com.fasterxml.jackson.databind.ObjectMapper().createArrayNode();}
    JsonNode preview(String code, JsonNode input);
    JsonNode execute(String code, JsonNode input, String requestKey, Long confirmationId);
    /** Receipt recovery still uses the caller's current role, channel and object authorization. */
    default JsonNode lookup(String code,String requestKey){throw BusinessSupport.fail("该回执暂不可查询",409);}
}
