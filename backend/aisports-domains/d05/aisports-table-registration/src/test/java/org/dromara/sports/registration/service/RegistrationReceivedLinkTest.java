package org.dromara.sports.registration.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.PlatformAccountApi;
import org.dromara.sports.registration.domain.SportsRegistration;
import org.dromara.sports.registration.domain.SportsRegistrationMember;
import org.dromara.sports.registration.mapper.SportsRegistrationMapper;
import org.dromara.sports.registration.mapper.SportsRegistrationMemberMapper;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.util.*;
import java.util.function.Supplier;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 只验证本人列表的私有链接投影；真实详情及资金授权仍由普通角色 HTTP/UI 另验。 */
@Tag("local")
class RegistrationReceivedLinkTest {
    private final Map<Class<?>, Object> deps = new HashMap<>();
    private final RegistrationService service = create();
    private <T> T dep(Class<T> type) { return type.cast(deps.get(type)); }
    private RegistrationService create() {
        try {
            var constructor = RegistrationService.class.getDeclaredConstructors()[0];
            return (RegistrationService) constructor.newInstance(Arrays.stream(constructor.getParameterTypes()).map(type -> {
                Object value = type == ObjectMapper.class ? new ObjectMapper() : mock(type);
                deps.put(type, value); return value;
            }).toArray());
        } catch (ReflectiveOperationException error) { throw new AssertionError(error); }
    }
    private SportsRegistrationMember facts(long owner, String memberStatus, String entryStatus, String token) {
        when(dep(PlatformAccountApi.class).currentAccountId()).thenReturn(Optional.of(201L));
        var member = new SportsRegistrationMember(); member.setId(801L); member.setAccountId(owner);
        member.setRegistrationId(701L); member.setSelfMember(false); member.setStatus(memberStatus); member.setInviteToken(token);
        var registration = new SportsRegistration(); registration.setId(701L); registration.setStatus(entryStatus);
        when(dep(SportsRegistrationMapper.class).selectById(701L)).thenReturn(registration);
        when(dep(SportsRegistrationMemberMapper.class).selectList(any())).thenReturn(List.of(member));
        when(dep(SportsRegistrationMemberMapper.class).selectOne(any())).thenReturn(member);
        return member;
    }
    private void ignoring(Runnable assertion) {
        try (var tenant = mockStatic(TenantHelper.class)) {
            tenant.when(() -> TenantHelper.ignore(any(Supplier.class))).thenAnswer(i -> ((Supplier<?>)i.getArgument(0)).get());
            assertion.run();
        }
    }
    @Test void anonymousCannotEnumerateInvitationLinks() {
        when(dep(PlatformAccountApi.class).currentAccountId()).thenReturn(Optional.empty());
        assertThrows(ServiceException.class, service::listReceived);
        verifyNoInteractions(dep(SportsRegistrationMemberMapper.class));
    }
    @Test void ownedPendingListHasReopenLinkAndExistingResponseState() {
        facts(201L,"pending_confirmation","draft","owned-invite");
        ignoring(() -> {
            var view = service.listReceived().get(0);
            assertEquals("owned-invite", view.inviteToken()); assertTrue(view.canRespond());
        });
    }
    @Test void DefensiveProjectionDropsAnotherOwnersRowBeforeReadingRegistration() {
        facts(999L,"pending_confirmation","draft","foreign-invite");
        ignoring(() -> assertTrue(service.listReceived().isEmpty()));
        verify(dep(SportsRegistrationMapper.class),never()).selectById(701L);
    }
    @Test void HostSelfMemberDoesNotBecomeReceivedInvitation() {
        facts(201L,"confirmed","submitted","self-invite").setSelfMember(true);
        ignoring(() -> assertTrue(service.listReceived().isEmpty()));
    }
    @Test void BlankOrOrphanInviteCannotProduceBrokenLink() {
        facts(201L,"pending_confirmation","draft"," ");
        ignoring(() -> assertNull(service.listReceived().get(0).inviteToken()));
        when(dep(SportsRegistrationMapper.class).selectById(701L)).thenReturn(null);
        ignoring(() -> assertTrue(service.listReceived().isEmpty()));
    }
    @Test void DeclinedAndWithdrawnOwnedHistoryRemainsReadOnly() {
        facts(201L,"declined","draft","declined-invite");
        ignoring(() -> { var view=service.listReceived().get(0); assertEquals("declined-invite",view.inviteToken()); assertFalse(view.canRespond()); assertTrue(view.members().isEmpty()); });
        facts(201L,"confirmed","withdrawn","withdrawn-invite");
        ignoring(() -> { var view=service.listReceived().get(0); assertEquals("withdrawn",view.registrationStatus()); assertFalse(view.canRespond()); });
    }
    @Test void DirectInviteDetailsDoNotReExportTokensAndRejectForeignOwner() {
        facts(201L,"pending_confirmation","draft","owned-invite");
        ignoring(() -> assertNull(service.inviteView("owned-invite").inviteToken()));
        facts(999L,"pending_confirmation","draft","foreign-invite");
        ignoring(() -> assertThrows(ServiceException.class, () -> service.inviteView("foreign-invite")));
    }
}
