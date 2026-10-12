package org.dromara.sports.event.controller;
import cn.dev33.satoken.annotation.SaCheckLogin;
import lombok.RequiredArgsConstructor;
import com.fasterxml.jackson.databind.JsonNode;
import org.dromara.common.core.domain.R;
import org.dromara.sports.event.service.EventClosureService;
import org.springframework.web.bind.annotation.*;
@RestController @SaCheckLogin @RequestMapping("/sports/closure") @RequiredArgsConstructor
public class EventClosureController {private final EventClosureService closure;@GetMapping("/events/{id}") public R<JsonNode> summary(@PathVariable long id){return R.ok(closure.summary(id));}}
