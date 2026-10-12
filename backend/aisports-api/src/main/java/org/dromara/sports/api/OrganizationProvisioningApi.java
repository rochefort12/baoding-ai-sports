package org.dromara.sports.api;

/** Framework tenant provisioning is an assembly adapter, not a table-to-framework implementation dependency. */
public interface OrganizationProvisioningApi {
    Opening open(String organizationName, String contactName, Long packageId, Long accountId);
    record Opening(String tenantId, Long sysUserId) { }
}
