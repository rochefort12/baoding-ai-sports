package org.dromara.sports.registration.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.EventRegistrationApi;
import org.dromara.sports.api.PlatformAccountApi;
import org.dromara.sports.api.StoredObjectApi;
import org.dromara.sports.registration.domain.SportsCompetitionUnit;
import org.dromara.sports.registration.domain.SportsRegistration;
import org.dromara.sports.registration.domain.SportsRegistrationMember;
import org.dromara.sports.registration.mapper.SportsCompetitionUnitMapper;
import org.dromara.sports.registration.mapper.SportsRegistrationMapper;
import org.dromara.sports.registration.mapper.SportsRegistrationMemberMapper;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.util.*;
import java.util.function.Supplier;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 模拟依赖只验证报名/成员/用途的授权边界，不代替真实文件及普通角色HTTP。 */
@Tag("local")
class RegistrationDeclarationImageTest {
    private final Map<Class<?>, Object> deps = new HashMap<>();
    private final RegistrationService service = create();
    private <T> T dep(Class<T> type) { return type.cast(deps.get(type)); }
    private RegistrationService create() {
        try {
            var constructor = RegistrationService.class.getDeclaredConstructors()[0];
            return (RegistrationService) constructor.newInstance(Arrays.stream(constructor.getParameterTypes()).map(type -> {
                Object value = type == ObjectMapper.class ? new ObjectMapper() : mock(type);
                deps.put(type, value); return value;
            }).toArray());
        } catch (ReflectiveOperationException error) { throw new AssertionError(error); }
    }
    private void facts(String memberStatus, String entryStatus, long manager) {
        when(dep(PlatformAccountApi.class).currentAccountId()).thenReturn(Optional.of(201L));
        var registration = new SportsRegistration(); registration.setId(701L); registration.setUnitId(501L);
        registration.setManagerAccountId(manager); registration.setStatus(entryStatus); registration.setTenantId("owned-tenant");
        when(dep(SportsRegistrationMapper.class).selectById(701L)).thenReturn(registration);
        if (memberStatus != null) {
            var member = new SportsRegistrationMember(); member.setRegistrationId(701L); member.setAccountId(201L); member.setStatus(memberStatus);
            when(dep(SportsRegistrationMemberMapper.class).selectOne(any())).thenReturn(member);
        }
        var unit = new SportsCompetitionUnit(); unit.setId(501L); unit.setEventId(401L);
        when(dep(SportsCompetitionUnitMapper.class).selectById(501L)).thenReturn(unit);
        when(dep(EventRegistrationApi.class).declaration(401L)).thenReturn(Optional.of(new EventRegistrationApi.DeclarationNotice(true, "", 301L)));
        when(dep(StoredObjectApi.class).readOwned(301L,"owned-tenant")).thenReturn(new StoredObjectApi.ImageBody("image/png",new byte[]{1,2}));
    }
    private void ignoring(Runnable assertion) {
        try (var tenant = mockStatic(TenantHelper.class)) {
            tenant.when(() -> TenantHelper.ignore(any(Supplier.class))).thenAnswer(i -> ((Supplier<?>)i.getArgument(0)).get());
            assertion.run();
        }
    }
    @Test void anonymousStopsBeforeDatabaseAndStorage() {
        when(dep(PlatformAccountApi.class).currentAccountId()).thenReturn(Optional.empty());
        assertThrows(ServiceException.class, () -> service.declarationImage(701L));
        verifyNoInteractions(dep(SportsRegistrationMapper.class),dep(StoredObjectApi.class));
    }
    @Test void unrelatedAccountCannotReadEventOrStorage() {
        facts(null,"draft",999L); ignoring(() -> assertThrows(ServiceException.class, () -> service.declarationImage(701L)));
        verifyNoInteractions(dep(SportsCompetitionUnitMapper.class),dep(EventRegistrationApi.class),dep(StoredObjectApi.class));
    }
    @Test void declinedMemberCannotReadDeclaration() {
        facts("declined","draft",999L); ignoring(() -> assertThrows(ServiceException.class, () -> service.declarationImage(701L)));
        verifyNoInteractions(dep(StoredObjectApi.class));
    }
    @Test void stalePendingInviteCannotReadSubmittedEntry() {
        facts("pending_confirmation","submitted",999L); ignoring(() -> assertThrows(ServiceException.class, () -> service.declarationImage(701L)));
        verifyNoInteractions(dep(StoredObjectApi.class));
    }
    @Test void validPendingInviteReadsOnlyBoundDeclarationPurposeAndTenant() {
        facts("pending_confirmation","draft",999L); ignoring(() -> assertArrayEquals(new byte[]{1,2},service.declarationImage(701L).body()));
        verify(dep(StoredObjectApi.class)).requireImage(301L,StoredObjectApi.EVENT_DECLARATION,"owned-tenant");
        verify(dep(StoredObjectApi.class)).readOwned(301L,"owned-tenant");
    }
    @Test void confirmedMemberCanReadHistoricalStatement() {
        facts("confirmed","withdrawn",999L); ignoring(() -> assertEquals("image/png",service.declarationImage(701L).contentType()));
    }
    @Test void ManagerCanReadWithoutBeingAnActiveRosterMember() {
        facts(null,"submitted",201L); ignoring(() -> assertNotNull(service.declarationImage(701L)));
    }
    @Test void WrongPurposeStopsBeforeReadingBytes() {
        facts("confirmed","draft",999L);
        doThrow(new ServiceException("用途不符")).when(dep(StoredObjectApi.class)).requireImage(301L,StoredObjectApi.EVENT_DECLARATION,"owned-tenant");
        ignoring(() -> assertThrows(ServiceException.class, () -> service.declarationImage(701L)));
        verify(dep(StoredObjectApi.class),never()).readOwned(anyLong(),anyString());
    }
    @Test void storageFailurePropagatesWithoutAnEmptySuccessImage() {
        facts("confirmed","draft",999L);
        when(dep(StoredObjectApi.class).readOwned(301L,"owned-tenant")).thenThrow(new ServiceException("存储不可用"));
        ignoring(() -> assertThrows(ServiceException.class, () -> service.declarationImage(701L)));
    }
}
