package org.dromara.sports.api;

import java.util.Collection;

/**
 * 已通过报名能否整单撤回。场次和报到留在竞赛模块，报名模块不直接查那些表。
 */
public interface CompetitionWithdrawalApi {

    /**
     * 仍有场次引用这单报名，或名单上的人在本项目已有有效报到时返回 true。
     * 项目未知的旧赛事级报到保守阻止撤回，不能推断为已在每个项目报到。
     */
    boolean blocksFullWithdrawal(String tenantId, Long eventId, Long unitId, Long registrationId, Collection<Long> personIds);
}
