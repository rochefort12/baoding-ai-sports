package org.dromara.sports.finance;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.finance.domain.*;
import org.dromara.sports.finance.mapper.*;
import org.dromara.sports.finance.service.FinanceService;
import org.junit.jupiter.api.*;
import java.math.BigDecimal;
import java.util.*;
import java.util.function.Supplier;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** Funds qualification is independent of an earlier approval; no receipt is created by this check. */
@Tag("local")
class ParticipationFundsTest {
    private final Map<Class<?>,Object> dependencies = new HashMap<>();
    private final FinanceService service = create();
    private final SportsFeeObligation due = new SportsFeeObligation();
    private final SportsPayment payment = new SportsPayment();
    private final SportsPaymentAllocation allocation = new SportsPaymentAllocation();
    private <T> T dep(Class<T> type) { return type.cast(dependencies.get(type)); }
    private FinanceService create() {
        try {
            var ctor = FinanceService.class.getDeclaredConstructors()[0];
            return (FinanceService)ctor.newInstance(Arrays.stream(ctor.getParameterTypes()).map(type -> {
                Object value = type == ObjectMapper.class ? new ObjectMapper() : mock(type);
                dependencies.put(type,value); return value;
            }).toArray());
        } catch (ReflectiveOperationException error) { throw new AssertionError(error); }
    }
    @BeforeEach void setup() {
        due.setId(1L);due.setTenantId("fixture");due.setRegistrationId(2L);due.setTotalAmount(new BigDecimal("100.00"));due.setStatus("settled");
        payment.setId(3L);payment.setStatus("confirmed");
        allocation.setPaymentId(3L);allocation.setAmount(new BigDecimal("100.00"));allocation.setStatus("effective");
        when(dep(SportsFeeObligationMapper.class).selectOne(any())).thenReturn(due);
        when(dep(SportsPaymentAllocationMapper.class).selectList(any())).thenReturn(List.of(allocation));
        when(dep(SportsPaymentMapper.class).selectById(3L)).thenReturn(payment);
        when(dep(SportsRefundMapper.class).selectList(any())).thenReturn(List.of());
    }
    private void run(Runnable assertion) {
        try (var tenant=mockStatic(TenantHelper.class)) {
            tenant.when(() -> TenantHelper.dynamic(eq("fixture"),any(Supplier.class))).thenAnswer(i -> ((Supplier<?>)i.getArgument(1)).get());
            assertion.run();
            verify(dep(SportsFeeObligationMapper.class),never()).updateById(any(SportsFeeObligation.class));
            verify(dep(SportsPaymentMapper.class),never()).insert(any(SportsPayment.class));
        }
    }
    @Test void noObligationFailsClosed() { run(() -> {when(dep(SportsFeeObligationMapper.class).selectOne(any())).thenReturn(null);assertThrows(ServiceException.class,()->service.requireParticipationReady("fixture",2L));}); }
    @Test void openObligationFailsDespitePreviousApproval() { run(() -> {due.setStatus("open");assertThrows(ServiceException.class,()->service.requireParticipationReady("fixture",2L));}); }
    @Test void zeroFeeNeedsNoReceipt() { run(() -> {due.setStatus("not_required");due.setTotalAmount(BigDecimal.ZERO);assertDoesNotThrow(()->service.requireParticipationReady("fixture",2L));verifyNoInteractions(dep(SportsPaymentAllocationMapper.class));}); }
    @Test void nonzeroFeeCannotBeDisguisedAsFree() { run(() -> {due.setStatus("not_required");assertThrows(ServiceException.class,()->service.requireParticipationReady("fixture",2L));}); }
    @Test void settledFlagCannotHideAReversal() { run(() -> {payment.setStatus("reversed");assertThrows(ServiceException.class,()->service.requireParticipationReady("fixture",2L));}); }
    @Test void settledFlagCannotHidePartialFunds() { run(() -> {allocation.setAmount(new BigDecimal("40.00"));assertThrows(ServiceException.class,()->service.requireParticipationReady("fixture",2L));}); }
    @Test void sufficientEffectiveFundsAreAccepted() { run(() -> assertDoesNotThrow(()->service.requireParticipationReady("fixture",2L))); }
    @Test void refundCanMakeAPreviouslySettledEntryShort() { run(() -> {var refund=new SportsRefund();refund.setCompletedAmount(new BigDecimal("20.00"));when(dep(SportsRefundMapper.class).selectList(any())).thenReturn(List.of(refund));assertThrows(ServiceException.class,()->service.requireParticipationReady("fixture",2L));}); }
    @Test void voidObligationCannotAdmitNewParticipation() { run(() -> {due.setStatus("void");assertThrows(ServiceException.class,()->service.requireParticipationReady("fixture",2L));}); }
}
