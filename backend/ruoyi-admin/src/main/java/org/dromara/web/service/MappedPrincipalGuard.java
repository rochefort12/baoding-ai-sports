package org.dromara.web.service;

import lombok.RequiredArgsConstructor;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.api.OrganizationSessionApi;
import org.springframework.stereotype.Component;

/**
 * 组织管理主体没有独立登录。密码被改掉也不能从这里进来。
 */
@Component
@RequiredArgsConstructor
public class MappedPrincipalGuard {

    private final OrganizationSessionApi organizationSessionApi;

    public void rejectDirectLogin(Long sysUserId) {
        if (sysUserId != null && organizationSessionApi.isMappedPrincipal(sysUserId)) {
            throw new ServiceException("组织管理账号不能直接登录，请从平台账号进入组织");
        }
    }
}
