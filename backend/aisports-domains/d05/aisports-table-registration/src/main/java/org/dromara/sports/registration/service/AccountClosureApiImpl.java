package org.dromara.sports.registration.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.AccountClosureApi;
import org.dromara.sports.api.FeeApi;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.api.TeamMembershipApi;
import org.springframework.context.annotation.Lazy;
import org.dromara.sports.registration.domain.SportsRegistration;
import org.dromara.sports.registration.domain.SportsRegistrationMember;
import org.dromara.sports.registration.mapper.SportsRegistrationMapper;
import org.dromara.sports.registration.mapper.SportsRegistrationMemberMapper;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * 注销保留未收尾责任；完整收尾的历史报名可保留档案而不永久阻止注销。
 */
@Service
public class AccountClosureApiImpl implements AccountClosureApi {

    private final SportsRegistrationMapper registrationMapper;
    private final SportsRegistrationMemberMapper memberMapper;
    private final TeamMembershipApi teamMembershipApi;
    private final FeeApi feeApi;
    private final OrganizationSessionApi sessionApi;
    private final org.dromara.sports.platform.core.ScopedJdbc db;

    public AccountClosureApiImpl(SportsRegistrationMapper registrationMapper,
                                  SportsRegistrationMemberMapper memberMapper,
                                  @Lazy TeamMembershipApi teamMembershipApi,
                                  FeeApi feeApi,
                                  OrganizationSessionApi sessionApi,
                                  org.dromara.sports.platform.core.ScopedJdbc db) {
        this.registrationMapper = registrationMapper;
        this.memberMapper = memberMapper;
        this.teamMembershipApi = teamMembershipApi;
        this.feeApi = feeApi;
        this.sessionApi = sessionApi;
        this.db = db;
    }

    @Override
    public List<String> blocks(Long accountId, Long personId) {
        List<String> blocks = new ArrayList<>();
        Set<Long> closed = new java.util.HashSet<>();
        for (var row : db.list("SELECT r.id FROM asp_registration r JOIN asp_competition_unit u ON u.id=r.unit_id JOIN asp_event e ON e.id=u.event_id WHERE e.closure_status='closed' AND (r.manager_account_id=? OR r.submitter_account_id=? OR EXISTS(SELECT 1 FROM asp_registration_member m WHERE m.registration_id=r.id AND m.account_id=?))",accountId,accountId,accountId)) {
            closed.add(((Number)row.get("id")).longValue());
        }
        List<SportsRegistration> owned = TenantHelper.ignore(() -> registrationMapper.selectList(Wrappers.<SportsRegistration>lambdaQuery()
            .and(q -> q.eq(SportsRegistration::getSubmitterAccountId, accountId).or().eq(SportsRegistration::getManagerAccountId, accountId))));
        long active = owned.stream().filter(row -> !closed.contains(row.getId()) && ("submitted".equals(row.getStatus()) || "approved".equals(row.getStatus()))).count();
        if (active > 0) {
            blocks.add("还有 " + active + " 条已提交或已通过的报名");
        }
        Set<Long> counted = new LinkedHashSet<>();
        owned.stream().filter(row -> "submitted".equals(row.getStatus()) || "approved".equals(row.getStatus()))
            .forEach(row -> counted.add(row.getId()));
        List<SportsRegistrationMember> memberships = TenantHelper.ignore(() -> memberMapper.selectList(Wrappers.<SportsRegistrationMember>lambdaQuery()
            .eq(SportsRegistrationMember::getAccountId, accountId)
            .eq(SportsRegistrationMember::getOccupying, true)));
        long extra = memberships.stream().filter(member -> !closed.contains(member.getRegistrationId()) && !counted.contains(member.getRegistrationId())).count();
        if (extra > 0) {
            blocks.add("还在 " + extra + " 条报名名单里");
        }
        if (personId != null && !teamMembershipApi.activeCaptainTeamIds(personId).isEmpty()) {
            blocks.add("还是队伍队长，请先移交队长");
        }
        List<String> sole = sessionApi.soleOrganizerNames(accountId);
        if (!sole.isEmpty()) {
            blocks.add("还是这些组织的唯一办赛人员：" + String.join("、", sole));
        }
        int unsettled = 0;
        for (SportsRegistration registration : owned) {
            if (registration.getTenantId() != null && feeApi.unsettled(registration.getTenantId(), registration.getId())) {
                unsettled++;
            }
        }
        if (unsettled > 0) {
            blocks.add("还有 " + unsettled + " 笔未结清的收费或退款");
        }
        return blocks;
    }
}
