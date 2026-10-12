package org.dromara.sports.event.controller;
import cn.dev33.satoken.annotation.SaCheckLogin;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.event.service.EventMaterialService;
import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.web.bind.annotation.*;
/** Organization-guarded private drafts; writing goes through registered actions. */
@SaCheckLogin @RestController @RequiredArgsConstructor
@RequestMapping("/sports/b/events/{eventId}/materials")
public class EventMaterialController {
    private final EventMaterialService materials;
    @GetMapping public R<JsonNode> current(@PathVariable Long eventId) { return R.ok(materials.current(eventId)); }
}
