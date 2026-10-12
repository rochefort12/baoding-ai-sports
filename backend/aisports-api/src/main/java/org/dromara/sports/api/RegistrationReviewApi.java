package org.dromara.sports.api;

/**
 * 无需审核的收费报名，在真实到账之后由收费模块回调。
 * 条件不满足时保留到账，不改资格。
 */
public interface RegistrationReviewApi {

    void tryAutoApproveAfterPayment(String tenantId, Long registrationId);
}
