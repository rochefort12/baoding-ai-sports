package org.dromara.sports.event.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.InvitationNoticeApi;
import org.dromara.sports.api.PlatformAccountApi;
import org.dromara.sports.event.domain.SportsNotification;
import org.dromara.sports.event.domain.SportsNotificationDelivery;
import org.dromara.sports.event.mapper.SportsNotificationMapper;
import org.dromara.sports.event.mapper.SportsNotificationDeliveryMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Map;

/** 邀请与持久站内信同事务。短信未接通只记失败，不假发、不回滚有效邀请。 */
@Service
@RequiredArgsConstructor
public class InvitationNoticeService implements InvitationNoticeApi {
    private final SportsNotificationMapper notificationMapper;
    private final SportsNotificationDeliveryMapper deliveryMapper;
    private final PlatformAccountApi accountApi;
    private final ObjectMapper objectMapper;

    @Override
    @org.dromara.sports.platform.core.SportsAction(value="legacy.event.invitation_notice_service.created", title="InvitationNoticeService.created", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional(rollbackFor = Exception.class)
    public void created(String kind, Long invitationId, int revision, Long recipientAccountId, String title, String body, String targetPath, boolean requestSms) {
        requireKind(kind);
        if (accountApi.currentAccountId().isEmpty() || recipientAccountId == null || invitationId == null) throw new ServiceException("请使用平台账号办理邀请");
        if (!allowedTarget(kind, targetPath)) throw new ServiceException("邀请或名单通知跳转无效");
        TenantHelper.ignore(() -> {
            String key = kind + ":" + invitationId + ":" + revision;
            SportsNotification notice = notificationMapper.selectOne(Wrappers.<SportsNotification>lambdaQuery().eq(SportsNotification::getRecipientAccountId, recipientAccountId).eq(SportsNotification::getDedupeKey, key));
            if (notice == null) {
                notice = new SportsNotification();
                notice.setTenantId(org.dromara.sports.platform.core.BusinessIdentity.getTenantId());
                notice.setRecipientAccountId(recipientAccountId); notice.setBusinessType(kind); notice.setBusinessId(invitationId); notice.setBusinessRevision(revision); notice.setPurpose(kind); notice.setDedupeKey(key); notice.setVersion(0);
                try { notice.setContent(objectMapper.writeValueAsString(Map.of("title", title, "body", body, "targetPath", targetPath))); }
                catch (JsonProcessingException error) { throw new ServiceException("邀请通知无法保存"); }
                notificationMapper.insert(notice);
                insertDelivery(notice.getTenantId(), notice.getId(), "inbox", "delivered", null);
            }
            if (requestSms && deliveryMapper.selectCount(Wrappers.<SportsNotificationDelivery>lambdaQuery().eq(SportsNotificationDelivery::getNotificationId, notice.getId()).eq(SportsNotificationDelivery::getChannel, "sms")) == 0) {
                // 一份邀请只申请一次短信；仅记录未接通。真实渠道接入须使用账号验证号码及独立模板。
                insertDelivery(notice.getTenantId(), notice.getId(), "sms", "failed", "真实短信未接通；请复制邀请链接联系对方");
            }
            return null;
        });
    }

    @Override
    public Status delivery(String kind, Long invitationId, Long recipientAccountId) {
        requireKind(kind);
        return TenantHelper.ignore(() -> {
            SportsNotification notice = notificationMapper.selectOne(Wrappers.<SportsNotification>lambdaQuery().eq(SportsNotification::getBusinessType, kind).eq(SportsNotification::getBusinessId, invitationId).eq(SportsNotification::getRecipientAccountId, recipientAccountId).orderByDesc(SportsNotification::getId).last("limit 1"));
            if (notice == null) return new Status("not_created", "not_requested", null);
            var sms = deliveryMapper.selectOne(Wrappers.<SportsNotificationDelivery>lambdaQuery().eq(SportsNotificationDelivery::getNotificationId, notice.getId()).eq(SportsNotificationDelivery::getChannel, "sms").orderByDesc(SportsNotificationDelivery::getId).last("limit 1"));
            return new Status("delivered", sms == null ? "not_requested" : sms.getStatus(), sms == null ? null : sms.getFailureReason());
        });
    }

    private void insertDelivery(String tenantId, Long id, String channel, String status, String reason) {
        var delivery = new SportsNotificationDelivery(); delivery.setTenantId(tenantId); delivery.setNotificationId(id); delivery.setChannel(channel); delivery.setAttempt(1); delivery.setStatus(status); delivery.setFailureReason(reason); delivery.setVersion(0);
        if ("delivered".equals(status)) delivery.setDeliveredAt(OffsetDateTime.now(ZoneOffset.ofHours(8)));
        deliveryMapper.insert(delivery);
    }
    private void requireKind(String kind) {
        if (!java.util.Set.of("registration-invite", "team-invite", "registration-roster-removed", "team-joined", "team-member-removed").contains(kind))
            throw new ServiceException("不支持的邀请或名单通知类型");
    }

    /** A known notification kind cannot borrow another kind's private target or accept a redirect. */
    private boolean allowedTarget(String kind, String targetPath) {
        if (targetPath == null) return false;
        return switch (kind) {
            case "registration-invite" -> targetPath.matches("/portal/registration/invite/[a-zA-Z0-9-]+");
            case "team-invite" -> targetPath.matches("/portal/teams/invitations/[0-9]+");
            case "registration-roster-removed" -> targetPath.equals("/portal/registration");
            case "team-joined" -> targetPath.matches("/portal/teams/[0-9]+");
            case "team-member-removed" -> targetPath.equals("/portal/teams");
            default -> false;
        };
    }
}
