package org.dromara.sports.api;
/** Exact organization grants, with live expiry/revocation. A government role alone grants no object access. */
public interface GovernanceScopeApi { boolean allows(Long sysUserId,Long organizationId,String permission); }
