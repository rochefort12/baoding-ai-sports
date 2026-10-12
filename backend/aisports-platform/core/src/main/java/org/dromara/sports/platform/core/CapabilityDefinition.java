package org.dromara.sports.platform.core;

import com.fasterxml.jackson.databind.JsonNode;
import java.util.Set;

/** Published capability contract shared by pages, MCP and the runtime. */
public record CapabilityDefinition(String code, String title, String ownerTable, String description,
                                   boolean mutation, boolean agent, boolean confirmation,
                                   Set<String> actorTypes, String permission, Set<String> reads,
                                   Set<String> writes, JsonNode inputSchema) { }
