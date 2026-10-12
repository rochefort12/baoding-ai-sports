package org.dromara.sports.organization.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.organization.service.OrganizationApplicationService;
import org.dromara.sports.organization.service.OrganizationApplicationService.ApplicationView;
import org.dromara.sports.organization.service.OrganizationApplicationService.Draft;
import org.dromara.sports.organization.service.OrganizationApplicationService.FileItem;
import org.dromara.sports.organization.service.OrganizationApplicationService.StoredFile;
import org.springframework.http.MediaType;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

/**
 * 平台账号的办赛申请。不在这里审核。
 */
@Validated
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/c/organization")
public class OrganizationApplicationController {

    private final OrganizationApplicationService applicationService;

    @GetMapping("/application")
    public R<ApplicationView> current() {
        return R.ok(applicationService.current());
    }

    @PutMapping("/application")
    public R<ApplicationView> save(@RequestBody Draft draft) {
        return R.ok(applicationService.save(draft));
    }

    @PostMapping("/application/submit")
    public R<ApplicationView> submit(@RequestBody Draft draft) {
        return R.ok(applicationService.submit(draft));
    }

    @PostMapping(value = "/files", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public R<FileItem> upload(@RequestPart("file") MultipartFile file) {
        return R.ok(applicationService.upload(file));
    }

    @GetMapping("/files/{fileId}")
    public void download(@PathVariable Long fileId, HttpServletResponse response) throws IOException {
        write(applicationService.openOwn(fileId), response);
    }

    static void write(StoredFile file, HttpServletResponse response) throws IOException {
        String encoded = URLEncoder.encode(file.fileName(), StandardCharsets.UTF_8).replace("+", "%20");
        response.setContentType(MediaType.APPLICATION_OCTET_STREAM_VALUE);
        response.setHeader("Content-Disposition", "attachment; filename*=UTF-8''" + encoded);
        response.getOutputStream().write(file.body());
    }
}
