package org.dromara.sports.event.ai;

import java.time.OffsetDateTime;
import java.util.List;

/**
 * 运营问答暂存。键由服务端的组织和账号组成，调用方不能指定别人的编号。
 */
public interface OperationsChatStore {

    Held remember(long organizationId, long accountId, String sessionId, String userText, String reply);

    Held read(long organizationId, long accountId, String sessionId);

    List<Summary> list(long organizationId, long accountId);

    int sessionLimit();

    void discard(long organizationId, long accountId, String sessionId);

    record Held(String sessionId, OffsetDateTime expiresAt, List<OperationsChatDocument.Turn> turns, boolean retained) {
        public static Held missed(String sessionId) {
            return new Held(sessionId, null, List.of(), false);
        }
    }

    record Summary(String sessionId, String preview, OffsetDateTime expiresAt) {
    }
}
