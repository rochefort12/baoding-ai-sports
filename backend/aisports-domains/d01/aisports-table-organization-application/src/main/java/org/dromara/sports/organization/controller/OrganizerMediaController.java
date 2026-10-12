package org.dromara.sports.organization.controller;

import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.api.OrganizationSessionApi.ManagedOrganization;
import org.dromara.sports.api.StoredObjectApi;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Map;

/**
 * 承办方上传宣传图、说明图片和收款码。访问仍走各自的业务接口，这里只负责存。
 */
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/b/media")
public class OrganizerMediaController {

    private final OrganizationSessionApi sessionApi;
    private final StoredObjectApi storedObjectApi;

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public R<Map<String, String>> upload(@RequestParam String purpose, @RequestPart("file") MultipartFile file) throws IOException {
        ManagedOrganization organization = organizer();
        if (file == null || file.isEmpty()) {
            throw new ServiceException("请选择图片");
        }
        long fileId = storedObjectApi.keepImage(organization.accountId(), organization.tenantId(), purpose, file.getBytes());
        return R.ok(Map.of("fileId", Long.toString(fileId)));
    }

    @GetMapping("/{fileId}")
    public void preview(@PathVariable long fileId, HttpServletResponse response) throws IOException {
        ManagedOrganization organization = organizer();
        write(storedObjectApi.readOwned(fileId, organization.tenantId()), response);
    }

    static void write(StoredObjectApi.ImageBody image, HttpServletResponse response) throws IOException {
        response.setContentType(image.contentType());
        response.getOutputStream().write(image.body());
    }

    private ManagedOrganization organizer() {
        if (!LoginHelper.isLogin()) {
            throw new ServiceException("请先进入组织");
        }
        ManagedOrganization organization = sessionApi.managedOrganization(LoginHelper.getUserId())
            .orElseThrow(() -> new ServiceException("当前账号不能管理这个组织"));
        if (!organization.tenantId().equals(LoginHelper.getTenantId())) {
            throw new ServiceException("请先进入该组织");
        }
        return organization;
    }
}
