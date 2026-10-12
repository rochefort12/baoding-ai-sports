package org.dromara.web.service;

import lombok.RequiredArgsConstructor;
import org.dromara.sports.api.OrganizationProvisioningApi;
import org.dromara.system.service.ISysTenantService;
import org.springframework.stereotype.Service;

/** Composition adapter keeps the upstream tenant implementation outside table-module dependencies. */
@Service
@RequiredArgsConstructor
public class SportsOrganizationProvisioning implements OrganizationProvisioningApi {
    private final ISysTenantService tenants;
    public Opening open(String organizationName, String contactName, Long packageId, Long accountId) {
        var opened = tenants.openForPlatformAccount(organizationName, contactName, packageId, accountId);
        return new Opening(opened.tenantId(), opened.sysUserId());
    }
}
