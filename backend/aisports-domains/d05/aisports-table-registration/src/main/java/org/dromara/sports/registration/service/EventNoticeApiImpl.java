package org.dromara.sports.registration.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import lombok.RequiredArgsConstructor;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.EventNoticeApi;
import org.dromara.sports.api.FeeApi;
import org.dromara.sports.registration.domain.SportsCompetitionUnit;
import org.dromara.sports.registration.domain.SportsRegistration;
import org.dromara.sports.registration.domain.SportsRegistrationMember;
import org.dromara.sports.registration.mapper.SportsCompetitionUnitMapper;
import org.dromara.sports.registration.mapper.SportsRegistrationMapper;
import org.dromara.sports.registration.mapper.SportsRegistrationMemberMapper;
import org.springframework.stereotype.Service;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * 取消通知的收件人：待确认、已提交、已通过，以及提交人名下还有未结资金的报名。
 */
@Service
@RequiredArgsConstructor
public class EventNoticeApiImpl implements EventNoticeApi {

    private final SportsCompetitionUnitMapper unitMapper;
    private final SportsRegistrationMapper registrationMapper;
    private final SportsRegistrationMemberMapper memberMapper;
    private final FeeApi feeApi;

    @Override
    public List<Long> cancelRecipientAccountIds(String tenantId, Long eventId) {
        return TenantHelper.dynamic(tenantId, () -> {
            List<Long> unitIds = unitMapper.selectList(Wrappers.<SportsCompetitionUnit>lambdaQuery()
                    .eq(SportsCompetitionUnit::getEventId, eventId))
                .stream().map(SportsCompetitionUnit::getId).toList();
            Set<Long> accounts = new LinkedHashSet<>();
            if (unitIds.isEmpty()) {
                return List.copyOf(accounts);
            }
            List<SportsRegistration> registrations = registrationMapper.selectList(Wrappers.<SportsRegistration>lambdaQuery()
                .in(SportsRegistration::getUnitId, unitIds));
            for (SportsRegistration registration : registrations) {
                List<SportsRegistrationMember> members = memberMapper.selectList(Wrappers.<SportsRegistrationMember>lambdaQuery()
                    .eq(SportsRegistrationMember::getRegistrationId, registration.getId()));
                boolean live = "submitted".equals(registration.getStatus()) || "approved".equals(registration.getStatus());
                boolean pending = members.stream().anyMatch(member -> "pending_confirmation".equals(member.getStatus()));
                boolean money = feeApi.unsettled(tenantId, registration.getId());
                if ((live || pending || money) && registration.getSubmitterAccountId() != null) {
                    accounts.add(registration.getSubmitterAccountId());
                }
                if (live || pending) {
                    for (SportsRegistrationMember member : members) {
                        if (member.getAccountId() != null && !"declined".equals(member.getStatus())) {
                            accounts.add(member.getAccountId());
                        }
                    }
                }
            }
            return List.copyOf(accounts);
        });
    }
}
