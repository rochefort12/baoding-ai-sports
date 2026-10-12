package org.dromara.sports.api;

import java.util.List;
import java.util.Optional;

/**
 * 已通过资格审核的报名名单。录分和发证只引用这份快照。
 */
public interface RegistrationRosterApi {

    Optional<RosterSnapshot> findValidRoster(String tenantId, Long registrationId);

    /**
     * 已通过且名单已冻结的报名。证明资格只读这份名单，不读当前队伍。
     */
    Optional<RosterView> approvedRoster(String tenantId, Long registrationId);

    List<RosterView> approvedRosters(String tenantId, Long eventId);

    List<RosterView> approvedRostersForUnit(String tenantId, Long unitId);

    /**
     * 这个人出现在哪些已冻结名单里。只返回报名编号，不返回其他成员。
     */
    List<Long> registrationIdsForPerson(Long personId);

    record RosterSnapshot(Long registrationId, Long rosterVersionId, Long unitId, Long eventId,
                           List<Long> personIds, String status) {
    }

    record RosterPerson(Long personId, String legalName) {
    }

    record RosterView(Long registrationId, Long rosterVersionId, Long unitId, Long eventId, String unitName,
                      List<RosterPerson> people) {
    }
}
