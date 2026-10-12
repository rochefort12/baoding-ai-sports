package org.dromara.sports.organization.controller;

import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.sports.organization.service.UnreferencedFileCleanup;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;

/**
 * 平台管理员手动触发未引用文件清理。每天凌晨也会自动跑同一套规则。
 */
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/platform/files")
public class FileCleanupController {

    private static final ZoneOffset SHANGHAI = ZoneOffset.ofHours(8);

    private final UnreferencedFileCleanup cleanup;

    @PostMapping("/cleanup")
    public R<Integer> cleanup() {
        if (!LoginHelper.isSuperAdmin()) {
            throw new ServiceException("只有平台管理员可以清理未引用文件");
        }
        return R.ok(cleanup.cleanup(OffsetDateTime.now(SHANGHAI).minusDays(7)));
    }
}
