package org.dromara.sports.event.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.EventNoticeApi;
import org.dromara.sports.api.PlatformAccountApi;
import org.dromara.sports.event.domain.SportsEvent;
import org.dromara.sports.event.domain.SportsNotification;
import org.dromara.sports.event.domain.SportsNotificationDelivery;
import org.dromara.sports.event.mapper.SportsNotificationDeliveryMapper;
import org.dromara.sports.event.mapper.SportsNotificationMapper;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 赛事取消后的站内信。短信渠道只记下未接通，不把站内信成功当成短信成功。
 */
@Service
@RequiredArgsConstructor
public class EventCancellationNoticeService {

    private static final ZoneOffset SHANGHAI = ZoneOffset.ofHours(8);
    private static final String SMS_NOT_CONNECTED = "真实短信未接通";

    private final EventNoticeApi eventNoticeApi;
    private final PlatformAccountApi platformAccountApi;
    private final SportsNotificationMapper notificationMapper;
    private final SportsNotificationDeliveryMapper deliveryMapper;
    private final ObjectMapper objectMapper;

    public void notifyCancelled(SportsEvent event) {
        List<Long> accounts = eventNoticeApi.cancelRecipientAccountIds(event.getTenantId(), event.getId());
        for (Long accountId : accounts) {
            writeOne(event, accountId);
        }
    }

    public List<NoticeCard> mine() {
        Long accountId = platformAccountApi.currentAccountId().orElseThrow(() -> new ServiceException("请使用参赛者账号登录"));
        List<SportsNotification> rows = TenantHelper.ignore(() -> notificationMapper.selectList(Wrappers.<SportsNotification>lambdaQuery()
            .eq(SportsNotification::getRecipientAccountId, accountId)
            .orderByDesc(SportsNotification::getId)));
        return rows.stream().map(this::toCard).toList();
    }

    public List<DeliveryCard> deliveries(Long eventId) {
        List<SportsNotification> notices = notificationMapper.selectList(Wrappers.<SportsNotification>lambdaQuery()
            .eq(SportsNotification::getBusinessType, "event")
            .eq(SportsNotification::getBusinessId, eventId)
            .eq(SportsNotification::getPurpose, "event-cancel"));
        List<DeliveryCard> cards = new java.util.ArrayList<>();
        for (SportsNotification notice : notices) {
            List<SportsNotificationDelivery> rows = deliveryMapper.selectList(Wrappers.<SportsNotificationDelivery>lambdaQuery()
                .eq(SportsNotificationDelivery::getNotificationId, notice.getId())
                .orderByAsc(SportsNotificationDelivery::getId));
            for (SportsNotificationDelivery row : rows) {
                cards.add(new DeliveryCard(row.getId(), notice.getId(), notice.getRecipientAccountId(), row.getChannel(),
                    row.getAttempt(), row.getStatus(), row.getFailureReason()));
            }
        }
        return cards;
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.event.eventcancellationnoticeservice.retrysms",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public DeliveryCard retrySms(Long notificationId) {
        SportsNotification notice = notificationMapper.selectById(notificationId);
        if (notice == null || !"event-cancel".equals(notice.getPurpose())) {
            throw new ServiceException("消息不存在");
        }
        Integer attempt = deliveryMapper.selectList(Wrappers.<SportsNotificationDelivery>lambdaQuery()
                .eq(SportsNotificationDelivery::getNotificationId, notice.getId())
                .eq(SportsNotificationDelivery::getChannel, "sms"))
            .stream().map(SportsNotificationDelivery::getAttempt).max(Integer::compareTo).orElse(0);
        SportsNotificationDelivery delivery = new SportsNotificationDelivery();
        delivery.setNotificationId(notice.getId());
        delivery.setChannel("sms");
        delivery.setAttempt(attempt + 1);
        delivery.setStatus("failed");
        delivery.setFailureReason(SMS_NOT_CONNECTED);
        delivery.setVersion(0);
        deliveryMapper.insert(delivery);
        return new DeliveryCard(delivery.getId(), notice.getId(), notice.getRecipientAccountId(), "sms",
            delivery.getAttempt(), "failed", SMS_NOT_CONNECTED);
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.event.eventcancellationnoticeservice.markread",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public NoticeCard markRead(Long notificationId) {
        Long accountId = platformAccountApi.currentAccountId().orElseThrow(() -> new ServiceException("请使用参赛者账号登录"));
        SportsNotification located = TenantHelper.ignore(() -> notificationMapper.selectById(notificationId));
        if (located == null || !accountId.equals(located.getRecipientAccountId())) {
            throw new ServiceException("消息不存在");
        }
        if (located.getReadAt() == null) {
            TenantHelper.dynamic(located.getTenantId(), () -> {
                SportsNotification current = notificationMapper.selectById(notificationId);
                if (current != null && current.getReadAt() == null) {
                    current.setReadAt(OffsetDateTime.now(SHANGHAI));
                    notificationMapper.updateById(current);
                }
                return null;
            });
        }
        SportsNotification saved = TenantHelper.ignore(() -> notificationMapper.selectById(notificationId));
        return toCard(saved);
    }

    private void writeOne(SportsEvent event, Long accountId) {
        String dedupeKey = "event-cancel:" + event.getId();
        SportsNotification existing = notificationMapper.selectOne(Wrappers.<SportsNotification>lambdaQuery()
            .eq(SportsNotification::getRecipientAccountId, accountId)
            .eq(SportsNotification::getDedupeKey, dedupeKey));
        if (existing != null) {
            return;
        }
        SportsNotification notice = new SportsNotification();
        notice.setRecipientAccountId(accountId);
        notice.setBusinessType("event");
        notice.setBusinessId(event.getId());
        notice.setBusinessRevision(event.getPublishedRevision() == null ? 0 : event.getPublishedRevision());
        notice.setPurpose("event-cancel");
        notice.setContent(content(event));
        notice.setDedupeKey(dedupeKey);
        notice.setVersion(0);
        try {
            notificationMapper.insert(notice);
        } catch (DuplicateKeyException exception) {
            return;
        }
        insertDelivery(notice.getId(), "inbox", "delivered", OffsetDateTime.now(SHANGHAI), null);
        insertDelivery(notice.getId(), "sms", "failed", null, SMS_NOT_CONNECTED);
    }

    private void insertDelivery(Long notificationId, String channel, String status, OffsetDateTime deliveredAt, String failureReason) {
        SportsNotificationDelivery delivery = new SportsNotificationDelivery();
        delivery.setNotificationId(notificationId);
        delivery.setChannel(channel);
        delivery.setAttempt(1);
        delivery.setStatus(status);
        delivery.setDeliveredAt(deliveredAt);
        delivery.setFailureReason(failureReason);
        delivery.setVersion(0);
        deliveryMapper.insert(delivery);
    }

    private String content(SportsEvent event) {
        Map<String, String> body = new LinkedHashMap<>();
        String name = event.getName() == null || event.getName().isBlank() ? "赛事" : event.getName();
        body.put("title", name + "已取消");
        String reason = event.getCancelReason() == null || event.getCancelReason().isBlank() ? "组织方已取消这场赛事" : event.getCancelReason();
        body.put("body", reason);
        try {
            return objectMapper.writeValueAsString(body);
        } catch (JsonProcessingException exception) {
            throw new ServiceException("取消通知无法保存");
        }
    }

    private NoticeCard toCard(SportsNotification notice) {
        String title = "通知";
        String body = "";
        String targetPath = null;
        try {
            var node = objectMapper.readTree(notice.getContent() == null ? "{}" : notice.getContent());
            title = node.path("title").asText(title);
            body = node.path("body").asText("");
            targetPath = node.path("targetPath").asText(null);
            // 历史消息使用过 target 字段；只恢复与业务对象精确一致的已知站内入口。
            // 不改写历史内容，也不把任意来源 URL 当作可跳转地址。
            if (targetPath == null) {
                String legacy = node.path("target").asText(null);
                if ("complaint".equals(notice.getBusinessType())
                    && ("/portal/issues/" + notice.getBusinessId()).equals(legacy)) targetPath = legacy;
                if ("organization".equals(notice.getBusinessType())
                    && "qualification".equals(notice.getPurpose())
                    && "/portal/organization".equals(legacy)) targetPath = legacy;
            }
        } catch (JsonProcessingException exception) {
            body = "";
        }
        return new NoticeCard(notice.getId(), notice.getPurpose(), title, body, notice.getBusinessType(),
            notice.getBusinessId(), notice.getReadAt() != null, targetPath);
    }

    public record NoticeCard(Long id, String purpose, String title, String body, String businessType, Long businessId, boolean read, String targetPath) {
    }

    public record DeliveryCard(Long id, Long notificationId, Long recipientAccountId, String channel, Integer attempt,
                               String status, String failureReason) {
    }
}
