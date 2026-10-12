package org.dromara.sports.event.ai;

import lombok.RequiredArgsConstructor;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.api.OrganizationSessionApi.ManagedOrganization;
import org.springframework.stereotype.Component;

/**
 * 问答暂存只挂在当前进入的组织和管理人账号上。
 */
@Component
@RequiredArgsConstructor
public class OrganizerChatOwner implements ChatOwner {

    private final OrganizationSessionApi sessionApi;

    @Override
    public Owner current() {
        if (!LoginHelper.isLogin() || LoginHelper.getUserType() != UserType.SYS_USER) {
            throw new ServiceException("请先进入组织");
        }
        ManagedOrganization organization = sessionApi.managedOrganization(LoginHelper.getUserId())
            .orElseThrow(() -> new ServiceException("当前账号不能管理这个组织的赛事"));
        if (!organization.tenantId().equals(LoginHelper.getTenantId())) {
            throw new ServiceException("请先进入该组织");
        }
        return new Owner(organization.organizationId(), organization.accountId());
    }
}
