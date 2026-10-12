package org.dromara.web.service;

import cn.hutool.crypto.digest.BCrypt;
import org.dromara.common.core.domain.model.LoginUser;
import org.dromara.common.core.domain.model.PasswordLoginBody;
import org.dromara.common.core.enums.LoginType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.system.domain.vo.SysUserVo;
import org.dromara.system.mapper.SysUserMapper;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.mockito.MockedStatic;

import java.util.List;
import java.util.function.Supplier;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** 仅模拟数据库/会话边界，实际 BCrypt 校验同名凭据和认证后的租户归属。 */
@Tag("local")
class WorkAccountResolverTest {
    private static final String PASSWORD = "fixture-work-secret";
    private static final String HASH = BCrypt.hashpw(PASSWORD, BCrypt.gensalt(4));
    private final SysUserMapper mapper = mock(SysUserMapper.class);
    private final SysLoginService login = mock(SysLoginService.class);
    private final OrganizationSessionApi organizations = mock(OrganizationSessionApi.class);
    private final WorkAccountResolver resolver = new WorkAccountResolver(mapper, login, new MappedPrincipalGuard(organizations));

    private PasswordLoginBody body() {
        PasswordLoginBody value = new PasswordLoginBody();
        value.setUsername("work-person"); value.setPassword(PASSWORD);
        value.setTenantId("untrusted-other-tenant");
        return value;
    }

    private SysUserVo user(long id, String tenant, String hash, String status) {
        SysUserVo value = new SysUserVo();
        value.setUserId(id); value.setTenantId(tenant); value.setUserName("work-person");
        value.setPassword(hash); value.setStatus(status);
        value.setUserType("sys_user");
        return value;
    }

    private void withTenants(java.util.function.Consumer<MockedStatic<TenantHelper>> check) {
        try (var tenant = mockStatic(TenantHelper.class)) {
            tenant.when(() -> TenantHelper.ignore(any(Supplier.class)))
                .thenAnswer(call -> ((Supplier<?>) call.getArgument(0)).get());
            tenant.when(() -> TenantHelper.dynamic(anyString(), any(Supplier.class)))
                .thenAnswer(call -> ((Supplier<?>) call.getArgument(1)).get());
            doAnswer(call -> {
                if (((Supplier<Boolean>) call.getArgument(3)).get()) {
                    throw new ServiceException("fixture-password-failure-counted");
                }
                return null;
            }).when(login).checkLogin(eq(LoginType.PASSWORD), anyString(), eq("work-person"), any());
            check.accept(tenant);
        }
    }

    private void candidates(SysUserVo... rows) {
        when(mapper.selectVoList(any())).thenReturn(List.of(rows));
        for (SysUserVo row : rows) {
            when(mapper.selectVoById(row.getUserId())).thenReturn(row);
        }
        when(login.buildLoginUser(any())).thenAnswer(call -> {
            SysUserVo row = call.getArgument(0);
            LoginUser value = new LoginUser(); value.setUserId(row.getUserId()); value.setTenantId(row.getTenantId());
            return value;
        });
    }

    @Test void authenticatedAccountSelectsItsTenantAndIgnoresSubmittedTenant() {
        candidates(user(21, "actual-tenant", HASH, "0"));
        withTenants(tenant -> {
            LoginUser result = resolver.authenticate(body());
            assertEquals("actual-tenant", result.getTenantId());
            assertEquals(21L, result.getUserId());
            verify(login).checkTenant("actual-tenant");
            verify(login, never()).checkTenant("untrusted-other-tenant");
            tenant.verify(() -> TenantHelper.dynamic(eq("actual-tenant"), any(Supplier.class)));
        });
    }

    @Test void duplicateNamesWithDifferentPasswordsSelectOnlyActualPasswordMatch() {
        candidates(user(21, "first-tenant", BCrypt.hashpw("different-fixture", BCrypt.gensalt(4)), "0"),
            user(22, "actual-tenant", HASH, "0"));
        withTenants(tenant -> assertEquals(22L, resolver.authenticate(body()).getUserId()));
        verify(login, never()).checkTenant("first-tenant");
    }

    @Test void duplicateNamesAndSameValidPasswordNeverChooseFirstTenant() {
        candidates(user(21, "first-tenant", HASH, "0"), user(22, "second-tenant", HASH, "0"));
        withTenants(tenant -> assertEquals("该工作账号对应多个组织，请联系管理员确认账号",
            assertThrows(ServiceException.class, () -> resolver.authenticate(body())).getMessage()));
        verify(login, never()).checkTenant(anyString());
        verify(login, never()).buildLoginUser(any());
        verify(mapper, never()).selectVoById(anyLong());
    }

    @Test void incorrectPasswordUsesExistingFailureCounterAndNeverLoadsTenant() {
        candidates(user(21, "actual-tenant", HASH, "0"));
        PasswordLoginBody value = body(); value.setPassword("incorrect-fixture");
        withTenants(tenant -> assertEquals("fixture-password-failure-counted",
            assertThrows(ServiceException.class, () -> resolver.authenticate(value)).getMessage()));
        verify(login).checkLogin(eq(LoginType.PASSWORD), eq("000000"), eq("work-person"), any());
        verify(login, never()).checkTenant(anyString());
    }

    @Test void unknownAccountUsesSameFailureCounterWithoutTenantDisclosure() {
        candidates();
        withTenants(tenant -> assertEquals("fixture-password-failure-counted",
            assertThrows(ServiceException.class, () -> resolver.authenticate(body())).getMessage()));
        verify(login, never()).checkTenant(anyString());
    }

    @Test void lockedAccountDoesNotQueryCandidatesEvenWithCorrectPassword() {
        withTenants(tenant -> {
            doThrow(new ServiceException("fixture-locked")).when(login)
                .checkLogin(eq(LoginType.PASSWORD), anyString(), eq("work-person"), any());
            assertEquals("fixture-locked", assertThrows(ServiceException.class, () -> resolver.authenticate(body())).getMessage());
        });
        verifyNoInteractions(mapper, organizations);
    }

    @Test void disabledAccountNeverBuildsSession() {
        candidates(user(21, "actual-tenant", HASH, "1"));
        withTenants(tenant -> assertThrows(ServiceException.class, () -> resolver.authenticate(body())));
        verify(login, never()).buildLoginUser(any());
    }

    @Test void blockedOrExpiredActualTenantRemainsBlocked() {
        candidates(user(21, "actual-tenant", HASH, "0"));
        doThrow(new ServiceException("fixture-expired-tenant")).when(login).checkTenant("actual-tenant");
        withTenants(tenant -> assertEquals("fixture-expired-tenant",
            assertThrows(ServiceException.class, () -> resolver.authenticate(body())).getMessage()));
        verify(mapper, never()).selectVoById(anyLong());
        verify(login, never()).buildLoginUser(any());
    }

    @Test void mappedOrganizationTechnicalPrincipalCannotUseIndependentPasswordLogin() {
        candidates(user(21, "organization-tenant", HASH, "0"));
        when(organizations.isMappedPrincipal(21L)).thenReturn(true);
        withTenants(tenant -> assertEquals("组织管理账号不能直接登录，请从平台账号进入组织",
            assertThrows(ServiceException.class, () -> resolver.authenticate(body())).getMessage()));
        verify(login, never()).buildLoginUser(any());
    }

    @Test void participantLegacyPasswordCannotBecomeAnIndependentWorkSession() {
        SysUserVo participant = user(21, "100001", HASH, "0");
        participant.setUserType("app_user");
        candidates(participant);
        withTenants(tenant -> assertEquals("请使用手机号登录后进入个人或组织空间",
            assertThrows(ServiceException.class, () -> resolver.authenticate(body())).getMessage()));
        verify(login, never()).buildLoginUser(any());
    }

    @Test void platformCompatibilityTenantNeverProvidesIndependentWorkSession() {
        candidates(user(21, "900001", HASH, "0"));
        withTenants(tenant -> assertThrows(ServiceException.class, () -> resolver.authenticate(body())));
        verify(login, never()).checkTenant(anyString());
        verify(login, never()).buildLoginUser(any());
    }

    @Test void nonSystemUserInAnotherTenantCannotReceiveAWorkSession() {
        SysUserVo participant = user(21, "actual-tenant", HASH, "0"); participant.setUserType("app_user");
        candidates(participant);
        withTenants(tenant -> assertThrows(ServiceException.class, () -> resolver.authenticate(body())));
        verify(login, never()).buildLoginUser(any());
    }

    @Test void passwordChangeBetweenCandidateAndScopedReloadStopsSession() {
        candidates(user(21, "actual-tenant", HASH, "0"));
        when(mapper.selectVoById(21L)).thenReturn(user(21, "actual-tenant", BCrypt.hashpw("changed-fixture", BCrypt.gensalt(4)), "0"));
        withTenants(tenant -> assertThrows(ServiceException.class, () -> resolver.authenticate(body())));
        verify(login, never()).buildLoginUser(any());
    }

    @Test void tenantChangeBetweenCandidateAndScopedReloadStopsSession() {
        candidates(user(21, "actual-tenant", HASH, "0"));
        when(mapper.selectVoById(21L)).thenReturn(user(21, "changed-tenant", HASH, "0"));
        withTenants(tenant -> assertThrows(ServiceException.class, () -> resolver.authenticate(body())));
        verify(login, never()).buildLoginUser(any());
    }

    @Test void invalidStoredPasswordHashIsRejectedWithoutUnderlyingException() {
        candidates(user(21, "actual-tenant", "broken-fixture-hash", "0"));
        withTenants(tenant -> assertEquals("fixture-password-failure-counted",
            assertThrows(ServiceException.class, () -> resolver.authenticate(body())).getMessage()));
        verify(login, never()).checkTenant(anyString());
    }
}
