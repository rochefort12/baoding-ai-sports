package org.dromara.sports.registration.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.registration.service.FieldCatalogService;
import org.dromara.sports.registration.service.FieldCatalogService.EventFieldCard;
import org.dromara.sports.registration.service.FieldCatalogService.EventFieldDraft;
import org.dromara.sports.registration.service.FieldCatalogService.OrgFieldCard;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 组织字段目录和赛事选用。首笔正式提交后不能再改选用。
 */
@Validated
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/b/fields")
public class FieldOrganizerController {

    private final FieldCatalogService fieldCatalogService;

    @GetMapping
    public R<List<OrgFieldCard>> list() {
        return R.ok(fieldCatalogService.listOrgFields());
    }

    @PostMapping
    public R<OrgFieldCard> create(@Validated @RequestBody OrgFieldRequest request) {
        return R.ok(fieldCatalogService.createOrgField(request.code(), request.label(), request.valueType(), request.options()));
    }

    @PutMapping("/{fieldId}")
    public R<OrgFieldCard> revise(@PathVariable Long fieldId, @Validated @RequestBody OrgFieldRequest request) {
        return R.ok(fieldCatalogService.reviseOrgField(fieldId, request.label(), request.valueType(), request.options()));
    }

    @PostMapping("/{fieldId}/stop")
    public R<OrgFieldCard> stop(@PathVariable Long fieldId) {
        return R.ok(fieldCatalogService.stopOrgField(fieldId));
    }

    @GetMapping("/events/{eventId}")
    public R<List<EventFieldCard>> eventFields(@PathVariable Long eventId) {
        return R.ok(fieldCatalogService.listEventFields(eventId));
    }

    @PutMapping("/events/{eventId}")
    public R<List<EventFieldCard>> replace(@PathVariable Long eventId, @RequestBody List<EventFieldDraft> drafts) {
        return R.ok(fieldCatalogService.replaceEventFields(eventId, drafts));
    }

    public record OrgFieldRequest(@NotBlank String code, @NotBlank String label, @NotBlank String valueType, List<String> options) {
    }
}
