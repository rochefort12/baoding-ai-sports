package org.dromara.sports.identity.service;

import lombok.RequiredArgsConstructor;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.sports.api.PlatformAccountApi;
import org.dromara.sports.api.PlatformAccountApi.InviteCandidate;
import org.dromara.sports.api.PlatformAccountApi.MemberLabel;
import org.dromara.sports.api.PlatformAccountApi.RegistrationProfile;
import org.springframework.stereotype.Service;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

/**
 * 平台登录号里的用户号就是平台账号编号。后台用户号不能拿来冒充。
 */
@Service
@RequiredArgsConstructor
public class PlatformAccountApiImpl implements PlatformAccountApi {

    private final IdentityService identityService;

    @Override
    public Optional<Long> currentAccountId() {
        if (!org.dromara.sports.platform.core.BusinessIdentity.isLogin() || org.dromara.sports.platform.core.BusinessIdentity.getUserType() != UserType.PLATFORM_USER) {
            return Optional.empty();
        }
        return Optional.ofNullable(org.dromara.sports.platform.core.BusinessIdentity.getUserId());
    }

    @Override
    public Optional<InviteCandidate> findInviteCandidate(String phone) {
        return identityService.findInviteCandidate(phone);
    }

    @Override
    public Optional<RegistrationProfile> currentRegistrationProfile() {
        return currentAccountId().flatMap(identityService::registrationProfile);
    }

    @Override
    public List<MemberLabel> memberLabels(Collection<Long> personIds) {
        return identityService.memberLabels(personIds);
    }
}
