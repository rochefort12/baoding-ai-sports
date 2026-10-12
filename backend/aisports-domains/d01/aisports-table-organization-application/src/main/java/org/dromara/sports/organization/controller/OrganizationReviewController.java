package org.dromara.sports.organization.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.organization.service.OrganizationApplicationService;
import org.dromara.sports.organization.service.OrganizationApplicationService.ApplicationView;
import org.dromara.sports.organization.service.OrganizationApplicationService.PendingItem;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.io.IOException;
import java.util.List;

/**
 * 超级管理员审核办赛申请。服务里会再次核对身份，只藏按钮不够。
 */
@Validated
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/organization-review")
public class OrganizationReviewController {

    private final OrganizationApplicationService applicationService;

    @GetMapping("/pending")
    public R<List<PendingItem>> pending() {
        return R.ok(applicationService.pending());
    }

    @GetMapping("/{applicationId}")
    public R<ApplicationView> detail(@PathVariable Long applicationId) {
        return R.ok(applicationService.review(applicationId));
    }

    @PostMapping("/{applicationId}/approve")
    public R<Void> approve(@PathVariable Long applicationId) {
        applicationService.approve(applicationId);
        return R.ok();
    }

    @PostMapping("/{applicationId}/reject")
    public R<Void> reject(@PathVariable Long applicationId, @Validated @RequestBody RejectRequest request) {
        applicationService.reject(applicationId, request.reason());
        return R.ok();
    }

    @GetMapping("/{applicationId}/files/{fileId}")
    public void download(@PathVariable Long applicationId, @PathVariable Long fileId, HttpServletResponse response) throws IOException {
        OrganizationApplicationController.write(applicationService.openForReview(applicationId, fileId), response);
    }

    public record RejectRequest(@NotBlank(message = "请填写拒绝理由") String reason) {
    }
}
