package org.dromara.sports.event.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.event.service.EventPromotionService;
import org.dromara.sports.event.service.PromotionVisualService;
import org.dromara.common.ratelimiter.annotation.RateLimiter;
import org.dromara.sports.event.service.EventPromotionService.PromotionView;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 办赛端宣传材料。不代发到微信或 QQ，也不改公开页。
 */
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/b/events/{eventId}/promotion")
public class EventPromotionController {

    private final EventPromotionService promotionService;
    private final PromotionVisualService visuals;

    @PostMapping("/visual")
    @RateLimiter(key = "#eventId + ':' + T(org.dromara.common.satoken.utils.LoginHelper).getTenantId()", time = 86400, count = 10, message = "这场赛事24小时内的主视觉请求已达上限，请使用已有图片")
    public R<PromotionView> visual(@PathVariable Long eventId, @RequestBody VisualRequest request) {
        if (request == null) throw new org.dromara.common.core.exception.ServiceException("请填写主视觉要求");
        return R.ok(visuals.generate(eventId, request.consent(), request.style(), request.audience(), request.keywords()));
    }
    public record VisualRequest(boolean consent, String style, String audience, String keywords) { }

    @GetMapping
    public R<PromotionView> current(@PathVariable Long eventId) {
        return R.ok(promotionService.current(eventId));
    }

    @PostMapping
    public R<PromotionView> generate(@PathVariable Long eventId, @RequestBody GenerateRequest request) {
        return R.ok(promotionService.generate(eventId, request != null && request.consent(), request == null ? null : request.note()));
    }

    public record GenerateRequest(boolean consent, String note) {
    }
}
