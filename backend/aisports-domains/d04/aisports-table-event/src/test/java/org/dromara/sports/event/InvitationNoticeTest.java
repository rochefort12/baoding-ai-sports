package org.dromara.sports.event;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.PlatformAccountApi;
import org.dromara.sports.event.domain.SportsNotification;
import org.dromara.sports.event.domain.SportsNotificationDelivery;
import org.dromara.sports.event.mapper.SportsNotificationMapper;
import org.dromara.sports.event.mapper.SportsNotificationDeliveryMapper;
import org.dromara.sports.event.service.InvitationNoticeService;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import java.util.Optional;
import java.util.function.Supplier;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 隔离依赖验证通知去重、独立渠道状态及跨租户关联；不发送真实短信。 */
@Tag("local")
class InvitationNoticeTest {
    private final SportsNotificationMapper notices = mock(SportsNotificationMapper.class);
    private final SportsNotificationDeliveryMapper deliveries = mock(SportsNotificationDeliveryMapper.class);
    private final PlatformAccountApi accounts = mock(PlatformAccountApi.class);
    private final InvitationNoticeService service = new InvitationNoticeService(notices, deliveries, accounts, new ObjectMapper());
    private void send(boolean sms) { service.created("team-invite", 601L, 0, 202L, "虚构邀请", "虚构内容", "/portal/teams/invitations/601", sms); }
    private void scope(Runnable action) {
        when(accounts.currentAccountId()).thenReturn(Optional.of(201L));
        doAnswer(i -> { ((SportsNotification)i.getArgument(0)).setId(901L); return 1; }).when(notices).insert(any(SportsNotification.class));
        try (var tenant = mockStatic(TenantHelper.class); var login = mockStatic(LoginHelper.class)) {
            tenant.when(() -> TenantHelper.ignore(any(Supplier.class))).thenAnswer(i -> ((Supplier<?>)i.getArgument(0)).get());
            login.when(LoginHelper::getTenantId).thenReturn("platform-fixture"); action.run();
        }
    }
    @Test void defaultOnlyInboxAndTenantMatchesParent() { scope(() -> {
        send(false);
        var notice = ArgumentCaptor.forClass(SportsNotification.class); verify(notices).insert(notice.capture());
        var delivery = ArgumentCaptor.forClass(SportsNotificationDelivery.class); verify(deliveries).insert(delivery.capture());
        assertEquals("team-invite:601:0", notice.getValue().getDedupeKey()); assertTrue(notice.getValue().getContent().contains("/portal/teams/invitations/601"));
        assertEquals(notice.getValue().getTenantId(), delivery.getValue().getTenantId());
        assertEquals("inbox", delivery.getValue().getChannel()); assertEquals("delivered", delivery.getValue().getStatus());
    }); }
    @Test void optionalSmsFailedDoesNotInvalidateInbox() { scope(() -> {
        send(true); var captured = ArgumentCaptor.forClass(SportsNotificationDelivery.class); verify(deliveries, times(2)).insert(captured.capture());
        var sms = captured.getAllValues().get(1); assertEquals("sms", sms.getChannel()); assertEquals("failed", sms.getStatus()); assertNull(sms.getDeliveredAt()); assertTrue(sms.getFailureReason().contains("未接通"));
    }); }
    @Test void repeatSameInvitationDoesNotCreateInboxOrSms() { scope(() -> {
        var existing = new SportsNotification(); existing.setId(901L); existing.setTenantId("platform-fixture");
        when(notices.selectOne(any())).thenReturn(existing); when(deliveries.selectCount(any())).thenReturn(1L);
        send(true); verify(notices, never()).insert(any(SportsNotification.class)); verify(deliveries, never()).insert(any(SportsNotificationDelivery.class));
    }); }
    @Test void missingAccountDeniedBeforeDatabase() {
        when(accounts.currentAccountId()).thenReturn(Optional.empty()); assertThrows(ServiceException.class, () -> send(false)); verifyNoInteractions(notices, deliveries);
    }
    @Test void unsafeTargetDeniedBeforeDatabase() {
        when(accounts.currentAccountId()).thenReturn(Optional.of(201L)); assertThrows(ServiceException.class, () -> service.created("team-invite",601L,0,202L,"标题","内容","/portal/teams/invitations/601?redirect=https://example.com",false)); verifyNoInteractions(notices,deliveries);
    }
    @Test void oldInvitationHasNoInventedDelivery() { scope(() -> {
        var state=service.delivery("team-invite",601L,202L); assertEquals("not_created",state.inboxStatus()); assertEquals("not_requested",state.smsStatus()); verify(deliveries,never()).insert(any(SportsNotificationDelivery.class));
    }); }
    @Test void removalNoticeIsDurableAndTargetsAnAccessibleOwnList() { scope(() -> {
        service.created("registration-roster-removed", 801L, 3, 202L, "名单调整", "你的本次邀请已取消", "/portal/registration", false);
        var notice=ArgumentCaptor.forClass(SportsNotification.class); verify(notices).insert(notice.capture());
        assertEquals("registration-roster-removed:801:3",notice.getValue().getDedupeKey());
        assertEquals(202L,notice.getValue().getRecipientAccountId()); assertTrue(notice.getValue().getContent().contains("/portal/registration"));
        verify(deliveries).insert(any(SportsNotificationDelivery.class));
    }); }
    @Test void knownKindsCannotBorrowAnotherInvitationsPrivateTarget() {
        when(accounts.currentAccountId()).thenReturn(Optional.of(201L));
        assertThrows(ServiceException.class,()->service.created("registration-roster-removed",801L,0,202L,"调整","内容","/portal/registration/invite/old-token",false));
        assertThrows(ServiceException.class,()->service.created("registration-invite",801L,0,202L,"邀请","内容","/portal/teams/invitations/601",false));
        assertThrows(ServiceException.class,()->service.created("team-joined",601L,0,201L,"加入","内容","/portal/teams/601?redirect=https://example.com",false));
        verifyNoInteractions(notices,deliveries);
    }
    @Test void teamMembershipChangesUseSeparateKindsAndSafeKnownTargets() { scope(() -> {
        service.created("team-joined",601L,0,201L,"队员加入","内容","/portal/teams/601",false);
        service.created("team-member-removed",602L,2,202L,"队伍调整","内容","/portal/teams",false);
        var notice=ArgumentCaptor.forClass(SportsNotification.class); verify(notices,times(2)).insert(notice.capture());
        assertEquals("team-joined:601:0",notice.getAllValues().get(0).getDedupeKey());
        assertEquals("team-member-removed:602:2",notice.getAllValues().get(1).getDedupeKey());
    }); }
}
