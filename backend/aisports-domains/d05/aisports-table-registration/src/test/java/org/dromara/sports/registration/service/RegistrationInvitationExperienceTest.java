package org.dromara.sports.registration.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.core.lock.MutualLock;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.*;
import org.dromara.sports.platform.core.ScopedJdbc;
import org.dromara.sports.registration.domain.*;
import org.dromara.sports.registration.mapper.*;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.SimpleTransactionStatus;
import java.time.LocalDate;
import java.util.*;
import java.util.function.Supplier;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** Service-level privacy and transactional notification checks; real accounts and browser delivery are separate. */
@Tag("local")
class RegistrationInvitationExperienceTest {
    private final Map<Class<?>,Object> deps=new HashMap<>();
    private final RegistrationService service=create();
    private <T>T dep(Class<T> type){return type.cast(deps.get(type));}
    private RegistrationService create(){try{var c=RegistrationService.class.getDeclaredConstructors()[0];return (RegistrationService)c.newInstance(Arrays.stream(c.getParameterTypes()).map(t->{Object v=t==ObjectMapper.class?new ObjectMapper().findAndRegisterModules():mock(t);deps.put(t,v);return v;}).toArray());}catch(ReflectiveOperationException e){throw new AssertionError(e);}}
    private SportsRegistrationMember prepare(){
        when(dep(PlatformAccountApi.class).currentAccountId()).thenReturn(Optional.of(201L));
        when(dep(PlatformAccountApi.class).currentRegistrationProfile()).thenReturn(Optional.of(new PlatformAccountApi.RegistrationProfile(201L,301L,"模拟邀请人","male",LocalDate.of(2000,1,1),"private-phone")));
        var row=new SportsRegistration();row.setId(701L);row.setTenantId("fixture");row.setUnitId(501L);row.setSubmitterAccountId(201L);row.setStatus("draft");row.setVersion(0);
        when(dep(SportsRegistrationMapper.class).selectById(701L)).thenReturn(row);
        var unit=new SportsCompetitionUnit();unit.setId(501L);unit.setEventId(601L);unit.setName("模拟双打");unit.setEntryType("pair");unit.setStatus("open");unit.setMaxMembers(2);
        when(dep(SportsCompetitionUnitMapper.class).selectById(501L)).thenReturn(unit);
        var member=new SportsRegistrationMember();member.setId(801L);member.setRegistrationId(701L);member.setUnitId(501L);member.setAccountId(202L);member.setStatus("pending_confirmation");member.setVersion(3);member.setInviteToken("private-token");member.setOccupying(false);
        when(dep(SportsRegistrationMemberMapper.class).selectById(801L)).thenReturn(member);when(dep(SportsRegistrationMemberMapper.class).selectOne(any())).thenReturn(member);when(dep(SportsRegistrationMemberMapper.class).selectList(any())).thenReturn(List.of(member));when(dep(SportsRegistrationMemberMapper.class).delete(any())).thenReturn(1);
        when(dep(FeeApi.class).current("fixture",701L)).thenReturn(Optional.empty());
        when(dep(PlatformTransactionManager.class).getTransaction(any())).thenReturn(new SimpleTransactionStatus());
        when(dep(MutualLock.class).execute(anyString(),anyLong(),anyLong(),any(Supplier.class))).thenAnswer(i->((Supplier<?>)i.getArgument(3)).get());
        return member;
    }
    private void tenant(Runnable action){try(var scope=mockStatic(TenantHelper.class)){scope.when(()->TenantHelper.ignore(any(Supplier.class))).thenAnswer(i->((Supplier<?>)i.getArgument(0)).get());scope.when(()->TenantHelper.dynamic(anyString(),any(Supplier.class))).thenAnswer(i->((Supplier<?>)i.getArgument(1)).get());action.run();}}
    @Test void managerSeesPendingIdentityButItDoesNotBecomeConfirmedSnapshot(){
        prepare();when(dep(ScopedJdbc.class).list(anyString(),eq("fixture"),eq(701L))).thenReturn(List.of(Map.of("account_id",202L,"label","模拟受邀者","mobile_tail","1234")));
        tenant(()->{var card=service.remindInvitation(701L,801L).members().get(0);assertNull(card.legalName());assertEquals("模拟受邀者",card.invitationName());assertEquals("1234",card.mobileTail());assertEquals("pending_confirmation",card.status());assertEquals("private-token",card.inviteToken());});
        verify(dep(InvitationNoticeApi.class)).created(eq("registration-invite"),eq(801L),eq(3),eq(202L),anyString(),contains("模拟邀请人"),eq("/portal/registration/invite/private-token"),eq(false));
    }
    @Test void defensiveProjectionNeverExportsAMalformedFullPhone(){
        prepare();when(dep(ScopedJdbc.class).list(anyString(),eq("fixture"),eq(701L))).thenReturn(List.of(Map.of("account_id",202L,"label","模拟受邀者","mobile_tail","16600001234")));
        tenant(()->assertNull(service.remindInvitation(701L,801L).members().get(0).mobileTail()));
    }
    @Test void confirmedMemberHasNoStaleCopyableInviteToken(){
        var member=prepare();member.setStatus("confirmed");member.setPersonSnapshot("{\"legalName\":\"已确认姓名\"}");
        tenant(()->{try{var method=RegistrationService.class.getDeclaredMethod("toEntry",SportsRegistration.class,SportsCompetitionUnit.class,boolean.class);method.setAccessible(true);var result=(RegistrationService.EntryCard)method.invoke(service,dep(SportsRegistrationMapper.class).selectById(701L),dep(SportsCompetitionUnitMapper.class).selectById(501L),true);assertNull(result.members().get(0).inviteToken());assertEquals("已确认姓名",result.members().get(0).legalName());}catch(ReflectiveOperationException e){throw new AssertionError(e);}});
    }
    @Test void wrongRecipientCannotReadIdentityOrResendOnOthersBehalf(){
        prepare();when(dep(PlatformAccountApi.class).currentAccountId()).thenReturn(Optional.of(999L));
        tenant(()->assertThrows(ServiceException.class,()->service.inviteView("private-token")));
        verifyNoInteractions(dep(ScopedJdbc.class),dep(InvitationNoticeApi.class));
    }
    @Test void removeWritesOnlyThatRecipientsNoticeInSameTransaction(){
        prepare();tenant(()->service.removeMember(701L,801L));
        verify(dep(SportsRegistrationMemberMapper.class)).delete(any());
        verify(dep(InvitationNoticeApi.class)).created(eq("registration-roster-removed"),eq(801L),eq(3),eq(202L),eq("参赛名单已调整"),contains("模拟双打"),eq("/portal/registration"),eq(false));
        verify(dep(PlatformTransactionManager.class)).commit(any());
    }
    @Test void failedOptimisticRemovalCannotProduceANotice(){
        prepare();when(dep(SportsRegistrationMemberMapper.class).delete(any())).thenReturn(0);
        tenant(()->assertThrows(ServiceException.class,()->service.removeMember(701L,801L)));
        verifyNoInteractions(dep(InvitationNoticeApi.class));verify(dep(PlatformTransactionManager.class)).rollback(any());
    }
    @Test void notificationFailureRollsBackMemberRemoval(){
        prepare();doThrow(new ServiceException("消息暂时无法保存")).when(dep(InvitationNoticeApi.class)).created(eq("registration-roster-removed"),anyLong(),anyInt(),anyLong(),anyString(),anyString(),anyString(),anyBoolean());
        tenant(()->assertThrows(ServiceException.class,()->service.removeMember(701L,801L)));
        verify(dep(PlatformTransactionManager.class)).rollback(any());verify(dep(PlatformTransactionManager.class),never()).commit(any());
    }
    @Test void foreignMemberCannotBeRemovedOrReminded(){
        prepare().setRegistrationId(999L);
        tenant(()->{assertThrows(ServiceException.class,()->service.removeMember(701L,801L));assertThrows(ServiceException.class,()->service.remindInvitation(701L,801L));});
        verify(dep(SportsRegistrationMemberMapper.class),never()).delete(any());verifyNoInteractions(dep(InvitationNoticeApi.class),dep(ScopedJdbc.class));
    }
}
