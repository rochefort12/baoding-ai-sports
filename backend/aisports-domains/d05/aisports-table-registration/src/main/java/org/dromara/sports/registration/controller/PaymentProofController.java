package org.dromara.sports.registration.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.registration.service.PaymentProofService;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import java.io.IOException;
import java.util.List;

/** 凭证为私有金融材料，服务按报名归属、队长身份和本组织 payment 权限授权。 */
@SaCheckLogin
@RestController
@RequiredArgsConstructor
public class PaymentProofController {
    private final PaymentProofService service;

    @PostMapping(value = "/sports/c/registrations/{registrationId}/payment-proofs", consumes = "multipart/form-data")
    public R<PaymentProofService.ProofCard> upload(@PathVariable Long registrationId, @RequestParam String requestKey,
                                                  @RequestPart("file") MultipartFile file) throws IOException {
        if (file.getSize() > 5 * 1024 * 1024) throw new org.dromara.common.core.exception.ServiceException("付款凭证不超过 5MB");
        return R.ok(service.upload(registrationId, requestKey, file.getBytes()));
    }

    @GetMapping("/sports/c/registrations/{registrationId}/payment-proofs")
    public R<List<PaymentProofService.ProofCard>> participantList(@PathVariable Long registrationId) { return R.ok(service.list(registrationId, false)); }

    @GetMapping("/sports/b/registrations/{registrationId}/payment-proofs")
    public R<List<PaymentProofService.ProofCard>> organizerList(@PathVariable Long registrationId) { return R.ok(service.list(registrationId, true)); }

    @GetMapping("/sports/c/registrations/{registrationId}/payment-proofs/{proofId}/image")
    public void participantImage(@PathVariable Long registrationId, @PathVariable Long proofId, HttpServletResponse response) throws IOException {
        write(registrationId, proofId, false, response);
    }

    @GetMapping("/sports/b/registrations/{registrationId}/payment-proofs/{proofId}/image")
    public void organizerImage(@PathVariable Long registrationId, @PathVariable Long proofId, HttpServletResponse response) throws IOException {
        write(registrationId, proofId, true, response);
    }

    private void write(Long registrationId, Long proofId, boolean organizer, HttpServletResponse response) throws IOException {
        var image = service.image(registrationId, proofId, organizer);
        response.setContentType(image.contentType());
        response.setHeader("Cache-Control", "no-store");
        response.setHeader("X-Content-Type-Options", "nosniff");
        response.getOutputStream().write(image.body());
    }
}
