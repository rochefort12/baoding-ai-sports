package org.dromara.web.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.common.ratelimiter.annotation.RateLimiter;
import org.dromara.common.ratelimiter.enums.LimitType;
import org.dromara.web.controller.ParticipantRegisterController.SmsTicket;
import org.dromara.web.service.ParticipantRegisterService;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 已登录参赛者注销。验证码只发给当前账号已绑定的手机号。
 */
@Validated
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/auth/participant")
public class ParticipantAccountController {

    private final ParticipantRegisterService registerService;

    @RateLimiter(time = 60, count = 10, limitType = LimitType.IP)
    @PostMapping("/close-sms-code")
    public R<SmsTicket> sendCloseCode(@RequestBody CloseCodeRequest request) {
        CloseCodeRequest body = request == null ? new CloseCodeRequest(null, null, null) : request;
        String debugCode = registerService.sendCloseCode(body.code(), body.uuid(), body.captchaVerifyParam());
        return R.ok("验证码已发送", new SmsTicket(debugCode));
    }

    @RateLimiter(time = 60, count = 10, limitType = LimitType.IP)
    @PostMapping("/close")
    public R<Void> close(@Valid @RequestBody CloseRequest request) {
        registerService.closeAccount(request.smsCode());
        return R.ok("账号已注销，请重新登录");
    }

    public record CloseCodeRequest(String code, String uuid, String captchaVerifyParam) {
    }

    public record CloseRequest(@NotBlank String smsCode) {
    }
}
