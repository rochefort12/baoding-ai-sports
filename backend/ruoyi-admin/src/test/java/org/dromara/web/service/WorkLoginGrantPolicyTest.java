package org.dromara.web.service;

import org.dromara.web.domain.vo.WorkLoginMethodsVo;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

/** 别名必须使用既有密码授权，微信未验证通道不因配置字符串存在而伪开放。 */
@Tag("local")
class WorkLoginGrantPolicyTest {
    @Test void existingPasswordGrantAllowsOnlyItsWorkAlias() {
        assertTrue(WorkLoginGrantPolicy.permits("password,social,platform", "work-password"));
        assertFalse(WorkLoginGrantPolicy.permits("social,platform", "work-password"));
    }
    @Test void fullGrantNamesAreRequired() {
        assertFalse(WorkLoginGrantPolicy.permits("work-password", "work-password"));
        assertFalse(WorkLoginGrantPolicy.permits("password", "pass"));
        assertFalse(WorkLoginGrantPolicy.permits("social", "soc"));
    }
    @Test void normalExistingGrantsAndWhitespaceRemainCompatible() {
        assertTrue(WorkLoginGrantPolicy.permits("password, social, platform", "password"));
        assertTrue(WorkLoginGrantPolicy.permits("password, social, platform", "social"));
        assertTrue(WorkLoginGrantPolicy.permits("password, social, platform", "platform"));
    }
    @Test void nullAndBlankAuthorizationCannotAuthenticate() {
        assertFalse(WorkLoginGrantPolicy.permits(null, "work-password"));
        assertFalse(WorkLoginGrantPolicy.permits("", "work-password"));
        assertFalse(WorkLoginGrantPolicy.permits("password", null));
        assertFalse(WorkLoginGrantPolicy.permits("password", " "));
    }
    @Test void tenantResolutionExceptionAppliesOnlyToExplicitWorkPassword() {
        assertTrue(WorkLoginGrantPolicy.requiresAccountTenantResolution("work-password"));
        assertFalse(WorkLoginGrantPolicy.requiresAccountTenantResolution("password"));
        assertFalse(WorkLoginGrantPolicy.requiresAccountTenantResolution("platform"));
        assertFalse(WorkLoginGrantPolicy.requiresAccountTenantResolution("social"));
    }
    @Test void workWechatRemainsClosedBeforeRealProviderAndPrincipalVerification() {
        WorkLoginMethodsVo result = WorkLoginMethodsVo.current();
        assertNotNull(result.wechat());
        assertFalse(result.wechat().available());
    }
}
