package org.dromara.sports.registration.service;

import org.dromara.sports.api.RegistrationReviewApi;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Service;

/**
 * 收费模块在到账提交之后回调。用延迟注入避开报名服务和收费服务的构造循环。
 */
@Service
public class RegistrationReviewApiImpl implements RegistrationReviewApi {

    private final RegistrationService registrationService;

    public RegistrationReviewApiImpl(@Lazy RegistrationService registrationService) {
        this.registrationService = registrationService;
    }

    @Override
    public void tryAutoApproveAfterPayment(String tenantId, Long registrationId) {
        registrationService.tryAutoApproveAfterPayment(tenantId, registrationId);
    }
}
