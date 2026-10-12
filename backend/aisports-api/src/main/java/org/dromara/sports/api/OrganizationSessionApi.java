package org.dromara.sports.api;

import java.util.List;
import java.util.Optional;
import java.util.Set;

/**
 * 进入组织前要读的事实。映射存在不等于已经授权。
 */
public interface OrganizationSessionApi {

    /**
     * 这个后台用户是不是组织管理主体。是的话不能走密码、短信、邮箱或第三方登录。
     */
    boolean isMappedPrincipal(Long sysUserId);

    /**
     * 平台账号本期可进入的唯一组织。没有有效授权时为空。
     */
    Optional<OrganizationEntry> entryFor(Long accountId);

    /**
     * 已经开通的组织租户。登录下拉列表要藏起这些编号。
     */
    Set<String> organizerTenantIds();

    /**
     * 管理会话里的后台用户当前可管理的组织。必须有有效的 organize 授权，且组织仍是平台准入。
     */
    Optional<ManagedOrganization> managedOrganization(Long sysUserId);

    /**
     * 这个平台账号是哪些组织里唯一的有效办赛人员。空表示没有这种组织。
     */
    List<String> soleOrganizerNames(Long accountId);

    record OrganizationEntry(Long organizationId, String organizationName, String tenantId, Long sysUserId) {
    }

    record ManagedOrganization(Long organizationId, String organizationName, String tenantId, Long accountId) {
    }
}
