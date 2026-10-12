package org.dromara.sports.platform.core;

import com.fasterxml.jackson.databind.JsonNode;
import java.util.List;

/** Implementation belongs to its entry-table module; the registry never imports it. */
public interface CapabilityProvider {
    List<CapabilityDefinition> capabilities();
    JsonNode preview(String code, JsonNode input);
    JsonNode execute(String code, JsonNode input);
}
