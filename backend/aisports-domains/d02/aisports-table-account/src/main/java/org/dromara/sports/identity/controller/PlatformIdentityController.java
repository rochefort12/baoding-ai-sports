package org.dromara.sports.identity.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.sports.identity.service.IdentityService;
import org.dromara.sports.identity.service.ProfileTraceService;
import org.dromara.sports.identity.service.ProfileTraceService.TraceCard;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 平台管理员查看档案修改、反馈，以及把已关闭账号的证件关联到新账号。
 */
@Validated
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/platform/identity")
public class PlatformIdentityController {

    private final IdentityService identityService;
    private final ProfileTraceService profileTraceService;

    @GetMapping("/traces")
    public R<List<TraceCard>> traces() {
        requirePlatformAdmin();
        return R.ok(profileTraceService.recent());
    }

    @PostMapping("/link")
    public R<Void> link(@Validated @RequestBody LinkRequest request) {
        requirePlatformAdmin();
        identityService.linkClosedIdentity(request.accountId(), request.idDocType(), request.idNumber(), request.reason());
        return R.ok();
    }

    private void requirePlatformAdmin() {
        if (!LoginHelper.isSuperAdmin()) {
            throw new ServiceException("只有平台管理员可以办理");
        }
    }

    public record LinkRequest(@NotNull Long accountId, @NotBlank String idDocType, @NotBlank String idNumber, @NotBlank String reason) {
    }
}
