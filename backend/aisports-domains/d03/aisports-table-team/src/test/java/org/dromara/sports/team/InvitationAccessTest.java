package org.dromara.sports.team;

import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.PlatformAccountApi;
import org.dromara.sports.team.domain.SportsTeam;
import org.dromara.sports.team.domain.SportsTeamInvitation;
import org.dromara.sports.team.mapper.SportsTeamMapper;
import org.dromara.sports.team.mapper.SportsTeamInvitationMapper;
import org.dromara.sports.team.mapper.SportsTeamMemberMapper;
import org.dromara.sports.team.service.TeamService;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.util.*;
import java.util.function.Supplier;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;

/** 深链读权限独立验证；不加入真实队伍，不读取队内其他成员。 */
@Tag("local")
class InvitationAccessTest {
    private final Map<Class<?>,Object> deps=new HashMap<>();
    private final TeamService service=create();
    private <T>T dep(Class<T> type){return type.cast(deps.get(type));}
    private TeamService create(){try{var c=TeamService.class.getDeclaredConstructors()[0];return (TeamService)c.newInstance(Arrays.stream(c.getParameterTypes()).map(t->{var m=mock(t);deps.put(t,m);return m;}).toArray());}catch(ReflectiveOperationException e){throw new AssertionError(e);}}
    private void facts(long target){
        when(dep(PlatformAccountApi.class).currentRegistrationProfile()).thenReturn(Optional.of(new PlatformAccountApi.RegistrationProfile(201L,301L,"虚构本人","male",java.time.LocalDate.of(2000,1,1),"13900000000")));
        var invite=new SportsTeamInvitation();invite.setId(611L);invite.setTeamId(601L);invite.setTargetPersonId(target);invite.setStatus("pending");when(dep(SportsTeamInvitationMapper.class).selectById(611L)).thenReturn(invite);
        var team=new SportsTeam();team.setId(601L);team.setName("虚构队伍");when(dep(SportsTeamMapper.class).selectById(601L)).thenReturn(team);
        when(dep(PlatformAccountApi.class).memberLabels(any())).thenReturn(List.of());
    }
    @Test void targetMayReadInviteButNotRoster(){facts(301L);try(var tenant=mockStatic(TenantHelper.class)){tenant.when(()->TenantHelper.ignore(any(Supplier.class))).thenAnswer(i->((Supplier<?>)i.getArgument(0)).get());var card=service.invitation(611L);assertEquals("虚构队伍",card.teamName());assertEquals("pending",card.status());verifyNoInteractions(dep(SportsTeamMemberMapper.class));}}
    @Test void otherPersonDeniedBeforeTeamDetails(){facts(999L);try(var tenant=mockStatic(TenantHelper.class)){tenant.when(()->TenantHelper.ignore(any(Supplier.class))).thenAnswer(i->((Supplier<?>)i.getArgument(0)).get());assertThrows(ServiceException.class,()->service.invitation(611L));verifyNoInteractions(dep(SportsTeamMapper.class),dep(SportsTeamMemberMapper.class));verify(dep(PlatformAccountApi.class),never()).memberLabels(any());}}
    @Test void noProfileDeniedBeforeDatabase(){when(dep(PlatformAccountApi.class).currentRegistrationProfile()).thenReturn(Optional.empty());assertThrows(ServiceException.class,()->service.invitation(611L));verifyNoInteractions(dep(SportsTeamMapper.class),dep(SportsTeamInvitationMapper.class));}
}
