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

/** 配置费用不是实际付款；这里只验证资金服务边界，数据库事务及普通账号另行验证。 */
@Tag("local")
class DraftPricingDeletionTest {
    private final Map<Class<?>, Object> dependencies = new HashMap<>();
    private final FinanceService service = create();
    private final BillingEvent event = new BillingEvent();
    private final SportsFeePolicy active = policy(71L, "active");
    private final SportsFeePolicy retired = policy(72L, "retired");
    private <T> T dep(Class<T> type) { return type.cast(dependencies.get(type)); }
    private FinanceService create() {
        try {
            var constructor = FinanceService.class.getDeclaredConstructors()[0];
            return (FinanceService) constructor.newInstance(Arrays.stream(constructor.getParameterTypes()).map(type -> {
                Object value = type == ObjectMapper.class ? new ObjectMapper() : mock(type);
                dependencies.put(type, value); return value;
            }).toArray());
        } catch (ReflectiveOperationException failure) { throw new AssertionError(failure); }
    }
    private SportsFeePolicy policy(long id, String state) {
        var policy = new SportsFeePolicy(); policy.setId(id); policy.setUnitId(51L);
        policy.setAmount(new BigDecimal("100.00")); policy.setPaymentMode("event"); policy.setStatus(state);
        return policy;
    }
    @BeforeEach void setup() {
        event.setId(91L); event.setTenantId("fixture"); event.setPublicationStatus("draft"); event.setHoldingStatus("normal");
        when(dep(BillingEventMapper.class).lock(91L)).thenReturn(event);
        var unit = new BillingUnit(); unit.setId(51L); unit.setEventId(91L);
        when(dep(BillingUnitMapper.class).selectList(any())).thenReturn(List.of(unit));
        when(dep(BillingRegistrationMapper.class).selectCount(any())).thenReturn(0L);
        when(dep(SportsFeePolicyMapper.class).selectList(any())).thenReturn(List.of(active, retired));
        when(dep(SportsFeeObligationMapper.class).selectCount(any())).thenReturn(0L);
        when(dep(SportsFeePolicyMapper.class).deleteById(anyLong())).thenReturn(1);
    }
    private void run(Runnable work) {
        try (var tenant = mockStatic(TenantHelper.class)) {
            tenant.when(() -> TenantHelper.dynamic(eq("fixture"), any(Supplier.class)))
                .thenAnswer(call -> ((Supplier<?>) call.getArgument(1)).get());
            work.run();
            verifyNoInteractions(dep(SportsPaymentMapper.class), dep(SportsPaymentAllocationMapper.class),
                dep(SportsRefundMapper.class), dep(SportsPaymentExceptionMapper.class), dep(SportsPaymentActionMapper.class));
        }
    }
    private void rejected() {
        run(() -> assertThrows(ServiceException.class, () -> service.discardUnusedDraftPricing("fixture", 91L)));
        verify(dep(SportsFeePolicyMapper.class), never()).deleteById(anyLong());
        verify(dep(SportsEventPaymentConfigMapper.class), never()).delete(any());
    }
    @Test void paidAndRetiredPricingWithoutAnyUsageCanBeDiscardedTogether() {
        run(() -> service.discardUnusedDraftPricing("fixture", 91L));
        var order = inOrder(dep(BillingEventMapper.class), dep(SportsFeeObligationMapper.class), dep(SportsFeePolicyMapper.class), dep(SportsEventPaymentConfigMapper.class));
        order.verify(dep(BillingEventMapper.class)).lock(91L);
        order.verify(dep(SportsFeeObligationMapper.class), times(2)).selectCount(any());
        order.verify(dep(SportsFeePolicyMapper.class)).deleteById(71L);
        order.verify(dep(SportsFeePolicyMapper.class)).deleteById(72L);
        order.verify(dep(SportsEventPaymentConfigMapper.class)).delete(any());
    }
    @Test void oldRegistrationStillPreventsErasingPricing() {
        when(dep(BillingRegistrationMapper.class).selectCount(any())).thenReturn(1L); rejected();
    }
    @Test void draftWithOnlyEventPaymentConfigurationAlsoCanBeCleaned() {
        when(dep(BillingUnitMapper.class).selectList(any())).thenReturn(List.of());
        run(() -> service.discardUnusedDraftPricing("fixture", 91L));
        verify(dep(SportsFeePolicyMapper.class), never()).deleteById(anyLong());
        verify(dep(SportsEventPaymentConfigMapper.class)).delete(any());
    }
    @Test void evenClosedObligationOfRetiredVersionPreventsErasingPricing() {
        when(dep(SportsFeeObligationMapper.class).selectCount(any())).thenReturn(0L, 1L); rejected();
    }
    @Test void firstSubmissionLockCannotBeResetByDeletingPricing() {
        event.setRegistrationReviewLocked(true); rejected();
    }
    @Test void publishedOrOtherTenantEventCannotBeCleaned() {
        event.setPublicationStatus("published"); rejected();
        event.setPublicationStatus("draft"); event.setTenantId("other"); rejected();
    }
    @Test void stalePricingDeleteFailsBeforeRemovingEventPaymentSettings() {
        when(dep(SportsFeePolicyMapper.class).deleteById(71L)).thenReturn(0);
        run(() -> assertThrows(ServiceException.class, () -> service.discardUnusedDraftPricing("fixture", 91L)));
        verify(dep(SportsFeePolicyMapper.class), never()).deleteById(72L);
        verify(dep(SportsEventPaymentConfigMapper.class), never()).delete(any());
    }
}
