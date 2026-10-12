package org.dromara.sports.organization.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.sports.api.OrganizationQualificationApi;
import org.dromara.sports.api.OrganizationSessionApi;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** 办赛工作台当前身份。每次按有效授权查询，不接受客户端组织编号或角色开关。 */
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/b/desk")
public class OrganizationDeskController {
    private final OrganizationSessionApi sessionApi;
    private final OrganizationQualificationApi qualificationApi;

    @GetMapping("/context")
    public R<DeskContext> context() {
        if (LoginHelper.getUserType() == UserType.PLATFORM_USER) {
            throw new ServiceException("请先进入办赛组织");
        }
        var organization = sessionApi.managedOrganization(LoginHelper.getUserId())
            .orElseThrow(() -> new ServiceException("当前账号没有有效办赛授权"));
        if (!organization.tenantId().equals(LoginHelper.getTenantId())) {
            throw new ServiceException("组织会话不匹配，请重新进入");
        }
        boolean payment = qualificationApi.hasStaffAction(organization.tenantId(), organization.organizationId(),
            organization.accountId(), "payment");
        return R.ok(new DeskContext(organization.organizationId(), organization.organizationName(), true, payment));
    }

    public record DeskContext(Long organizationId, String organizationName, boolean organize, boolean payment) { }
}
