package org.dromara.sports.finance;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.core.lock.MutualLock;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.OrganizationQualificationApi;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.finance.domain.*;
import org.dromara.sports.finance.mapper.*;
import org.dromara.sports.finance.service.FinanceService;
import org.dromara.sports.platform.core.BusinessIdentity;
import org.junit.jupiter.api.*;
import org.mockito.ArgumentCaptor;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionStatus;

import java.math.BigDecimal;
import java.util.*;
import java.util.function.Supplier;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 模拟验证无支付副作用、价格历史与拒绝边界；真实提交回滚和普通账号另验。 */
@Tag("local")
class UnusedDraftPolicyRevisionTest {
    private final Map<Class<?>, Object> dependencies = new HashMap<>();
    private final FinanceService service = create();
    private final BillingEvent event = new BillingEvent();
    private final BillingUnit unit = new BillingUnit();
    private final SportsFeePolicy current = policy(71L, 2, "active", "100.00");
    private final SportsFeePolicy old = policy(72L, 5, "retired", "50.00");
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
    private SportsFeePolicy policy(long id, int revision, String state, String amount) {
        var row = new SportsFeePolicy(); row.setId(id); row.setUnitId(51L); row.setRevision(revision);
        row.setAmount(new BigDecimal(amount)); row.setPaymentMode("event"); row.setStatus(state); row.setVersion(0);
        return row;
    }
    @BeforeEach void setup() {
        event.setId(91L); event.setTenantId("fixture"); event.setOrganizationId(61L);
        event.setPublicationStatus("draft"); event.setHoldingStatus("normal");
        event.setPublishedRevision(0); event.setRegistrationReviewLocked(false);
        unit.setId(51L); unit.setEventId(91L); unit.setTenantId("fixture"); unit.setName("合成项目");
        when(dep(OrganizationSessionApi.class).managedOrganization(9L)).thenReturn(Optional.of(
            new OrganizationSessionApi.ManagedOrganization(61L, "合成组织", "fixture", 8L)));
        when(dep(OrganizationQualificationApi.class).hasStaffAction("fixture", 61L, 8L, "payment")).thenReturn(true);
        when(dep(BillingEventMapper.class).lock(91L)).thenReturn(event);
        when(dep(BillingEventMapper.class).selectById(91L)).thenReturn(event);
        when(dep(BillingUnitMapper.class).selectOne(any())).thenReturn(unit);
        when(dep(BillingUnitMapper.class).selectById(51L)).thenReturn(unit);
        when(dep(SportsFeePolicyMapper.class).selectOne(any())).thenReturn(current);
        when(dep(SportsFeePolicyMapper.class).selectList(any())).thenReturn(List.of(current, old));
        when(dep(SportsFeePolicyMapper.class).updateById(any(SportsFeePolicy.class))).thenReturn(1);
        when(dep(SportsFeePolicyMapper.class).insert(any(SportsFeePolicy.class))).thenReturn(1);
        when(dep(MutualLock.class).execute(anyString(), anyLong(), anyLong(), any(Supplier.class)))
            .thenAnswer(call -> ((Supplier<?>) call.getArgument(3)).get());
        when(dep(PlatformTransactionManager.class).getTransaction(any())).thenReturn(mock(TransactionStatus.class));
    }
    private void owned(Runnable work) {
        try (var identity = mockStatic(BusinessIdentity.class); var tenant = mockStatic(TenantHelper.class)) {
            identity.when(BusinessIdentity::getUserType).thenReturn(UserType.SYS_USER);
            identity.when(BusinessIdentity::getUserId).thenReturn(9L);
            identity.when(BusinessIdentity::getTenantId).thenReturn("fixture");
            tenant.when(() -> TenantHelper.dynamic(eq("fixture"), any(Supplier.class)))
                .thenAnswer(call -> ((Supplier<?>) call.getArgument(1)).get());
            work.run();
        }
    }
    private void revise(String amount) {
        owned(() -> service.reviseUnusedDraftPolicy("fixture", 91L, 51L, new BigDecimal(amount)));
        verifyNoInteractions(dep(SportsEventPaymentConfigMapper.class), dep(SportsFeeObligationMapper.class),
            dep(SportsPaymentMapper.class), dep(SportsPaymentAllocationMapper.class), dep(SportsPaymentActionMapper.class),
            dep(SportsRefundMapper.class), dep(SportsPaymentExceptionMapper.class));
        verifyNoInteractions(dep(MutualLock.class));
    }
    private void rejected() {
        owned(() -> assertThrows(ServiceException.class,
            () -> service.reviseUnusedDraftPolicy("fixture", 91L, 51L, new BigDecimal("200.00"))));
        verify(dep(SportsFeePolicyMapper.class), never()).updateById(any(SportsFeePolicy.class));
        verify(dep(SportsFeePolicyMapper.class), never()).insert(any(SportsFeePolicy.class));
    }
    private SportsFeePolicy inserted() {
        var row = ArgumentCaptor.forClass(SportsFeePolicy.class);
        verify(dep(SportsFeePolicyMapper.class)).insert(row.capture()); return row.getValue();
    }
    @Test void newPaidPriceUsesNextHistoricalRevisionAndKeepsOldAmounts() {
        revise("120"); var row = inserted();
        assertEquals(51L, row.getUnitId()); assertEquals(6, row.getRevision());
        assertEquals(new BigDecimal("120.00"), row.getAmount()); assertEquals("event", row.getPaymentMode());
        assertEquals("entry", row.getPricingUnit()); assertEquals("active", row.getStatus());
        assertEquals("retired", current.getStatus()); assertEquals(new BigDecimal("100.00"), current.getAmount());
        assertEquals(71L, current.getId()); assertEquals(new BigDecimal("50.00"), old.getAmount());
        verify(dep(SportsFeePolicyMapper.class), never()).deleteById(anyLong());
        var order = inOrder(dep(BillingEventMapper.class), dep(BillingUnitMapper.class), dep(SportsFeePolicyMapper.class));
        order.verify(dep(BillingEventMapper.class)).lock(91L);
        order.verify(dep(BillingEventMapper.class)).hasDraftBusinessHistory("fixture", 91L);
        order.verify(dep(BillingUnitMapper.class)).selectOne(any());
        order.verify(dep(SportsFeePolicyMapper.class), times(2)).selectOne(any());
        order.verify(dep(SportsFeePolicyMapper.class)).updateById(current);
        order.verify(dep(SportsFeePolicyMapper.class)).selectList(any());
        order.verify(dep(SportsFeePolicyMapper.class)).insert(any(SportsFeePolicy.class));
    }
    @Test void zeroPriceCreatesFreePolicyWithoutAnyPaymentOrChannelMutation() {
        revise("0"); var row = inserted();
        assertEquals(new BigDecimal("0.00"), row.getAmount()); assertEquals("free", row.getPaymentMode());
        assertNull(row.getQrFileId()); assertNull(row.getPayInstruction());
    }
    @Test void equalAmountDoesNotRetireOrCloneTheActivePolicyOrItsExistingQr() {
        current.setPaymentMode("organizer_qr"); current.setQrFileId(101L); current.setPayInstruction("原有收款指引");
        revise("100.0");
        assertEquals("active", current.getStatus()); assertEquals(101L, current.getQrFileId());
        assertEquals("原有收款指引", current.getPayInstruction());
        verify(dep(SportsFeePolicyMapper.class), never()).updateById(any(SportsFeePolicy.class));
        verify(dep(SportsFeePolicyMapper.class), never()).insert(any(SportsFeePolicy.class));
    }
    @Test void unpricedDraftCanGetItsFirstPriceWithoutTouchingOtherUnits() {
        when(dep(SportsFeePolicyMapper.class).selectOne(any())).thenReturn(null);
        when(dep(SportsFeePolicyMapper.class).selectList(any())).thenReturn(List.of());
        revise("100"); assertEquals(1, inserted().getRevision());
        verify(dep(SportsFeePolicyMapper.class), never()).updateById(any(SportsFeePolicy.class));
    }
    @Test void crossTenantAndCrossOrganizationEventsCannotBeRepriced() {
        event.setTenantId("other"); rejected();
        event.setTenantId("fixture"); event.setOrganizationId(999L); rejected();
    }
    @Test void callerTenantCannotSelectAnotherOrganizationsPricingScope() {
        owned(() -> assertThrows(ServiceException.class,
            () -> service.reviseUnusedDraftPolicy("other", 91L, 51L, new BigDecimal("200"))));
        verify(dep(BillingEventMapper.class), never()).lock(anyLong());
        verifyNoInteractions(dep(SportsFeePolicyMapper.class));
    }
    @Test void lackOfPaymentAuthorityRejectsBeforeLockAndPolicyLookup() {
        when(dep(OrganizationQualificationApi.class).hasStaffAction("fixture", 61L, 8L, "payment")).thenReturn(false);
        rejected(); verify(dep(BillingEventMapper.class), never()).lock(anyLong());
    }
    @Test void anotherEventsUnitAndAnotherTenantUnitCannotBeRepriced() {
        unit.setEventId(92L); rejected();
        unit.setEventId(91L); unit.setTenantId("other"); rejected();
    }
    @Test void publishedOfflineCancelledAndPastPublicationAllReject() {
        event.setPublicationStatus("published"); rejected();
        event.setPublicationStatus("offline"); rejected();
        event.setPublicationStatus("draft"); event.setHoldingStatus("cancelled"); rejected();
        event.setHoldingStatus("normal"); event.setPublishedRevision(1); rejected();
    }
    @Test void anyBusinessHistoryAndFirstSubmissionLockRejectEvenClosedRecords() {
        when(dep(BillingEventMapper.class).hasDraftBusinessHistory("fixture", 91L)).thenReturn(true); rejected();
        when(dep(BillingEventMapper.class).hasDraftBusinessHistory("fixture", 91L)).thenReturn(false);
        event.setRegistrationReviewLocked(true); rejected();
    }
    @Test void invalidMoneyNeverTouchesTheEventOrPrices() {
        owned(() -> {
            assertThrows(ServiceException.class, () -> service.reviseUnusedDraftPolicy("fixture", 91L, 51L, new BigDecimal("-1")));
            assertThrows(ServiceException.class, () -> service.reviseUnusedDraftPolicy("fixture", 91L, 51L, new BigDecimal("1.999")));
        });
        verify(dep(BillingEventMapper.class), never()).lock(anyLong()); verifyNoInteractions(dep(SportsFeePolicyMapper.class));
    }
    @Test void staleOldVersionRejectsBeforeInsertingNewPrice() {
        when(dep(SportsFeePolicyMapper.class).updateById(any(SportsFeePolicy.class))).thenReturn(0);
        owned(() -> assertThrows(ServiceException.class,
            () -> service.reviseUnusedDraftPolicy("fixture", 91L, 51L, new BigDecimal("200"))));
        verify(dep(SportsFeePolicyMapper.class), never()).insert(any(SportsFeePolicy.class));
    }
    @Test void existingWorkspacePublishAlsoLocksEventBeforeItsPriceVersionWrites() {
        owned(() -> service.publish(51L, new BigDecimal("120"), "event", null, null));
        var order = inOrder(dep(BillingEventMapper.class), dep(SportsFeePolicyMapper.class));
        order.verify(dep(BillingEventMapper.class)).lock(91L);
        order.verify(dep(SportsFeePolicyMapper.class)).selectOne(any());
        order.verify(dep(SportsFeePolicyMapper.class)).updateById(current);
        assertEquals(6, inserted().getRevision());
    }
}
