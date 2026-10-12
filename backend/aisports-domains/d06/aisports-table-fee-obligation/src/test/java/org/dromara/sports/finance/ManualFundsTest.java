package org.dromara.sports.finance;
import org.junit.jupiter.api.*;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.core.lock.MutualLock;
import org.dromara.sports.api.*;
import org.dromara.sports.finance.service.FinanceService;
import org.dromara.sports.finance.domain.*;
import org.dromara.sports.finance.mapper.*;
import org.springframework.transaction.*;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import java.math.BigDecimal;
import java.util.*;
import java.util.function.Supplier;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;
/** 隔离模拟持久依赖检查资金写语义；不表示实际转账或普通角色验收。 */
@Tag("local")
class ManualFundsTest {
 final Map<Class<?>,Object> deps=new HashMap<>(); final FinanceService service=service();
 final SportsFeeObligation due=new SportsFeeObligation(); final BillingRegistration entry=new BillingRegistration();
 final List<SportsPayment> payments=new ArrayList<>(); final List<SportsPaymentAllocation> allocations=new ArrayList<>(); final List<SportsRefund> refunds=new ArrayList<>();
 SportsPaymentAction action;
 <T>T dep(Class<T> t){return t.cast(deps.get(t));}
 FinanceService service(){try{var ctor=FinanceService.class.getDeclaredConstructors()[0];return (FinanceService)ctor.newInstance(Arrays.stream(ctor.getParameterTypes()).map(t->{Object m=t==com.fasterxml.jackson.databind.ObjectMapper.class?new com.fasterxml.jackson.databind.ObjectMapper():mock(t);deps.put(t,m);return m;}).toArray());}catch(Exception e){throw new AssertionError(e);}}
 @BeforeEach void setup(){
  due.setId(1L);due.setTenantId("fixture");due.setRegistrationId(2L);due.setStatus("open");due.setTotalAmount(new BigDecimal("100.00"));due.setQuoteSnapshot("{}");
  entry.setId(2L);entry.setUnitId(3L);entry.setStatus("submitted");var unit=new BillingUnit();unit.setId(3L);unit.setEventId(4L);var event=new BillingEvent();event.setId(4L);event.setOrganizationId(6L);event.setHoldingStatus("normal");
  when(dep(OrganizationSessionApi.class).managedOrganization(9L)).thenReturn(Optional.of(new OrganizationSessionApi.ManagedOrganization(6L,"虚构组织","fixture",8L)));
  when(dep(OrganizationQualificationApi.class).hasStaffAction("fixture",6L,8L,"payment")).thenReturn(true);
  when(dep(SportsFeeObligationMapper.class).selectById(any())).thenReturn(due);when(dep(SportsFeeObligationMapper.class).selectOne(any())).thenReturn(due);when(dep(SportsFeeObligationMapper.class).updateById(any(SportsFeeObligation.class))).thenReturn(1);
  when(dep(BillingRegistrationMapper.class).selectById(any())).thenReturn(entry);when(dep(BillingUnitMapper.class).selectById(any())).thenReturn(unit);when(dep(BillingEventMapper.class).selectById(any())).thenReturn(event);
  when(dep(PlatformTransactionManager.class).getTransaction(any())).thenReturn(mock(TransactionStatus.class));
  when(dep(MutualLock.class).execute(anyString(),anyLong(),anyLong(),any(Supplier.class))).thenAnswer(i->((Supplier<?>)i.getArgument(3)).get());
  when(dep(SportsPaymentMapper.class).insert(any(SportsPayment.class))).thenAnswer(i->{SportsPayment p=i.getArgument(0);p.setId(100L+payments.size());payments.add(p);return 1;});
  when(dep(SportsPaymentMapper.class).selectById(any())).thenAnswer(i->payments.stream().filter(p->p.getId().equals(i.getArgument(0))).findFirst().orElse(null));
  when(dep(SportsPaymentAllocationMapper.class).insert(any(SportsPaymentAllocation.class))).thenAnswer(i->{allocations.add(i.getArgument(0));return 1;});
  when(dep(SportsPaymentAllocationMapper.class).selectList(any())).thenAnswer(i->List.copyOf(allocations));
  when(dep(SportsRefundMapper.class).selectList(any())).thenAnswer(i->List.copyOf(refunds));
  when(dep(SportsRefundMapper.class).insert(any(SportsRefund.class))).thenAnswer(i->{SportsRefund r=i.getArgument(0);r.setId(400L+refunds.size());refunds.add(r);return 1;});
  when(dep(SportsPaymentActionMapper.class).selectOne(any())).thenAnswer(i->action);
  when(dep(SportsPaymentActionMapper.class).insert(any(SportsPaymentAction.class))).thenAnswer(i->{action=i.getArgument(0);action.setId(300L);return 1;});
  when(dep(SportsPaymentActionMapper.class).selectById(any())).thenAnswer(i->action);when(dep(SportsPaymentActionMapper.class).updateById(any(SportsPaymentAction.class))).thenReturn(1);
 }
 <T>T session(Supplier<T> work){try(var login=mockStatic(LoginHelper.class);var tenant=mockStatic(TenantHelper.class)){login.when(LoginHelper::getUserId).thenReturn(9L);login.when(LoginHelper::getTenantId).thenReturn("fixture");tenant.when(()->TenantHelper.dynamic(eq("fixture"),any(Supplier.class))).thenAnswer(i->((Supplier<?>)i.getArgument(1)).get());return work.get();}}
 void receipt(String amount,String key){service.confirmManual(1L,"实际测试付款人",new BigDecimal(amount),"2026-10-07 10:00:00","测试事实",null,key);}
 @Test void partialReceiptsSettleOnlyWhenCumulativeEnough(){session(()->{receipt("40.00","a");assertEquals("open",due.getStatus());assertEquals(new BigDecimal("40.00"),payments.get(0).getAmount());receipt("60.00","b");assertEquals("settled",due.getStatus());assertEquals(2,payments.size());return null;});}
 @Test void rejectedEntryAllowsLateMoneyWithoutQualificationRestoration(){session(()->{entry.setStatus("rejected");due.setStatus("void");receipt("30.00","late");assertEquals("void",due.getStatus());assertEquals("rejected",entry.getStatus());assertNotNull(action);return null;});}
 @Test void surplusIsRecordedAsFactAndNeedsCleanup(){session(()->{receipt("120.00","surplus");assertEquals("settled",due.getStatus());assertEquals(new BigDecimal("120.00"),payments.get(0).getAmount());assertNotNull(action);return null;});}
 @Test void partialRefundKeepsPendingAndRejectsExcess(){session(()->{entry.setStatus("rejected");receipt("100.00","original");service.recordRefund(300L,"按原规则退部分","r1",new BigDecimal("40.00"),"2026-10-07 11:00:00","实际测试付款人",null);assertEquals("pending",action.getStatus());assertEquals(new BigDecimal("40.00"),refunds.get(0).getCompletedAmount());assertThrows(ServiceException.class,()->service.recordRefund(300L,"继续退","r2",new BigDecimal("61.00"),"2026-10-07 12:00:00","实际测试付款人",null));assertEquals(1,refunds.size());return null;});}
 @Test void changedRecipientRequiresAuthority(){session(()->{entry.setStatus("rejected");receipt("100.00","original");assertThrows(ServiceException.class,()->service.recordRefund(300L,"规则依据","r1",new BigDecimal("10.00"),"2026-10-07 11:00:00","其他接收人",null));assertTrue(refunds.isEmpty());return null;});}
 @Test void nonCentAmountCannotBeRoundedIntoDifferentFact(){session(()->{assertThrows(ServiceException.class,()->receipt("1.999","bad"));assertTrue(payments.isEmpty());return null;});}
 @Test void receiptReplayIsNotAnotherPaymentAndChangedAmountIsRejected(){session(()->{receipt("40.00","same");when(dep(SportsPaymentMapper.class).selectOne(any())).thenReturn(payments.get(0));when(dep(SportsPaymentAllocationMapper.class).selectOne(any())).thenReturn(allocations.get(0));receipt("40.00","same");assertEquals(1,payments.size());assertThrows(ServiceException.class,()->receipt("41.00","same"));assertEquals(1,payments.size());return null;});}
 @Test void secondRefundCompletesOnlyActualRemainder(){session(()->{entry.setStatus("rejected");receipt("100.00","original");service.recordRefund(300L,"退改依据","r1",new BigDecimal("40.00"),"2026-10-07 11:00:00","实际测试付款人",null);service.recordRefund(300L,"退改依据","r2",new BigDecimal("60.00"),"2026-10-07 12:00:00","实际测试付款人",null);assertEquals("refunded",action.getStatus());assertEquals(2,refunds.size());return null;});}
 @Test void refundCannotBeHiddenByReversingReceipt(){session(()->{entry.setStatus("rejected");receipt("100.00","original");service.recordRefund(300L,"退改依据","r1",new BigDecimal("10.00"),"2026-10-07 11:00:00","实际测试付款人",null);when(dep(SportsPaymentAllocationMapper.class).selectCount(any())).thenReturn(1L);assertThrows(ServiceException.class,()->service.reverse(1L,100L,"reverse"));assertEquals("confirmed",payments.get(0).getStatus());return null;});}
 @Test void otherOrganizationCannotRecordMoney(){session(()->{var other=new BillingEvent();other.setId(4L);other.setOrganizationId(999L);other.setHoldingStatus("normal");when(dep(BillingEventMapper.class).selectById(any())).thenReturn(other);assertThrows(ServiceException.class,()->receipt("100.00","other"));assertTrue(payments.isEmpty());return null;});}
 @Test void actualTimeMustNotBeInvented(){session(()->{assertThrows(ServiceException.class,()->service.confirmManual(1L,"付款人",new BigDecimal("100.00"),"","事实",null,"no-time"));assertTrue(payments.isEmpty());return null;});}
 @Test void conflictingReceiptAuditWaitsUntilTheParentTransactionHasReleasedItsLocks(){session(()->{
  receipt("40.00","same");when(dep(SportsPaymentMapper.class).selectOne(any())).thenReturn(payments.get(0));when(dep(SportsPaymentAllocationMapper.class).selectOne(any())).thenReturn(allocations.get(0));
  TransactionSynchronizationManager.initSynchronization();TransactionSynchronizationManager.setActualTransactionActive(true);
  try{
   assertThrows(ServiceException.class,()->receipt("41.00","same"));
   verify(dep(SportsPaymentExceptionMapper.class),never()).insert(any(SportsPaymentException.class));
   var callbacks=TransactionSynchronizationManager.getSynchronizations();assertEquals(1,callbacks.size());
   callbacks.get(0).afterCompletion(TransactionSynchronization.STATUS_ROLLED_BACK);
   var recorded=org.mockito.ArgumentCaptor.forClass(SportsPaymentException.class);verify(dep(SportsPaymentExceptionMapper.class)).insert(recorded.capture());
   assertEquals(1L,recorded.getValue().getObligationId());assertEquals("fixture",recorded.getValue().getTenantId());assertEquals(new BigDecimal("41.00"),recorded.getValue().getReportedAmount());assertEquals(1,payments.size());
  }finally{TransactionSynchronizationManager.clearSynchronization();TransactionSynchronizationManager.setActualTransactionActive(false);}
  return null;
 });}
}
