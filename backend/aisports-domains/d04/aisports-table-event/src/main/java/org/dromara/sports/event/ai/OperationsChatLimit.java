package org.dromara.sports.event.ai;

import java.util.ArrayList;
import java.util.List;

/**
 * 决定新开一段时要删掉哪些更早的问答。列表按最近写入在前。
 */
public final class OperationsChatLimit {

    private OperationsChatLimit() {
    }

    public static List<String> overflow(List<String> newestFirst, String incomingId, int limit) {
        int cap = limit < 1 ? 1 : Math.min(limit, 50);
        List<String> drop = new ArrayList<>();
        int kept = incomingId == null || incomingId.isBlank() ? 0 : 1;
        for (String id : newestFirst) {
            if (id == null || id.isBlank() || id.equals(incomingId)) {
                continue;
            }
            if (kept < cap) {
                kept++;
            } else {
                drop.add(id);
            }
        }
        return drop;
    }
}
