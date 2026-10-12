package org.dromara.sports.event.controller;

import cn.dev33.satoken.annotation.SaIgnore;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.api.StoredObjectApi;
import org.dromara.sports.event.service.EventPublicationService;
import org.dromara.sports.event.service.EventPublicationService.EventCard;
import org.dromara.sports.event.service.EventPublicationService.PublicFeeView;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;

/**
 * 未登录也可访问。服务内部显式跨租户，并只返回已发布且组织仍准入的赛事。
 */
@SaIgnore
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/public/events")
public class PublicEventController {

    private final EventPublicationService eventService;

    @GetMapping
    public R<List<EventCard>> list() {
        return R.ok(eventService.listPublic());
    }

    @GetMapping("/{eventId}")
    public R<EventCard> detail(@PathVariable Long eventId) {
        return R.ok(eventService.findPublic(eventId));
    }

    @GetMapping("/{eventId}/fees")
    public R<PublicFeeView> fees(@PathVariable Long eventId) {
        return R.ok(eventService.publicFees(eventId));
    }

    @GetMapping("/{eventId}/media/{slot}")
    public void media(@PathVariable Long eventId, @PathVariable String slot, HttpServletResponse response) throws IOException {
        StoredObjectApi.ImageBody image = eventService.publicMedia(eventId, slot);
        if (image == null) {
            response.sendError(HttpServletResponse.SC_NOT_FOUND);
            return;
        }
        response.setContentType(image.contentType());
        response.getOutputStream().write(image.body());
    }
}
