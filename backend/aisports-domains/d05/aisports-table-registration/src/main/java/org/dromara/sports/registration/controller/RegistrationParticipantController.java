package org.dromara.sports.registration.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.registration.service.FieldCatalogService;
import org.dromara.sports.registration.service.FieldCatalogService.EntryFieldCard;
import org.dromara.sports.registration.service.FieldCatalogService.ValueDraft;
import org.dromara.sports.api.StoredObjectApi;
import org.dromara.sports.registration.service.RegistrationService;
import org.dromara.sports.registration.service.RegistrationService.EntryCard;
import org.dromara.sports.registration.service.RegistrationService.InviteView;
import org.dromara.sports.registration.service.RegistrationService.UnitCard;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;

/**
 * 参赛者报名。写入哪个租户由服务按赛事决定，不使用技术租户。
 */
@Validated
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/c/registrations")
public class RegistrationParticipantController {

    private final RegistrationService registrationService;
    private final FieldCatalogService fieldCatalogService;

    @GetMapping("/units")
    public R<List<UnitCard>> units(@RequestParam @NotNull Long eventId) {
        return R.ok(registrationService.listPublicUnits(eventId));
    }

    @GetMapping
    public R<List<EntryCard>> mine(@RequestParam(required = false) Long eventId) {
        return R.ok(registrationService.listMine(eventId));
    }

    @GetMapping("/received")
    public R<List<InviteView>> received() {
        return R.ok(registrationService.listReceived());
    }

    /** 原提交人/代表队当前队长删除从未提交的草稿，历史撤回不能用此接口删除。 */
    @DeleteMapping("/{registrationId}")
    public R<Void> deleteDraft(@PathVariable Long registrationId) {
        registrationService.deleteDraft(registrationId);
        return R.ok();
    }

    @PostMapping
    public R<EntryCard> create(@Validated @RequestBody DraftRequest request) {
        return R.ok(registrationService.createDraft(request.unitId(), request.requestKey(), request.teamId(), request.memberAccountIds()));
    }

    @PostMapping("/{registrationId}/members")
    public R<EntryCard> invite(@PathVariable Long registrationId, @Validated @RequestBody InviteRequest request) {
        return R.ok(registrationService.invite(registrationId, request.phone(), Boolean.TRUE.equals(request.requestSms())));
    }

    @PostMapping("/{registrationId}/roster")
    public R<EntryCard> roster(@PathVariable Long registrationId, @Validated @RequestBody AccountRequest request) {
        return R.ok(registrationService.addTeammate(registrationId, request.accountId()));
    }

    @DeleteMapping("/{registrationId}/members/{memberId}")
    public R<EntryCard> remove(@PathVariable Long registrationId, @PathVariable Long memberId) {
        return R.ok(registrationService.removeMember(registrationId, memberId));
    }

    @PostMapping("/{registrationId}/members/{memberId}/remind")
    public R<EntryCard> remind(@PathVariable Long registrationId, @PathVariable Long memberId) {
        return R.ok(registrationService.remindInvitation(registrationId, memberId));
    }

    @PostMapping("/{registrationId}/declaration-ack")
    public R<EntryCard> acknowledgeDeclaration(@PathVariable Long registrationId) {
        return R.ok(registrationService.acknowledgeDeclaration(registrationId));
    }

    @PostMapping("/{registrationId}/submit")
    public R<EntryCard> submit(@PathVariable Long registrationId, @Validated @RequestBody KeyRequest request) {
        return R.ok(registrationService.submit(registrationId, request.requestKey()));
    }

    @PostMapping("/{registrationId}/withdraw")
    public R<EntryCard> withdraw(@PathVariable Long registrationId) {
        return R.ok(registrationService.withdraw(registrationId));
    }

    @GetMapping("/{registrationId}/fields")
    public R<List<EntryFieldCard>> fields(@PathVariable Long registrationId) {
        return R.ok(fieldCatalogService.listMine(registrationId));
    }

    @GetMapping("/{registrationId}/declaration-image")
    public void declarationImage(@PathVariable Long registrationId, HttpServletResponse response) throws IOException {
        StoredObjectApi.ImageBody image = registrationService.declarationImage(registrationId);
        response.setContentType(image.contentType());
        response.setHeader("Cache-Control", "private, no-store");
        response.getOutputStream().write(image.body());
    }

    @PutMapping("/{registrationId}/fields")
    public R<List<EntryFieldCard>> saveFields(@PathVariable Long registrationId, @RequestBody List<ValueDraft> drafts) {
        return R.ok(fieldCatalogService.saveMine(registrationId, drafts));
    }

    @GetMapping("/{registrationId}/payment-qr")
    public void paymentQr(@PathVariable Long registrationId, HttpServletResponse response) throws IOException {
        StoredObjectApi.ImageBody image = registrationService.paymentQr(registrationId);
        response.setContentType(image.contentType());
        response.getOutputStream().write(image.body());
    }

    @GetMapping("/{registrationId}/payment-instructions")
    public R<org.dromara.sports.api.FeeApi.PaymentSettings> paymentInstructions(@PathVariable Long registrationId) {
        return R.ok(registrationService.paymentInstructions(registrationId));
    }

    @GetMapping("/{registrationId}/payment-channels/{channelType}/qr")
    public void paymentChannelQr(@PathVariable Long registrationId, @PathVariable String channelType, HttpServletResponse response) throws IOException {
        StoredObjectApi.ImageBody image = registrationService.paymentChannelQr(registrationId, channelType);
        response.setContentType(image.contentType()); response.getOutputStream().write(image.body());
    }

    @PostMapping("/{registrationId}/payment-declared")
    public R<EntryCard> declarePaid(@PathVariable Long registrationId) {
        return R.ok(registrationService.declarePaid(registrationId));
    }

    @GetMapping("/invites/{token}")
    public R<InviteView> invite(@PathVariable String token) {
        return R.ok(registrationService.inviteView(token));
    }

    @PostMapping("/invites/{token}/confirm")
    public R<InviteView> confirm(@PathVariable String token) {
        return R.ok(registrationService.confirmInvite(token));
    }

    @PostMapping("/invites/{token}/decline")
    public R<InviteView> decline(@PathVariable String token) {
        return R.ok(registrationService.declineInvite(token));
    }

    public record DraftRequest(@NotNull Long unitId, @NotBlank String requestKey, Long teamId,
                               @jakarta.validation.constraints.Size(max = 100) List<@NotNull Long> memberAccountIds) {
    }

    public record InviteRequest(@NotBlank String phone, Boolean requestSms) {
    }

    public record AccountRequest(@NotNull Long accountId) {
    }

    public record KeyRequest(@NotBlank String requestKey) {
    }
}
