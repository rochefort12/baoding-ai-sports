package org.dromara.sports.registration.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.api.EventRegistrationApi.ManagedEventOption;
import org.dromara.sports.registration.service.RegistrationService;
import org.dromara.sports.registration.service.RegistrationService.EntryCard;
import org.dromara.sports.registration.service.RegistrationService.UnitCard;
import org.dromara.sports.registration.service.RegistrationService.UnitDraft;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 组织内的竞赛单元和整单审核。收费足额实收才可通过。
 */
@Validated
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/b/registrations")
public class RegistrationOrganizerController {

    private final RegistrationService registrationService;

    @GetMapping("/events")
    public R<List<ManagedEventOption>> events() {
        return R.ok(registrationService.listManagedEvents());
    }

    @GetMapping("/units")
    public R<List<UnitCard>> units(@RequestParam @NotNull Long eventId) {
        return R.ok(registrationService.listManagedUnits(eventId));
    }

    @PostMapping("/units")
    public R<UnitCard> createUnit(@RequestBody UnitDraft draft) {
        return R.ok(registrationService.createUnit(draft));
    }

    @PostMapping("/units/{unitId}/edit")
    public R<UnitCard> editUnit(@PathVariable Long unitId, @RequestBody UnitEditRequest request) {
        return R.ok(registrationService.updateUnit(unitId, request.name(), request.entryType(), request.minMembers(), request.maxMembers(), false));
    }
    @PostMapping("/units/{unitId}/remove")
    public R<UnitCard> removeUnit(@PathVariable Long unitId) {
        return R.ok(registrationService.updateUnit(unitId, null, null, null, null, true));
    }
    public record UnitEditRequest(String name, String entryType, Integer minMembers, Integer maxMembers) { }

    @PostMapping("/units/{unitId}/limit")
    public R<UnitCard> adjustLimit(@PathVariable Long unitId, @Validated @RequestBody LimitRequest request) {
        return R.ok(registrationService.adjustLimit(unitId, request.limitCount()));
    }

    @GetMapping("/units/{unitId}/entries")
    public R<List<EntryCard>> entries(@PathVariable Long unitId) {
        return R.ok(registrationService.listUnitEntries(unitId));
    }

    @PostMapping("/{registrationId}/approve")
    public R<EntryCard> approve(@PathVariable Long registrationId) {
        return R.ok(registrationService.approve(registrationId));
    }

    @GetMapping("/{registrationId}/submitted-roster")
    public R<List<RegistrationService.SubmittedMember>> submittedRoster(@PathVariable Long registrationId) {
        return R.ok(registrationService.submittedRoster(registrationId));
    }

    @PostMapping("/{registrationId}/reject")
    public R<EntryCard> reject(@PathVariable Long registrationId, @Validated @RequestBody RejectRequest request) {
        return R.ok(registrationService.reject(registrationId, request.reason()));
    }

    public record RejectRequest(@NotBlank(message = "请填写拒绝原因") String reason) {
    }

    public record LimitRequest(@NotNull @Min(1) Integer limitCount) {
    }
}
