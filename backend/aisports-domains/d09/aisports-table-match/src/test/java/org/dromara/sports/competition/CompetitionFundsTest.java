package org.dromara.sports.competition;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.core.lock.MutualLock;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.*;
import org.dromara.sports.competition.domain.*;
import org.dromara.sports.competition.mapper.*;
import org.dromara.sports.competition.service.CompetitionService;
import org.junit.jupiter.api.*;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.*;
import java.util.function.Supplier;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@Tag("local")
class CompetitionFundsTest {
    private final Map<Class<?>,Object> dependencies=new HashMap<>();
    private final CompetitionService service=create();
    private <T>T dep(Class<T> type){return type.cast(dependencies.get(type));}
    private CompetitionService create(){try{var ctor=CompetitionService.class.getDeclaredConstructors()[0];return (CompetitionService)ctor.newInstance(Arrays.stream(ctor.getParameterTypes()).map(type->{Object value=type==ObjectMapper.class?new ObjectMapper():mock(type);dependencies.put(type,value);return value;}).toArray());}catch(ReflectiveOperationException error){throw new AssertionError(error);}}
    private void run(Runnable assertion){
        var event=new CompetitionEvent();event.setId(901L);event.setOrganizationId(6L);event.setHoldingStatus("normal");event.setEndsAt(OffsetDateTime.now().plusDays(1));
        var unit=new CompetitionUnit();unit.setId(501L);unit.setEventId(901L);
        when(dep(CompetitionEventMapper.class).selectById(901L)).thenReturn(event);
        when(dep(CompetitionUnitMapper.class).selectById(501L)).thenReturn(unit);
        when(dep(OrganizationSessionApi.class).managedOrganization(201L)).thenReturn(Optional.of(new OrganizationSessionApi.ManagedOrganization(6L,"Fixture","fixture",8L)));
        when(dep(OrganizationQualificationApi.class).hasStaffAction("fixture",6L,8L,"organize")).thenReturn(true);
        when(dep(MutualLock.class).execute(anyString(),anyLong(),anyLong(),any(Supplier.class))).thenAnswer(i->((Supplier<?>)i.getArgument(3)).get());
        try(var login=mockStatic(LoginHelper.class);var tenant=mockStatic(TenantHelper.class)){
            login.when(LoginHelper::getUserId).thenReturn(201L);
            tenant.when(()->TenantHelper.dynamic(eq("fixture"),any(Supplier.class))).thenAnswer(i->((Supplier<?>)i.getArgument(1)).get());
            assertion.run();
        }
    }
    private RegistrationRosterApi.RosterView roster(){return new RegistrationRosterApi.RosterView(701L,801L,501L,901L,"Pair",List.of(new RegistrationRosterApi.RosterPerson(401L,"Fixture")));}
    private FeeApi.ObligationView obligation(String status){return new FeeApi.ObligationView(1L,2L,new BigDecimal("100.00"),"offline",status,"Fixture",false,null);}
    @Test void shortFundsPreventAttendanceAndGrowth(){run(()->{when(dep(RegistrationRosterApi.class).approvedRosters("fixture",901L)).thenReturn(List.of(roster()));when(dep(FeeApi.class).current("fixture",701L)).thenReturn(Optional.of(obligation("open")));assertTrue(assertThrows(ServiceException.class,()->service.checkIn(901L,401L,"short")).getMessage().contains("收款不足"));verifyNoInteractions(dep(CompetitionCheckinMapper.class),dep(GrowthFactApi.class));});}
    @Test void settledHintIsRecheckedUnderThePaymentLock(){run(()->{when(dep(RegistrationRosterApi.class).approvedRosters("fixture",901L)).thenReturn(List.of(roster()));when(dep(FeeApi.class).current("fixture",701L)).thenReturn(Optional.of(obligation("settled")));doThrow(new ServiceException("收款不足")).when(dep(FeeApi.class)).requireParticipationReady("fixture",701L);assertThrows(ServiceException.class,()->service.checkIn(901L,401L,"reversal-race"));verify(dep(FeeApi.class)).requireParticipationReady("fixture",701L);verifyNoInteractions(dep(CompetitionCheckinMapper.class),dep(GrowthFactApi.class));});}
    @Test void fixtureLocksUseRegistrationOrderRegardlessOfSide(){run(()->{doThrow(new ServiceException("收款不足")).when(dep(FeeApi.class)).requireParticipationReady("fixture",702L);assertThrows(ServiceException.class,()->service.createMatch(501L,"M",702L,701L,"sorted"));var order=inOrder(dep(FeeApi.class));order.verify(dep(FeeApi.class)).requireParticipationReady("fixture",701L);order.verify(dep(FeeApi.class)).requireParticipationReady("fixture",702L);verifyNoInteractions(dep(CompetitionMatchMapper.class),dep(CompetitionMatchEntryMapper.class));});}

    @Test void freeOtherProjectCannotAuthorizeUnpaidSelectedProject(){run(()->{
        var other=new RegistrationRosterApi.RosterView(702L,802L,502L,901L,"Free other",roster().people());
        when(dep(RegistrationRosterApi.class).approvedRosters("fixture",901L)).thenReturn(List.of(roster(),other));
        when(dep(FeeApi.class).current("fixture",701L)).thenReturn(Optional.of(obligation("open")));
        when(dep(FeeApi.class).current("fixture",702L)).thenReturn(Optional.of(obligation("not_required")));
        assertTrue(assertThrows(ServiceException.class,()->service.checkIn(901L,501L,401L,"scoped-fee")).getMessage().contains("本项目"));
        verify(dep(FeeApi.class),never()).current("fixture",702L);verifyNoInteractions(dep(CompetitionCheckinMapper.class),dep(GrowthFactApi.class));
    });}
    @Test void multiProjectLegacyCallerMustChooseOneProject(){run(()->{
        when(dep(RegistrationRosterApi.class).approvedRosters("fixture",901L)).thenReturn(List.of(roster(),new RegistrationRosterApi.RosterView(702L,802L,502L,901L,"Other",roster().people())));
        assertTrue(assertThrows(ServiceException.class,()->service.checkIn(901L,401L,"ambiguous")).getMessage().contains("明确选择"));
        verifyNoInteractions(dep(CompetitionCheckinMapper.class),dep(FeeApi.class));
    });}
    @Test void unitFromAnotherEventCannotAuthorizeAttendance(){run(()->{
        var unit=new CompetitionUnit();unit.setId(502L);unit.setEventId(902L);when(dep(CompetitionUnitMapper.class).selectById(502L)).thenReturn(unit);
        var event=new CompetitionEvent();event.setId(902L);event.setOrganizationId(6L);when(dep(CompetitionEventMapper.class).selectById(902L)).thenReturn(event);
        assertTrue(assertThrows(ServiceException.class,()->service.checkIn(901L,502L,401L,"other-event")).getMessage().contains("不属于"));
        verifyNoInteractions(dep(CompetitionCheckinMapper.class),dep(FeeApi.class));
    });}
    @Test void selectedProjectRequiresItsOwnApprovedRoster(){run(()->{
        when(dep(RegistrationRosterApi.class).approvedRosters("fixture",901L)).thenReturn(List.of(new RegistrationRosterApi.RosterView(702L,802L,502L,901L,"Other",roster().people())));
        assertTrue(assertThrows(ServiceException.class,()->service.checkIn(901L,501L,401L,"wrong-roster")).getMessage().contains("本项目已通过"));
        verifyNoInteractions(dep(CompetitionCheckinMapper.class),dep(FeeApi.class));
    });}
    @Test void unknownLegacyAttendanceIsSeparateFromCurrentProjectAttendance(){run(()->{
        when(dep(RegistrationRosterApi.class).approvedRosters("fixture",901L)).thenReturn(List.of(roster(),new RegistrationRosterApi.RosterView(702L,802L,502L,901L,"Other",roster().people())));
        when(dep(FeeApi.class).current(eq("fixture"),anyLong())).thenReturn(Optional.of(obligation("not_required")));
        var old=new CompetitionCheckin();old.setPersonId(401L);var scoped=new CompetitionCheckin();scoped.setUnitId(501L);scoped.setPersonId(401L);
        when(dep(CompetitionCheckinMapper.class).selectList(any())).thenReturn(List.of(old,scoped));
        var rows=service.eligible(901L);assertEquals(2,rows.size());assertTrue(rows.get(0).checkedIn());assertFalse(rows.get(1).checkedIn());assertTrue(rows.stream().allMatch(CompetitionService.EligiblePerson::legacyEventCheckin));
    });}
}
