package org.dromara.sports.competition.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import lombok.RequiredArgsConstructor;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.CompetitionWithdrawalApi;
import org.dromara.sports.competition.domain.CompetitionCheckin;
import org.dromara.sports.competition.domain.CompetitionMatchEntry;
import org.dromara.sports.competition.mapper.CompetitionCheckinMapper;
import org.dromara.sports.competition.mapper.CompetitionMatchEntryMapper;
import org.springframework.stereotype.Service;

import java.util.Collection;
import java.util.List;

/**
 * 已通过报名的整单撤回只看场次引用和有效报到，不改竞赛数据。
 */
@Service
@RequiredArgsConstructor
public class CompetitionWithdrawalApiImpl implements CompetitionWithdrawalApi {

    private final CompetitionMatchEntryMapper matchEntryMapper;
    private final CompetitionCheckinMapper checkinMapper;

    @Override
    public boolean blocksFullWithdrawal(String tenantId, Long eventId, Long unitId, Long registrationId, Collection<Long> personIds) {
        if (tenantId == null || eventId == null || unitId == null || registrationId == null) {
            return true;
        }
        return TenantHelper.dynamic(tenantId, () -> {
            Long matches = matchEntryMapper.selectCount(Wrappers.<CompetitionMatchEntry>lambdaQuery()
                .eq(CompetitionMatchEntry::getRegistrationId, registrationId)
                .ne(CompetitionMatchEntry::getStatus, "withdrawn"));
            if (matches != null && matches > 0) {
                return true;
            }
            List<Long> people = personIds == null ? List.of() : personIds.stream().filter(id -> id != null).distinct().toList();
            if (people.isEmpty()) {
                return false;
            }
            Long arrived = checkinMapper.selectCount(Wrappers.<CompetitionCheckin>lambdaQuery()
                .eq(CompetitionCheckin::getEventId, eventId)
                .and(scope -> scope.eq(CompetitionCheckin::getUnitId, unitId).or().isNull(CompetitionCheckin::getUnitId))
                .eq(CompetitionCheckin::getStatus, "confirmed")
                .in(CompetitionCheckin::getPersonId, people));
            return arrived != null && arrived > 0;
        });
    }
}
