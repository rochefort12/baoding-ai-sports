package org.dromara.sports.registration;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.core.lock.MutualLock;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.*;
import org.dromara.sports.registration.domain.*;
import org.dromara.sports.registration.mapper.*;
import org.dromara.sports.registration.service.*;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.SimpleTransactionStatus;
import java.util.*;
import java.util.function.Supplier;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 实际服务规则检查，锁、事务、数据库隔离；不声称普通账号或数据库验收。 */
@Tag("local")
class RegistrationDraftAndGuideTest {
    final Map<Class<?>, Object> deps = new HashMap<>();
    final RegistrationService service = create();
    <T> T dep(Class<T> type) { return type.cast(deps.get(type)); }
    RegistrationService create() {
        try {
            var constructor = RegistrationService.class.getDeclaredConstructors()[0];
            return (RegistrationService) constructor.newInstance(Arrays.stream(constructor.getParameterTypes()).map(type -> {
                Object value = type == ObjectMapper.class ? new ObjectMapper().findAndRegisterModules() : mock(type);
                deps.put(type, value); return value;
            }).toArray());
        } catch (ReflectiveOperationException error) { throw new AssertionError(error); }
    }
    SportsRegistration prepare() {
        when(dep(PlatformAccountApi.class).currentAccountId()).thenReturn(Optional.of(201L));
        when(dep(PlatformAccountApi.class).currentRegistrationProfile()).thenReturn(Optional.of(
            new PlatformAccountApi.RegistrationProfile(201L, 301L, "隔离本人", "male", java.time.LocalDate.of(2000,1,1), "fixture")));
        var row = new SportsRegistration(); row.setId(701L); row.setTenantId("fixture"); row.setUnitId(501L);
        row.setSubmitterAccountId(201L); row.setStatus("draft"); row.setVersion(0);
        when(dep(SportsRegistrationMapper.class).selectById(701L)).thenReturn(row);
        when(dep(SportsRegistrationMapper.class).selectList(any())).thenReturn(List.of(row));
        when(dep(SportsRegistrationMapper.class).delete(any())).thenReturn(1);
        var unit = new SportsCompetitionUnit(); unit.setId(501L); unit.setEventId(601L); unit.setName("隔离项目"); unit.setStatus("open");
        unit.setEntryType("pair"); unit.setMinMembers(2); unit.setMaxMembers(2);
        when(dep(SportsCompetitionUnitMapper.class).selectById(501L)).thenReturn(unit);
        when(dep(SportsAuditEventMapper.class).insert(any(SportsAuditEvent.class))).thenReturn(1);
        var member = new SportsRegistrationMember(); member.setId(401L); member.setRegistrationId(701L);
        member.setAccountId(201L); member.setStatus("confirmed"); member.setOccupying(false); member.setInviteToken("private-token");
        member.setPersonSnapshot("{\"legalName\":\"private-name\",\"health\":\"private-health\"}");
        when(dep(SportsRegistrationMemberMapper.class).selectList(any())).thenReturn(List.of(member));
        when(dep(FeeApi.class).current("fixture",701L)).thenReturn(Optional.empty());
        when(dep(PlatformTransactionManager.class).getTransaction(any())).thenReturn(new SimpleTransactionStatus());
        when(dep(MutualLock.class).execute(anyString(), anyLong(), anyLong(), any(Supplier.class)))
            .thenAnswer(call -> ((Supplier<?>) call.getArgument(3)).get());
        return row;
    }
    void withTenant(Runnable run) {
        try (var tenant = mockStatic(TenantHelper.class)) {
            tenant.when(() -> TenantHelper.ignore(any(Supplier.class))).thenAnswer(call -> ((Supplier<?>)call.getArgument(0)).get());
            tenant.when(() -> TenantHelper.dynamic(anyString(), any(Supplier.class))).thenAnswer(call -> ((Supplier<?>)call.getArgument(1)).get());
            run.run();
        }
    }
    @Test void cleanDraftDeletesMembersAndValuesWithoutTouchingCapacityOrMoney() {
        prepare(); withTenant(() -> service.deleteDraft(701L));
        verify(dep(SportsRegistrationMemberMapper.class)).delete(any());
        verify(dep(SportsRegistrationMapper.class)).delete(any());
        verifyNoInteractions(dep(SportsCapacityPoolMapper.class), dep(CompetitionWithdrawalApi.class));
        verify(dep(FeeApi.class)).current("fixture",701L);
        verify(dep(PlatformTransactionManager.class)).commit(any());
        verify(dep(SportsAuditEventMapper.class)).insert(any(SportsAuditEvent.class));
    }
    @Test void foreignSubmitterCannotDelete() {
        prepare().setSubmitterAccountId(999L); withTenant(() -> assertThrows(ServiceException.class, () -> service.deleteDraft(701L)));
        verifyNoInteractions(dep(MutualLock.class)); verify(dep(SportsRegistrationMapper.class), never()).delete(any());
    }
    @Test void submittedOrWithdrawnHistoryCannotBeDeleted() {
        var row=prepare(); row.setStatus("submitted"); withTenant(() -> assertThrows(ServiceException.class, () -> service.deleteDraft(701L)));
        row.setStatus("draft"); row.setSubmittedAt(java.time.OffsetDateTime.now());
        withTenant(() -> assertThrows(ServiceException.class, () -> service.deleteDraft(701L)));
        verify(dep(SportsRegistrationMemberMapper.class), never()).delete(any());
    }
    @Test void historicalSubmitKeyBlocksDeletionEvenIfSubmittedTimeMissing() {
        prepare(); when(dep(SportsRegistrationSubmitKeyMapper.class).exists(any())).thenReturn(true);
        withTenant(() -> assertThrows(ServiceException.class, () -> service.deleteDraft(701L)));
        verify(dep(SportsRegistrationMapper.class), never()).delete(any());
    }
    @Test void captainTransferRevokesOldCaptainsDeletion() {
        prepare().setTeamId(801L); when(dep(TeamMembershipApi.class).isActiveCaptain(801L,301L)).thenReturn(false);
        withTenant(() -> assertThrows(ServiceException.class, () -> service.deleteDraft(701L)));
        verify(dep(SportsRegistrationMapper.class), never()).delete(any());
    }
    @Test void anyPaymentObligationBlocksDraftDeletion() {
        prepare(); when(dep(FeeApi.class).current("fixture",701L)).thenReturn(Optional.of(mock(FeeApi.ObligationView.class)));
        withTenant(() -> assertThrows(ServiceException.class, () -> service.deleteDraft(701L)));
        verify(dep(SportsRegistrationMemberMapper.class), never()).delete(any());
    }
    @Test void optimisticConflictRollsBackDeletionOfChildren() {
        prepare(); when(dep(SportsRegistrationMapper.class).delete(any())).thenReturn(0);
        withTenant(() -> assertThrows(ServiceException.class, () -> service.deleteDraft(701L)));
        verify(dep(PlatformTransactionManager.class)).rollback(any());
        verifyNoInteractions(dep(SportsAuditEventMapper.class));
    }
    @Test void concurrentSubmitRecheckedInsideLockAndStopsDeletion() {
        var row=prepare(); var submitted=new SportsRegistration(); submitted.setSubmitterAccountId(201L); submitted.setStatus("submitted");
        when(dep(SportsRegistrationMapper.class).selectById(701L)).thenReturn(row, submitted);
        withTenant(() -> assertThrows(ServiceException.class, () -> service.deleteDraft(701L)));
        verify(dep(SportsRegistrationMapper.class), never()).delete(any());
    }
    @Test void guideCountsOwnedEntryButDoesNotExposeMemberPrivateData() {
        prepare(); withTenant(() -> {
            try {
                var data=dep(ObjectMapper.class).readTree(service.guideSnapshot(201L,0));
                assertEquals(1,data.path("total").asInt()); assertEquals("draft",data.path("entries").get(0).path("status").asText());
                assertFalse(data.toString().contains("private-"));
                var beyond=dep(ObjectMapper.class).readTree(service.guideSnapshot(201L,999));
                assertEquals(1,beyond.path("total").asInt()); assertTrue(beyond.path("entries").isEmpty());
            } catch(Exception error) { throw new AssertionError(error); }
        });
    }
    @Test void anonymousGuideDoesNotReadDatabase() {
        assertEquals("{\"loggedIn\":false}", service.guideSnapshot(null,0));
        verifyNoInteractions(dep(SportsRegistrationMapper.class),dep(SportsRegistrationMemberMapper.class));
    }
}
