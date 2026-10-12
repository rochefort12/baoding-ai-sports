package org.dromara.sports.finance;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.OrganizationQualificationApi;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.finance.domain.*;
import org.dromara.sports.finance.mapper.*;
import org.dromara.sports.finance.service.FinanceService;
import org.dromara.sports.platform.core.ScopedJdbc;
import org.junit.jupiter.api.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;
import java.util.function.Supplier;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** Mock service boundaries only: actual closed duties and authorized UI are checked separately over HTTP. */
@Tag("local")
class HistoricalFundRecordsTest {
    private final Map<Class<?>, Object> dependencies = new HashMap<>();
    private final FinanceService service = create();
    private final SportsFeeObligation old = duty(1L,"void","{\"paymentMode\":\"offline\"}");
    private final SportsFeeObligation current = duty(2L,"void","{\"paymentMode\":\"offline\",\"rosterRevision\":2}");
    private <T> T dep(Class<T> type) { return type.cast(dependencies.get(type)); }
    private FinanceService create() {
        try {
            var constructor = FinanceService.class.getDeclaredConstructors()[0];
            return (FinanceService)constructor.newInstance(Arrays.stream(constructor.getParameterTypes()).map(type -> {
                Object value = type == ObjectMapper.class ? new ObjectMapper() : mock(type);
                dependencies.put(type,value); return value;
            }).toArray());
        } catch (ReflectiveOperationException failure) { throw new AssertionError(failure); }
    }
    private SportsFeeObligation duty(long id,String status,String snapshot) {
        var duty=new SportsFeeObligation();duty.setId(id);duty.setTenantId("fixture");duty.setRegistrationId(7L);
        duty.setStatus(status);duty.setTotalAmount(new BigDecimal("100.00"));duty.setQuoteSnapshot(snapshot);
        duty.setCreateTime(Date.from(Instant.parse("2026-10-11T00:00:00Z"))); return duty;
    }
    @BeforeEach void setup() {
        when(dep(OrganizationSessionApi.class).managedOrganization(9L)).thenReturn(Optional.of(new OrganizationSessionApi.ManagedOrganization(6L,"合成组织","fixture",8L)));
        when(dep(OrganizationQualificationApi.class).hasStaffAction("fixture",6L,8L,"payment")).thenReturn(true);
        var entry=new BillingRegistration();entry.setId(7L);entry.setUnitId(3L);entry.setStatus("draft");
        var unit=new BillingUnit();unit.setId(3L);unit.setEventId(4L);
        var event=new BillingEvent();event.setId(4L);event.setOrganizationId(6L);
        when(dep(BillingRegistrationMapper.class).selectById(7L)).thenReturn(entry);
        when(dep(BillingUnitMapper.class).selectById(3L)).thenReturn(unit);
        when(dep(BillingEventMapper.class).selectById(4L)).thenReturn(event);
        when(dep(SportsFeeObligationMapper.class).selectList(any())).thenReturn(List.of(current,old));
        when(dep(SportsPaymentAllocationMapper.class).selectList(any())).thenReturn(List.of());
    }
    private void run(Runnable work) {
        try(var login=mockStatic(LoginHelper.class);var tenant=mockStatic(TenantHelper.class)) {
            login.when(LoginHelper::getUserId).thenReturn(9L);login.when(LoginHelper::getTenantId).thenReturn("fixture");
            tenant.when(()->TenantHelper.dynamic(eq("fixture"),any(Supplier.class))).thenAnswer(i->((Supplier<?>)i.getArgument(1)).get());
            work.run();
            verify(dep(SportsFeeObligationMapper.class),never()).updateById(any(SportsFeeObligation.class));
            verify(dep(SportsPaymentMapper.class),never()).insert(any(SportsPayment.class));
        }
    }
    @Test void allClosedVersionsRemainVisibleWithoutInventingLegacyRevision() { run(()->{
        var result=service.history(7L);assertEquals(2,result.size());assertEquals(2,result.get(0).rosterRevision());
        assertTrue(result.get(0).current());assertFalse(result.get(1).current());assertNull(result.get(1).rosterRevision());
        assertEquals("2026-10-11T08:00+08:00",result.get(1).createdAt());assertEquals(BigDecimal.ZERO,result.get(1).netAmount());
    }); }
    @Test void unresolvedOriginalExceptionKeepsTheRegistrationInFundsWork() { run(()->{
        when(dep(ScopedJdbc.class).count(anyString(),any(Object[].class))).thenAnswer(i->Long.valueOf(1L).equals(((Object[])i.getRawArguments()[1])[1])?1L:0L);
        assertTrue(service.unsettled("fixture",7L));assertTrue(service.history(7L).get(1).pending());
    }); }
    @Test void anOlderPendingRefundKeepsWorkVisible() { run(()->{
        when(dep(SportsPaymentActionMapper.class).selectCount(any())).thenReturn(0L,1L);
        assertTrue(service.unsettled("fixture",7L));
    }); }
    @Test void anOlderOpenDutyCannotDisappearBehindAClosedLatestDuty() { run(()->{
        old.setStatus("open");assertTrue(service.unsettled("fixture",7L));
    }); }
    @Test void refundedAndResolvedHistoryDoesNotCreateAFreshPaymentResponsibility() { run(()->{
        assertFalse(service.unsettled("fixture",7L));assertTrue(service.history(7L).stream().noneMatch(FinanceService.ObligationHistory::pending));
    }); }
    @Test void noFormalDutyMeansNoFundsWork() { run(()->{
        when(dep(SportsFeeObligationMapper.class).selectList(any())).thenReturn(List.of());assertFalse(service.unsettled("fixture",7L));assertTrue(service.history(7L).isEmpty());
    }); }
    @Test void otherOrganizationIsRejectedBeforeHistoricalPaymentsAreRead() { run(()->{
        var other=new BillingEvent();other.setOrganizationId(99L);when(dep(BillingEventMapper.class).selectById(4L)).thenReturn(other);
        assertThrows(ServiceException.class,()->service.history(7L));verifyNoInteractions(dep(SportsPaymentMapper.class),dep(SportsPaymentAllocationMapper.class));
    }); }
    @Test void missingPaymentPurposeIsRejectedBeforeRegistrationRead() { run(()->{
        when(dep(OrganizationQualificationApi.class).hasStaffAction("fixture",6L,8L,"payment")).thenReturn(false);
        assertThrows(ServiceException.class,()->service.history(7L));verifyNoInteractions(dep(BillingRegistrationMapper.class));
    }); }
    @Test void invalidRevisionIsUnknownInsteadOfAnInferredRoster() { run(()->{
        old.setQuoteSnapshot("{\"paymentMode\":\"offline\",\"rosterRevision\":0}");assertNull(service.history(7L).get(1).rosterRevision());
    }); }
    @Test void snapshotFreezesTheExactNewRevisionWhileLegacyCallRemainsUnnumbered() throws Exception {
        var policy=new SportsFeePolicy();policy.setUnitId(3L);policy.setAmount(BigDecimal.ZERO);policy.setPaymentMode("free");
        var method=FinanceService.class.getDeclaredMethod("snapshot",SportsFeePolicy.class,Integer.class);method.setAccessible(true);
        var json=new ObjectMapper();assertEquals(4,json.readTree((String)method.invoke(service,policy,4)).path("rosterRevision").asInt());
        assertFalse(json.readTree((String)method.invoke(service,policy,null)).has("rosterRevision"));
    }
}
