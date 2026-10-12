package org.dromara.sports.finance;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.core.lock.MutualLock;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.*;
import org.dromara.sports.finance.domain.*;
import org.dromara.sports.finance.mapper.*;
import org.dromara.sports.finance.service.FinanceService;
import org.dromara.sports.platform.core.*;
import org.junit.jupiter.api.*;
import org.springframework.transaction.*;
import java.math.BigDecimal;
import java.util.*;
import java.util.function.Supplier;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 隔离持久依赖只检验人工核对边界；不代表实际到账、退款或银行核验。 */
@Tag("local")
class PaymentExceptionResolutionTest {
    final Map<Class<?>,Object> deps=new HashMap<>();
    final FinanceService service=create();
    final Map<String,Object> row=new LinkedHashMap<>();
    final List<String> writes=new ArrayList<>();
    final SportsFeeObligation obligation=new SportsFeeObligation();
    final BillingRegistration registration=new BillingRegistration();
    <T>T dep(Class<T> type){return type.cast(deps.get(type));}
    FinanceService create(){try{var ctor=FinanceService.class.getDeclaredConstructors()[0];return (FinanceService)ctor.newInstance(Arrays.stream(ctor.getParameterTypes()).map(type->{Object value=type==ObjectMapper.class?new ObjectMapper():mock(type);deps.put(type,value);return value;}).toArray());}catch(Exception error){throw new AssertionError(error);}}
    @BeforeEach void setup(){
        row.put("id",41L);row.put("payment_id",100L);row.put("obligation_id",1L);row.put("exception_type","duplicate_payment");row.put("external_reference","synthetic-key");row.put("reported_amount",new BigDecimal("41.00"));row.put("status","open");row.put("version",0);
        obligation.setId(1L);obligation.setTenantId("fixture");obligation.setRegistrationId(2L);obligation.setStatus("settled");obligation.setTotalAmount(new BigDecimal("100.00"));
        registration.setId(2L);registration.setUnitId(3L);registration.setStatus("approved");
        var unit=new BillingUnit();unit.setId(3L);unit.setEventId(4L);
        var event=new BillingEvent();event.setId(4L);event.setOrganizationId(6L);event.setHoldingStatus("cancelled");
        when(dep(OrganizationSessionApi.class).managedOrganization(9L)).thenReturn(Optional.of(new OrganizationSessionApi.ManagedOrganization(6L,"合成组织","fixture",8L)));
        when(dep(OrganizationQualificationApi.class).hasStaffAction("fixture",6L,8L,"payment")).thenReturn(true);
        when(dep(SportsFeeObligationMapper.class).selectOne(any())).thenReturn(obligation);when(dep(SportsFeeObligationMapper.class).selectById(any())).thenReturn(obligation);
        when(dep(BillingRegistrationMapper.class).selectById(any())).thenReturn(registration);when(dep(BillingUnitMapper.class).selectById(any())).thenReturn(unit);when(dep(BillingEventMapper.class).selectById(any())).thenReturn(event);
        when(dep(PlatformTransactionManager.class).getTransaction(any())).thenReturn(mock(TransactionStatus.class));
        when(dep(MutualLock.class).execute(anyString(),anyLong(),anyLong(),any(Supplier.class))).thenAnswer(call->((Supplier<?>)call.getArgument(3)).get());
        when(dep(ScopedJdbc.class).one(anyString(),any(Object[].class))).thenAnswer(call->{
            String sql=call.getArgument(0);Object[] args=(Object[])call.getRawArguments()[1];
            if(sql.contains("resolution->>'requestKey'")){
                var resolution=dep(ObjectMapper.class).readTree(row.getOrDefault("resolution","{}").toString());
                return resolution.path("requestKey").asText().equals(args[1])?Map.of("id",row.get("id")):null;
            }
            return Objects.equals(args[0],row.get("id"))&&Objects.equals(args[2],row.get("obligation_id"))?new LinkedHashMap<>(row):null;
        });
        when(dep(ScopedJdbc.class).list(anyString(),any(Object[].class))).thenReturn(List.of(row));
        when(dep(ScopedJdbc.class).update(anyString(),any(Object[].class))).thenAnswer(call->{
            String sql=call.getArgument(0);Object[] args=(Object[])call.getRawArguments()[1];writes.add(sql);
            if(sql.startsWith("UPDATE asp_payment_exception")){row.put("status","resolved");row.put("owner_id",args[0]);row.put("resolution",args[1]);row.put("version",1);}
            return 1;
        });
    }
    <T>T session(Supplier<T> work){try(var login=mockStatic(LoginHelper.class);var tenant=mockStatic(TenantHelper.class)){
        login.when(LoginHelper::isLogin).thenReturn(true);login.when(LoginHelper::getUserType).thenReturn(UserType.SYS_USER);login.when(LoginHelper::getUserId).thenReturn(9L);login.when(LoginHelper::getTenantId).thenReturn("fixture");
        tenant.when(()->TenantHelper.dynamic(eq("fixture"),any(Supplier.class))).thenAnswer(call->((Supplier<?>)call.getArgument(1)).get());return work.get();
    }}
    FinanceService.PaymentExceptionRecord resolve(String key,String note,int version){return service.resolveDuplicateException(1L,41L,version,note,key);}
    @Test void humanPaymentRoleResolvesOnlyExceptionAndAppendsAudit(){session(()->{
        var result=resolve("resolution-1","合成：核对原账本，重复请求金额输入有误，原款100保留",0);
        assertEquals("resolved",result.status());assertEquals(1,result.version());assertEquals(9L,result.responsibleUserId());assertNotNull(result.resolvedAt());
        assertEquals("settled",obligation.getStatus());assertEquals("approved",registration.getStatus());assertEquals(2,writes.size());
        assertTrue(writes.get(0).startsWith("UPDATE asp_payment_exception"));assertTrue(writes.get(1).startsWith("INSERT INTO asp_audit_event"));
        verifyNoInteractions(dep(SportsPaymentMapper.class),dep(SportsPaymentAllocationMapper.class),dep(SportsRefundMapper.class),dep(RegistrationReviewApi.class));return null;
    });}
    @Test void exactRetryReturnsOriginalResolutionWithoutAnotherAudit(){session(()->{var first=resolve("retry","合成账本依据",0);var repeat=resolve("retry","合成账本依据",0);assertEquals(first,repeat);assertEquals(2,writes.size());return null;});}
    @Test void sameKeyChangedNoteOrVersionCannotReplaceConclusion(){session(()->{resolve("key","合成账本依据",0);assertThrows(ServiceException.class,()->resolve("key","改成另一依据",0));assertThrows(ServiceException.class,()->resolve("key","合成账本依据",1));assertEquals(2,writes.size());return null;});}
    @Test void resolvedExceptionCannotAcceptANewResolutionRequest(){session(()->{resolve("first","合成依据",0);assertThrows(ServiceException.class,()->resolve("second","另一依据",1));assertEquals(2,writes.size());return null;});}
    @Test void staleVersionDoesNotWrite(){session(()->{assertThrows(ServiceException.class,()->resolve("old","合成依据",99));assertTrue(writes.isEmpty());return null;});}
    @Test void emptyAndOverlongEvidenceCannotCloseTheException(){session(()->{assertThrows(ServiceException.class,()->resolve("empty"," ",0));assertThrows(ServiceException.class,()->resolve("long","a".repeat(1001),0));assertTrue(writes.isEmpty());return null;});}
    @Test void noPaymentGrantCannotReadOrResolve(){session(()->{when(dep(OrganizationQualificationApi.class).hasStaffAction("fixture",6L,8L,"payment")).thenReturn(false);assertThrows(ServiceException.class,()->resolve("scope","合成依据",0));assertThrows(ServiceException.class,()->service.records(1L));assertTrue(writes.isEmpty());return null;});}
    @Test void otherOrganizationIsRejectedBeforeWriting(){session(()->{var other=new BillingEvent();other.setOrganizationId(999L);when(dep(BillingEventMapper.class).selectById(any())).thenReturn(other);assertThrows(ServiceException.class,()->resolve("other","合成依据",0));assertTrue(writes.isEmpty());return null;});}
    @Test void otherObligationCannotBorrowThisException(){session(()->{assertThrows(ServiceException.class,()->service.resolveDuplicateException(22L,41L,0,"合成依据","wrong-obligation"));assertTrue(writes.isEmpty());return null;});}
    @Test void unsupportedExceptionAndUnknownStatusRemainUnresolved(){session(()->{row.put("exception_type","amount_mismatch");assertThrows(ServiceException.class,()->resolve("generic","合成依据",0));row.put("exception_type","duplicate_payment");row.put("status","unknown");assertThrows(ServiceException.class,()->resolve("unknown","合成依据",0));assertTrue(writes.isEmpty());return null;});}
    @Test void agentCannotUseTheHumanEntry(){session(()->{TrustedRunContext.bind(new AgentRunAccess.RunPrincipal(1L,"organizer",9L,"fixture",6L,Set.of(),"{}"));try{assertThrows(ServiceException.class,()->resolve("agent","合成依据",0));assertTrue(writes.isEmpty());}finally{TrustedRunContext.clear();}return null;});}
    @Test void participantCannotUseTheHumanEntry(){try(var login=mockStatic(LoginHelper.class)){login.when(LoginHelper::isLogin).thenReturn(true);login.when(LoginHelper::getUserType).thenReturn(UserType.PLATFORM_USER);assertThrows(ServiceException.class,()->resolve("participant","合成依据",0));assertTrue(writes.isEmpty());}}
    @Test void recordsExposeOnlyNecessaryResolutionFields(){session(()->{resolve("view","合成账本依据",0);var value=service.records(1L).exceptions().get(0);assertEquals("合成账本依据",value.resolutionNote());assertEquals(41L,value.exceptionId());assertFalse(Arrays.stream(value.getClass().getRecordComponents()).anyMatch(field->Set.of("resolution","actorAccountId","requestKey").contains(field.getName())));return null;});}
    @Test void optimisticWriteFailureDoesNotAppendBusinessAudit(){session(()->{when(dep(ScopedJdbc.class).update(startsWith("UPDATE asp_payment_exception"),any(Object[].class))).thenReturn(0);assertThrows(ServiceException.class,()->resolve("race","合成依据",0));assertTrue(writes.isEmpty());return null;});}
}
