package org.dromara.sports.api;

import java.util.List;
import java.util.Optional;

/**
 * 长期队伍的当前事实。报名只用这份契约核对，不读取队伍表。
 * 有实现之后才表示当前有效成员和当前队长。
 */
public interface TeamMembershipApi {

    Optional<ActiveTeam> findActive(Long teamId);

    boolean isActiveCaptain(Long teamId, Long personId);

    boolean containsActiveMembers(Long teamId, List<Long> personIds);

    boolean containsActiveAccounts(Long teamId, List<Long> accountIds);

    List<Long> activeCaptainTeamIds(Long personId);

    /**
     * 代表队伍提交前看当前状态。队伍已解散、操作者不是队长，或名单里有人已离队时失败。
     */
    void requireSubmittable(Long teamId, Long captainPersonId, List<Long> personIds);

    record ActiveTeam(Long teamId, String name, Long captainPersonId) {
    }
}
