package org.dromara.sports.event.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.event.service.EventOperationsService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** 运营首页的最小只读汇总接口。不接收组织编号，不启用平台全域查询。 */
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/b/operations")
public class EventOperationsController {
    private final EventOperationsService operationsService;
    @GetMapping("/summary")
    public R<EventOperationsService.Snapshot> summary() { return R.ok(operationsService.snapshot()); }
}
