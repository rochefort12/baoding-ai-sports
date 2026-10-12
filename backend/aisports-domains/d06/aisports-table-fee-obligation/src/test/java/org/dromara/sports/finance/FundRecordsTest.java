package org.dromara.sports.finance;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.api.OrganizationQualificationApi;
import org.dromara.sports.finance.service.FinanceService;
import org.dromara.sports.finance.domain.*;
import org.dromara.sports.finance.mapper.*;
import org.dromara.sports.platform.core.ScopedJdbc;
import java.math.BigDecimal;
import java.util.*;
import java.util.function.Supplier;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;

/** 模拟服务依赖检查查询用途及归属边界，不表示真实数据库/资金验收。 */
@Tag("local")
class FundRecordsTest {
    private final Map<Class<?>,Object> dependencies=new HashMap<>();
    private final FinanceService service=service();
    private <T> T dep(Class<T> type){return type.cast(dependencies.get(type));}
    private FinanceService service(){
        try {var ctor=FinanceService.class.getDeclaredConstructors()[0];Object[] args=Arrays.stream(ctor.getParameterTypes()).map(type->{Object mock=mock(type);dependencies.put(type,mock);return mock;}).toArray();return (FinanceService)ctor.newInstance(args);} catch(ReflectiveOperationException e){throw new AssertionError(e);}
    }
    private void authorization(boolean payment){
        when(dep(OrganizationSessionApi.class).managedOrganization(201L)).thenReturn(Optional.of(new OrganizationSessionApi.ManagedOrganization(601L,"虚构组织","fixture-tenant",301L)));
        when(dep(OrganizationQualificationApi.class).hasStaffAction("fixture-tenant",601L,301L,"payment")).thenReturn(payment);
    }
    private void facts(long organizationId){
        when(dep(ScopedJdbc.class).list(anyString(),any(Object[].class))).thenReturn(List.of());
        var obligation=new SportsFeeObligation();obligation.setId(801L);obligation.setRegistrationId(701L);when(dep(SportsFeeObligationMapper.class).selectById(801L)).thenReturn(obligation);
        var registration=new BillingRegistration();registration.setUnitId(501L);when(dep(BillingRegistrationMapper.class).selectById(701L)).thenReturn(registration);
        var unit=new BillingUnit();unit.setId(501L);unit.setEventId(901L);when(dep(BillingUnitMapper.class).selectById(501L)).thenReturn(unit);
        var event=new BillingEvent();event.setOrganizationId(organizationId);when(dep(BillingEventMapper.class).selectById(901L)).thenReturn(event);
        var allocation=new SportsPaymentAllocation();allocation.setPaymentId(401L);allocation.setAmount(new BigDecimal("120.00"));allocation.setStatus("reversed");when(dep(SportsPaymentAllocationMapper.class).selectList(any())).thenReturn(List.of(allocation));
        var payment=new SportsPayment();payment.setId(401L);payment.setPayerName("虚构付款人");payment.setAmount(new BigDecimal("120.00"));payment.setStatus("reversed");when(dep(SportsPaymentMapper.class).selectById(401L)).thenReturn(payment);
        var refund=new SportsRefund();refund.setId(402L);refund.setPaymentId(401L);refund.setCompletedAmount(new BigDecimal("120.00"));refund.setStatus("completed");when(dep(SportsRefundMapper.class).selectList(any())).thenReturn(List.of(refund));
    }
    @Test void returnsRealRecordsIncludingReversalWithoutWrites(){
        authorization(true);facts(601L);
        try(var login=mockStatic(LoginHelper.class);var tenant=mockStatic(TenantHelper.class)){
            login.when(LoginHelper::getUserId).thenReturn(201L);login.when(LoginHelper::getTenantId).thenReturn("fixture-tenant");
            tenant.when(()->TenantHelper.dynamic(eq("fixture-tenant"),any(Supplier.class))).thenAnswer(i->((Supplier<?>)i.getArgument(1)).get());
            var records=service.records(801L);assertEquals("reversed",records.receipts().get(0).status());assertEquals(new BigDecimal("120.00"),records.refunds().get(0).amount());
            assertTrue(records.exceptions().isEmpty());
            verify(dep(SportsPaymentMapper.class),never()).insert(any(SportsPayment.class));verify(dep(SportsRefundMapper.class),never()).insert(any(SportsRefund.class));
        }
    }
    @Test void rejectsOtherOrganizationBeforeReadingPayments(){
        authorization(true);facts(999L);
        try(var login=mockStatic(LoginHelper.class);var tenant=mockStatic(TenantHelper.class)){
            login.when(LoginHelper::getUserId).thenReturn(201L);login.when(LoginHelper::getTenantId).thenReturn("fixture-tenant");
            tenant.when(()->TenantHelper.dynamic(eq("fixture-tenant"),any(Supplier.class))).thenAnswer(i->((Supplier<?>)i.getArgument(1)).get());
            assertThrows(ServiceException.class,()->service.records(801L));verifyNoInteractions(dep(SportsPaymentMapper.class),dep(SportsRefundMapper.class));
        }
    }
    @Test void rejectsMissingPaymentPurposeBeforeReadingData(){
        authorization(false);try(var login=mockStatic(LoginHelper.class)){login.when(LoginHelper::getUserId).thenReturn(201L);assertThrows(ServiceException.class,()->service.records(801L));verifyNoInteractions(dep(SportsFeeObligationMapper.class),dep(SportsPaymentMapper.class));}
    }
    @Test void rejectsMismatchedSessionTenant(){
        authorization(true);try(var login=mockStatic(LoginHelper.class)){login.when(LoginHelper::getUserId).thenReturn(201L);login.when(LoginHelper::getTenantId).thenReturn("other-tenant");assertThrows(ServiceException.class,()->service.records(801L));verifyNoInteractions(dep(SportsFeeObligationMapper.class));}
    }
    @Test void rejectsPlatformIdentityBeforeConsultingOrganizationMapping(){
        try(var login=mockStatic(LoginHelper.class)){
            login.when(LoginHelper::getUserType).thenReturn(org.dromara.common.core.enums.UserType.PLATFORM_USER);
            assertThrows(ServiceException.class,()->service.records(801L));
            verifyNoInteractions(dep(OrganizationSessionApi.class),dep(SportsFeeObligationMapper.class));
        }
    }
    @Test void publicPricesKeepUnconfiguredUnitInsteadOfHidingIt(){
        var unit=new BillingUnit();unit.setId(501L);unit.setEventId(901L);unit.setName("费用待确认项目");
        when(dep(BillingUnitMapper.class).selectList(any())).thenReturn(List.of(unit));
        try(var tenant=mockStatic(TenantHelper.class)){
            tenant.when(()->TenantHelper.dynamic(eq("fixture-tenant"),any(Supplier.class))).thenAnswer(i->((Supplier<?>)i.getArgument(1)).get());
            var prices=service.publicUnitPrices("fixture-tenant",901L);
            assertEquals(1,prices.size());assertEquals(501L,prices.get(0).unitId());
            assertNull(prices.get(0).amount());assertNull(prices.get(0).paymentMode());
            verify(dep(SportsFeePolicyMapper.class),never()).insert(any(SportsFeePolicy.class));
        }
    }
}
