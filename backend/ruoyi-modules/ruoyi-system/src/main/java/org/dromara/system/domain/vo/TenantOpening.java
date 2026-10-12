package org.dromara.system.domain.vo;

/**
 * 一次开户返回的编号。调用方据此写入组织，不再按名称查找。
 */
public record TenantOpening(String tenantId, Long deptId, Long roleId, Long sysUserId) {
}
