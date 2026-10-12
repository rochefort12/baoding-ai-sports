package org.dromara.sports.identity.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.common.encrypt.annotation.ApiEncrypt;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.sports.identity.ParticipantEntry;
import org.dromara.sports.identity.domain.SportsAccount;
import org.dromara.sports.identity.domain.SportsPerson;
import org.dromara.sports.identity.service.IdentityService;
import org.dromara.sports.identity.service.IdentityService.PersonDraft;
import org.dromara.sports.identity.service.IdentityService.PersonCard;
import org.dromara.sports.identity.service.IdentityService.IdentityHome;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;

/**
 * 参赛者身份入口。登录用户只操作自己的平台账号，不能指定别人的账号编号来建档。
 */
@Validated
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/c/identity")
public class IdentityController {

    private final IdentityService identityService;

    @GetMapping
    public R<IdentityHome> home() {
        requireParticipant();
        SportsAccount account = currentAccount();
        return R.ok(identityService.home(account.getId()));
    }

    @ApiEncrypt
    @PutMapping("/password")
    public R<Void> changePassword(@Valid @RequestBody PasswordRequest request) {
        if (LoginHelper.getUserType() != UserType.PLATFORM_USER) {
            throw new ServiceException("请使用平台账号修改登录密码");
        }
        identityService.changeLoginPassword(LoginHelper.getUserId(), request.oldPassword(), request.newPassword());
        return R.ok();
    }

    @PostMapping("/self")
    public R<PersonCard> bindSelf(@Valid @RequestBody PersonRequest request) {
        requireParticipant();
        SportsAccount account = currentAccount();
        SportsPerson person = identityService.bindSelf(account.getId(), request.toDraft());
        return R.ok(identityService.profileCard(person, true));
    }

    private void requireParticipant() {
        if (LoginHelper.getUserType() == UserType.PLATFORM_USER) {
            return;
        }
        if (!ParticipantEntry.TENANT_ID.equals(LoginHelper.getTenantId())) {
            throw new ServiceException("请使用参赛者账号登录后再填写身份档案");
        }
    }

    private SportsAccount currentAccount() {
        if (LoginHelper.getUserType() == UserType.PLATFORM_USER) {
            return identityService.requireAccount(LoginHelper.getUserId());
        }
        String name = LoginHelper.getUsername();
        if (name == null || name.isBlank()) {
            name = "参赛用户";
        }
        return identityService.ensureAccount(LoginHelper.getUserId(), name);
    }

    @PostMapping("/feedback")
    public R<Void> feedback(@Validated @RequestBody FeedbackRequest request) {
        requireParticipant();
        identityService.submitFeedback(currentAccount().getId(), request.topic(), request.detail());
        return R.ok();
    }

    public record FeedbackRequest(@NotBlank String topic, @NotBlank String detail) {
    }

    public record PasswordRequest(@NotBlank String oldPassword, @NotBlank String newPassword) {
    }

    public record PersonRequest(@NotBlank String legalName, @NotNull LocalDate birthDate, @NotBlank String gender,
                                @NotBlank String mobile, String idDocType, String idNumber, String city,
                                String addressDetail, String bloodType, String clothingSize,
                                String emergencyContactName, String emergencyContactPhone) {
        private PersonDraft toDraft() {
            return new PersonDraft(legalName, birthDate, gender, mobile, idDocType, idNumber, city, addressDetail,
                bloodType, clothingSize, emergencyContactName, emergencyContactPhone);
        }
    }

}
