package org.dromara.web.controller;

import cn.dev33.satoken.annotation.SaIgnore;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.common.ratelimiter.annotation.RateLimiter;
import org.dromara.common.ratelimiter.enums.LimitType;
import org.dromara.web.config.AliyunCaptchaProperties;
import org.dromara.web.service.ParticipantRegisterService;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 参赛者注册入口。不接收租户编号，固定进入平台参赛者租户。
 */
@SaIgnore
@Validated
@RestController
@RequiredArgsConstructor
@RequestMapping("/auth/participant")
public class ParticipantRegisterController {

    private final ParticipantRegisterService registerService;
    private final AliyunCaptchaProperties aliyunCaptchaProperties;

    @GetMapping("/captcha-config")
    public R<CaptchaConfig> captchaConfig() {
        boolean aliyun = aliyunCaptchaProperties.ready();
        return R.ok(new CaptchaConfig(
            aliyun,
            aliyun ? aliyunCaptchaProperties.getRegion() : "",
            aliyun ? aliyunCaptchaProperties.getPrefix() : "",
            aliyun ? aliyunCaptchaProperties.getSceneId() : "",
            aliyun ? aliyunCaptchaProperties.getMode() : ""
        ));
    }

    @RateLimiter(time = 60, count = 10, limitType = LimitType.IP)
    @PostMapping("/sms-code")
    public R<SmsTicket> sendSmsCode(@Valid @RequestBody SmsRequest request) {
        String debugCode = registerService.sendSmsCode(request.phone(), request.code(), request.uuid(), request.captchaVerifyParam());
        return R.ok(new SmsTicket(debugCode));
    }

    @RateLimiter(time = 60, count = 10, limitType = LimitType.IP)
    @PostMapping("/reset-sms-code")
    public R<SmsTicket> sendResetCode(@Valid @RequestBody SmsRequest request) {
        String debugCode = registerService.sendResetCode(request.phone(), request.code(), request.uuid(), request.captchaVerifyParam());
        return R.ok("如果手机号已注册，验证码已发送", new SmsTicket(debugCode));
    }

    @RateLimiter(time = 60, count = 10, limitType = LimitType.IP)
    @PostMapping("/register")
    public R<Void> register(@Valid @RequestBody RegisterRequest request) {
        registerService.register(request.phone(), request.password(), request.smsCode());
        return R.ok();
    }

    @RateLimiter(time = 60, count = 10, limitType = LimitType.IP)
    @PostMapping("/reset-password")
    public R<Void> resetPassword(@Valid @RequestBody ResetRequest request) {
        registerService.resetPassword(request.phone(), request.smsCode(), request.password());
        return R.ok("密码已重置，请重新登录");
    }

    public record SmsRequest(@NotBlank String phone, String code, String uuid, String captchaVerifyParam) {
    }

    public record CaptchaConfig(boolean aliyun, String region, String prefix, String sceneId, String mode) {
    }

    public record SmsTicket(String debugCode) {
    }

    public record RegisterRequest(@NotBlank String phone, @NotBlank String password, @NotBlank String smsCode) {
    }

    public record ResetRequest(@NotBlank String phone, @NotBlank String smsCode, @NotBlank String password) {
    }
}
