package org.dromara.sports.registration;

import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.core.lock.MutualLock;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.EventRegistrationApi;
import org.dromara.sports.api.FeeApi;
import org.dromara.sports.registration.domain.SportsCompetitionUnit;
import org.dromara.sports.registration.domain.SportsRegistration;
import org.dromara.sports.registration.mapper.SportsCompetitionUnitMapper;
import org.dromara.sports.registration.mapper.SportsRegistrationMapper;
import org.dromara.sports.registration.service.RegistrationService;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.TransactionStatus;

import java.time.OffsetDateTime;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.function.Supplier;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 调用实际人工审核服务，防止绕过页面在开赛后取得资格。数据库和锁执行器隔离。 */
@Tag("local")
class RegistrationApprovalWindowTest {
    private final Map<Class<?>, Object> dependencies = new HashMap<>();
    private final RegistrationService service = create();

    private RegistrationService create() {
        try {
            var constructor = RegistrationService.class.getDeclaredConstructors()[0];
            return (RegistrationService) constructor.newInstance(Arrays.stream(constructor.getParameterTypes()).map(type -> {
                Object dependency = mock(type);
                dependencies.put(type, dependency);
                return dependency;
            }).toArray());
        } catch (ReflectiveOperationException exception) {
            throw new AssertionError(exception);
        }
    }

    private <T> T dependency(Class<T> type) { return type.cast(dependencies.get(type)); }

    private void prepare(OffsetDateTime startsAt, String holdingStatus) {
        var registration = new SportsRegistration();
        registration.setId(701L); registration.setTenantId("fixture"); registration.setUnitId(501L);
        registration.setStatus("submitted");
        when(dependency(SportsRegistrationMapper.class).selectById(701L)).thenReturn(registration);
        var unit = new SportsCompetitionUnit(); unit.setId(501L); unit.setEventId(901L);
        when(dependency(SportsCompetitionUnitMapper.class).selectById(501L)).thenReturn(unit);
        when(dependency(EventRegistrationApi.class).managedGate(901L)).thenReturn(Optional.of(
            new EventRegistrationApi.EventRegistrationGate(901L, "fixture", 601L, "隔离赛事", "published",
                holdingStatus, startsAt.minusDays(7), startsAt.minusDays(1), startsAt, startsAt.plusDays(1), "manual", true)));
        when(dependency(PlatformTransactionManager.class).getTransaction(any(TransactionDefinition.class)))
            .thenReturn(mock(TransactionStatus.class));
        when(dependency(MutualLock.class).execute(anyString(), anyLong(), anyLong(), any(Supplier.class)))
            .thenAnswer(invocation -> ((Supplier<?>) invocation.getArgument(3)).get());
    }

    @Test void ongoingEventCannotApproveEvenWithReceipt() {
        prepare(OffsetDateTime.now().minusHours(1), "normal");
        ServiceException exception = assertThrows(ServiceException.class, () -> service.approve(701L));
        assertTrue(exception.getMessage().contains("审核窗口已结束"));
        verifyNoInteractions(dependency(FeeApi.class));
        verify(dependency(SportsRegistrationMapper.class), never()).updateById(any(SportsRegistration.class));
    }

    @Test void endedEventCannotApprove() {
        prepare(OffsetDateTime.now().minusDays(2), "normal");
        assertTrue(assertThrows(ServiceException.class, () -> service.approve(701L)).getMessage().contains("审核窗口已结束"));
        verifyNoInteractions(dependency(FeeApi.class));
    }

    @Test void closedRegistrationBeforeStartStillReachesReceiptCheck() {
        prepare(OffsetDateTime.now().plusHours(1), "normal");
        when(dependency(FeeApi.class).current("fixture", 701L)).thenReturn(Optional.empty());
        assertTrue(assertThrows(ServiceException.class, () -> service.approve(701L)).getMessage().contains("收费记录"));
        verify(dependency(FeeApi.class)).current("fixture", 701L);
    }

    @Test void cancelledEventIsDeniedBeforeReceiptCheck() {
        prepare(OffsetDateTime.now().plusDays(1), "cancelled");
        assertTrue(assertThrows(ServiceException.class, () -> service.approve(701L)).getMessage().contains("取消"));
        verifyNoInteractions(dependency(FeeApi.class));
    }

    @Test void partialReceiptCannotAutoApprove() {
        prepareAuto("open");
        withTenant(() -> assertThrows(ServiceException.class, () -> service.tryAutoApproveAfterPayment("fixture", 701L)));
        verify(dependency(SportsRegistrationMapper.class), never()).updateById(any(SportsRegistration.class));
    }

    @Test void voidObligationCannotAutoApprove() {
        prepareAuto("void");
        withTenant(() -> assertThrows(ServiceException.class, () -> service.tryAutoApproveAfterPayment("fixture", 701L)));
        verify(dependency(SportsRegistrationMapper.class), never()).updateById(any(SportsRegistration.class));
    }

    @Test void settledObligationReachesAutoApprovalWrite() {
        prepareAuto("settled");
        // 模拟乐观更新失败，停在写入边界，避免使用名单投影自证其他流程。
        withTenant(() -> service.tryAutoApproveAfterPayment("fixture", 701L));
        verify(dependency(SportsRegistrationMapper.class)).updateById(argThat((SportsRegistration row) -> "approved".equals(row.getStatus())));
    }

    private void prepareAuto(String obligationStatus) {
        prepare(OffsetDateTime.now().plusHours(1), "normal");
        var gate = dependency(EventRegistrationApi.class).managedGate(901L).orElseThrow();
        when(dependency(EventRegistrationApi.class).findEvent(901L)).thenReturn(Optional.of(
            new EventRegistrationApi.EventRegistrationGate(gate.eventId(), gate.tenantId(), gate.organizationId(), gate.name(),
                gate.publicationStatus(), gate.holdingStatus(), gate.registrationOpensAt(), gate.registrationClosesAt(),
                gate.startsAt(), gate.endsAt(), "none", true)));
        var obligation = mock(FeeApi.ObligationView.class);
        when(obligation.status()).thenReturn(obligationStatus);
        when(dependency(FeeApi.class).current("fixture", 701L)).thenReturn(Optional.of(obligation));
    }

    private void withTenant(Runnable assertion) {
        try (var tenant = mockStatic(TenantHelper.class)) {
            tenant.when(() -> TenantHelper.dynamic(eq("fixture"), any(Supplier.class)))
                .thenAnswer(invocation -> ((Supplier<?>) invocation.getArgument(1)).get());
            assertion.run();
        }
    }
}
