package org.dromara.sports.event.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.event.service.EventCancellationNoticeService;
import org.dromara.sports.event.service.EventCancellationNoticeService.NoticeCard;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 参赛者的站内信。已读只改自己的通知。
 */
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/c/notices")
public class ParticipantNoticeController {

    private final EventCancellationNoticeService noticeService;

    @GetMapping
    public R<List<NoticeCard>> list() {
        return R.ok(noticeService.mine());
    }

    @PostMapping("/{notificationId}/read")
    public R<NoticeCard> read(@PathVariable Long notificationId) {
        return R.ok(noticeService.markRead(notificationId));
    }
}
