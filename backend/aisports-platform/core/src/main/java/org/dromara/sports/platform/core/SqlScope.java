package org.dromara.sports.platform.core;

import org.dromara.common.core.exception.ServiceException;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.regex.Pattern;

/** SQL is authored by modules; checking its declared tables supplements the existing row/tenant checks. */
public final class SqlScope {
    private static final Pattern TABLE = Pattern.compile("(?i)\\b(?:from|join|update|into)\\s+(?:public\\.)?\"?(asp_[a-z0-9_]+)\"?");
    private static final Pattern WRITE = Pattern.compile("(?i)\\b(?:update|insert\\s+into|delete\\s+from)\\s+(?:public\\.)?\"?(asp_[a-z0-9_]+)\"?");
    private SqlScope() { }
    public static Set<String> tables(String sql) {
        Set<String> result = new LinkedHashSet<>(); var m = TABLE.matcher(sql);
        while (m.find()) result.add(m.group(1).toLowerCase());
        return result;
    }
    public static void check(String sql, boolean mutation, boolean requireContext) {
        var tables = tables(sql); if (tables.isEmpty()) return;
        var context = ActionContext.current();
        if (context == null) {
            if (mutation && requireContext) throw new ServiceException("业务写入必须通过登记动作", 409);
            return;
        }
        Set<String> allowed = new LinkedHashSet<>(context.reads());
        allowed.addAll(context.writes());
        // Receipts and transactional outbox are executor-owned infrastructure.
        allowed.addAll(Set.of("asp_action_execution", "asp_outbox", "asp_audit_event"));
        if (!allowed.containsAll(tables)) throw new ServiceException("动作超出声明的数据范围", 403);
        if (mutation) {
            var writes = new LinkedHashSet<>(context.writes());
            writes.addAll(Set.of("asp_action_execution", "asp_outbox", "asp_audit_event"));
            var targets = WRITE.matcher(sql);
            while (targets.find()) if (!writes.contains(targets.group(1).toLowerCase()))
                throw new ServiceException("动作未声明该对象的写入权限", 403);
        }
    }
}
