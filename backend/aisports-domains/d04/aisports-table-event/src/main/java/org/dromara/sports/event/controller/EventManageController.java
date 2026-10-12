package org.dromara.sports.event.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.event.service.EventCancellationNoticeService;
import org.dromara.sports.event.service.EventCancellationNoticeService.DeliveryCard;
import org.dromara.sports.event.service.EventPublicationService;
import org.dromara.sports.event.service.EventPublicationService.EventCard;
import org.dromara.sports.event.service.EventPublicationService.EventDraft;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 组织管理会话里的赛事。公开列表不在这里。
 */
@Validated
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/b/events")
public class EventManageController {

    private final EventPublicationService eventService;
    private final EventCancellationNoticeService noticeService;

    @GetMapping("/{eventId}/preview-fees")
    public R<org.dromara.sports.event.service.EventPublicationService.PublicFeeView> previewFees(@PathVariable Long eventId) { return R.ok(eventService.previewFees(eventId)); }

    @GetMapping
    public R<List<EventCard>> list() {
        return R.ok(eventService.listManaged());
    }

    @GetMapping("/{eventId}")
    public R<EventCard> detail(@PathVariable Long eventId) {
        return R.ok(eventService.managed(eventId));
    }

    @PostMapping
    public R<EventCard> create(@RequestBody EventDraft draft) {
        return R.ok(eventService.create(draft));
    }

    @PutMapping("/{eventId}")
    public R<EventCard> update(@PathVariable Long eventId, @RequestBody EventDraft draft) {
        return R.ok(eventService.update(eventId, draft));
    }

    @PostMapping("/{eventId}/registration-review")
    public R<EventCard> changeReview(@PathVariable Long eventId, @RequestBody ReviewRequest request) {
        return R.ok(eventService.changeReview(eventId, request == null ? null : request.registrationReview()));
    }

    @PostMapping("/{eventId}/publish")
    public R<EventCard> publish(@PathVariable Long eventId, @Validated @RequestBody PublishRequest request) {
        return R.ok(eventService.publish(eventId, request.requestKey(), Boolean.TRUE.equals(request.contactConfirmed()), request.contactName(), request.contactMethod(),request.expectedVersion(),request.expectedPreviewHash()));
    }

    @PostMapping("/{eventId}/offline")
    public R<EventCard> offline(@PathVariable Long eventId) {
        return R.ok(eventService.offline(eventId));
    }

    @GetMapping("/{eventId}/notices")
    public R<List<DeliveryCard>> notices(@PathVariable Long eventId) {
        eventService.managed(eventId);
        return R.ok(noticeService.deliveries(eventId));
    }

    @PostMapping("/notices/{notificationId}/retry-sms")
    public R<DeliveryCard> retrySms(@PathVariable Long notificationId) {
        return R.ok(noticeService.retrySms(notificationId));
    }

    @PostMapping("/{eventId}/delete-draft")
    public R<Void> deleteDraft(@PathVariable Long eventId) {
        eventService.deleteDraft(eventId);
        return R.ok();
    }

    @PostMapping("/{eventId}/cancel")
    public R<EventCard> cancel(@PathVariable Long eventId, @RequestBody CancelRequest request) {
        return R.ok(eventService.cancel(eventId, request == null ? null : request.reason()));
    }

    public record PublishRequest(@NotBlank(message = "请提供发布请求键") String requestKey, Boolean contactConfirmed, String contactName, String contactMethod,Integer expectedVersion,String expectedPreviewHash) {
        public PublishRequest(String requestKey,Boolean contactConfirmed,String contactName,String contactMethod){this(requestKey,contactConfirmed,contactName,contactMethod,null,null);}
    }

    public record ReviewRequest(String registrationReview) {
    }

    public record CancelRequest(String reason) {
    }
}
