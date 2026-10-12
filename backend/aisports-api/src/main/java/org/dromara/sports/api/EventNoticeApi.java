package org.dromara.sports.api;

import java.util.List;

/**
 * 赛事取消要通知的平台账号。赛事模块不直接查报名表。
 */
public interface EventNoticeApi {

    List<Long> cancelRecipientAccountIds(String tenantId, Long eventId);
}
