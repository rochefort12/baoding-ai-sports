package org.dromara.sports.platform.core;

import java.util.Set;

/** Actor and scope are server-issued; none of these values are taken from model arguments. */
public record ActionContext(String actionCode, String actorType, Long actorId, String tenantId,
                            String channel, String requestKey, String payloadHash,
                            Long runId, Set<String> reads, Set<String> writes) {
    private static final ThreadLocal<ActionContext> CURRENT = new ThreadLocal<>();
    public static ActionContext current() { return CURRENT.get(); }
    public static void bind(ActionContext context) { CURRENT.set(context); }
    public static void clear() { CURRENT.remove(); }
}
