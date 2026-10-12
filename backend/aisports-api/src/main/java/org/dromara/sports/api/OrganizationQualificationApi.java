package org.dromara.sports.api;

/**
 * 组织办赛资格。外键和租户插件不能代替这项判断。
 */
public interface OrganizationQualificationApi {

    boolean isCertified(String tenantId, Long organizationId);

    /**
     * 工作人员是否具备该组织的指定动作。动作取 staff grant 的 actions 数组。
     */
    boolean hasStaffAction(String tenantId, Long organizationId, Long accountId, String action);

    /**
     * 公开页上的承办名称和申请时留下的联系人。没有组织时各字段为空。
     */
    OrganizerContact publicContact(String tenantId, Long organizationId);

    record OrganizerContact(String organizationName, String contactName, String contactMethod) {
    }
}
