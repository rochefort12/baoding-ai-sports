package org.dromara.sports.event.ai;

import com.fasterxml.jackson.databind.ObjectMapper;

/** Explicit source re-read is allowed only before any human draft edit. */
final class AiSourceRefreshPolicy {
    private AiSourceRefreshPolicy() { }
    static boolean canRefresh(String proposal, ObjectMapper mapper) {
        try {
            var root = mapper.readTree(proposal == null ? "{}" : proposal);
            for (var turn : root.path("dialogue")) if ("user".equals(turn.path("role").asText())) return false;
            return true;
        } catch (Exception error) { return false; }
    }
}
