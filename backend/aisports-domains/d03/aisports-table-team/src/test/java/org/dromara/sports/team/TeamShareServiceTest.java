package org.dromara.sports.team;

import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.core.lock.MutualLock;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.PlatformAccountApi;
import org.dromara.sports.api.InvitationNoticeApi;
import org.dromara.sports.team.domain.*;
import org.dromara.sports.team.mapper.*;
import org.dromara.sports.team.service.TeamService;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.SimpleTransactionStatus;
import java.time.*;
import java.util.*;
import java.util.function.Supplier;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 服务层边界验证；并发约束、真实登录和普通角色 UI 另由隔离脚本执行。 */
@Tag("local")
class TeamShareServiceTest {
    private final Map<Class<?>, Object> deps = new HashMap<>();
    private final TeamService service = create();
    private final SportsTeam team = new SportsTeam();
    private final SportsTeamInvitation source = new SportsTeamInvitation();
    private final SportsTeamMember captain = new SportsTeamMember();
    private <T> T dep(Class<T> type) { return type.cast(deps.get(type)); }
    private TeamService create() {
        try { var c = TeamService.class.getDeclaredConstructors()[0]; return (TeamService)c.newInstance(Arrays.stream(c.getParameterTypes()).map(type -> { var value = mock(type); deps.put(type, value); return value; }).toArray()); }
        catch (ReflectiveOperationException error) { throw new AssertionError(error); }
    }
    private void facts() {
        team.setId(501L); team.setName("合成分享队伍"); team.setCaptainPersonId(401L); team.setStatus("active");
        source.setId(601L); source.setTeamId(501L); source.setInvitationKind("share"); source.setInviterPersonId(401L); source.setInviterAccountId(202L); source.setStatus("pending"); source.setInviteToken("a".repeat(64)); source.setExpiresAt(OffsetDateTime.now().plusDays(7));
        captain.setPersonId(401L); captain.setRole("captain"); captain.setStatus("active");
        when(dep(SportsTeamMapper.class).selectById(501L)).thenReturn(team);
        when(dep(SportsTeamMapper.class).lockTeam(501L)).thenReturn(team);
        when(dep(SportsTeamInvitationMapper.class).selectOne(any())).thenReturn(source);
        when(dep(SportsTeamInvitationMapper.class).selectCount(any())).thenReturn(0L);
        when(dep(SportsTeamInvitationMapper.class).selectList(any())).thenReturn(List.of());
        when(dep(SportsTeamJoinRequestMapper.class).selectList(any())).thenReturn(List.of());
        when(dep(PlatformAccountApi.class).currentRegistrationProfile()).thenReturn(Optional.of(new PlatformAccountApi.RegistrationProfile(201L, 301L, "合成本人", "male", LocalDate.of(2000,1,1), "13900000000")));
        when(dep(PlatformAccountApi.class).memberLabels(List.of(401L))).thenReturn(List.of(new PlatformAccountApi.MemberLabel(401L,202L,"合成队长",true)));
        when(dep(MutualLock.class).execute(anyString(), anyLong(), anyLong(), any())).thenAnswer(i -> ((Supplier<?>)i.getArgument(3)).get());
        when(dep(PlatformTransactionManager.class).getTransaction(any())).thenReturn(new SimpleTransactionStatus());
    }
    private org.mockito.MockedStatic<TenantHelper> tenant() {
        var value = mockStatic(TenantHelper.class);
        value.when(() -> TenantHelper.ignore(any(Supplier.class))).thenAnswer(i -> ((Supplier<?>)i.getArgument(0)).get());
        return value;
    }
    @Test void anonymousPreviewContainsOnlyTeamAndExpiry() {
        facts(); when(dep(SportsTeamMemberMapper.class).selectOne(any())).thenReturn(captain);
        try (var ignored = tenant()) {
            var card = service.previewShare("a".repeat(64));
            assertEquals("合成分享队伍", card.teamName()); assertEquals("pending", card.status());
            verify(dep(SportsTeamMemberMapper.class), never()).selectList(any());
            verify(dep(PlatformAccountApi.class)).memberLabels(List.of(401L));
            verify(dep(PlatformAccountApi.class), never()).currentRegistrationProfile();
        }
    }
    @Test void missingProfileCannotReadOrAcceptPrivateConfirmation() {
        facts(); when(dep(PlatformAccountApi.class).currentRegistrationProfile()).thenReturn(Optional.empty());
        assertThrows(ServiceException.class, () -> service.acceptShare("a".repeat(64), true));
        verifyNoInteractions(dep(SportsTeamInvitationMapper.class), dep(SportsTeamMemberMapper.class));
    }
    @Test void nonCaptainCannotReadShareCredential() {
        facts(); try (var ignored = tenant()) { assertThrows(ServiceException.class, () -> service.shareLink(501L)); }
        verify(dep(SportsTeamInvitationMapper.class), never()).selectOne(any());
    }
    @Test void explicitAcceptanceWritesOwnMembershipAndSourceOnce() {
        facts(); when(dep(SportsTeamMemberMapper.class).selectOne(any())).thenReturn(null, captain);
        try (var ignored = tenant()) { assertFalse(service.acceptShare("a".repeat(64), true).alreadyMember()); }
        verify(dep(SportsTeamMapper.class)).lockTeam(501L);
        var saved = org.mockito.ArgumentCaptor.forClass(SportsTeamInvitation.class);
        verify(dep(SportsTeamInvitationMapper.class)).insert(saved.capture());
        assertEquals(301L, saved.getValue().getTargetPersonId()); assertEquals(601L, saved.getValue().getShareInvitationId());
        verify(dep(SportsTeamMemberMapper.class)).insert(any(SportsTeamMember.class));
        verify(dep(InvitationNoticeApi.class)).created(eq("team-joined"), any(), eq(0), eq(202L), anyString(), anyString(), eq("/portal/teams/501"), eq(false));
    }
    @Test void retryByCurrentMemberDoesNotInsertOrNotify() {
        facts(); var member = new SportsTeamMember(); member.setRole("member");
        when(dep(SportsTeamMemberMapper.class).selectOne(any())).thenReturn(member, captain);
        when(dep(SportsTeamInvitationMapper.class).selectCount(any())).thenReturn(1L);
        try (var ignored = tenant()) { assertTrue(service.acceptShare("a".repeat(64), true).alreadyMember()); }
        verify(dep(SportsTeamInvitationMapper.class), never()).insert(any(SportsTeamInvitation.class));
        verify(dep(SportsTeamMemberMapper.class), never()).insert(any(SportsTeamMember.class));
        verifyNoInteractions(dep(InvitationNoticeApi.class));
    }
    @Test void formerMemberCannotBeRestoredByRepeatedAcceptance() {
        facts(); when(dep(SportsTeamMemberMapper.class).selectOne(any())).thenReturn(null, captain);
        when(dep(SportsTeamInvitationMapper.class).selectCount(any())).thenReturn(1L);
        try (var ignored = tenant()) { assertThrows(ServiceException.class, () -> service.acceptShare("a".repeat(64), true)); }
        verify(dep(SportsTeamMemberMapper.class), never()).insert(any(SportsTeamMember.class));
    }
}
