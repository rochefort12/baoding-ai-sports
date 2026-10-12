package org.dromara.sports.platform.core;

/** Bound only after the MCP transport validates a server-issued run token. */
public final class TrustedRunContext {
    private static final ThreadLocal<AgentRunAccess.RunPrincipal> CURRENT = new ThreadLocal<>();
    private TrustedRunContext() { }
    public static AgentRunAccess.RunPrincipal current() { return CURRENT.get(); }
    public static void bind(AgentRunAccess.RunPrincipal value) { CURRENT.set(value); }
    public static void clear() { CURRENT.remove(); }
}
