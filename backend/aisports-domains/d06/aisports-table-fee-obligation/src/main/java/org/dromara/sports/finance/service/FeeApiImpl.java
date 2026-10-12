package org.dromara.sports.finance.service;

import lombok.RequiredArgsConstructor;
import org.dromara.sports.api.FeeApi;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.Optional;

/**
 * 报名模块只通过这份契约产生和处理义务。
 */
@Service
@RequiredArgsConstructor
public class FeeApiImpl implements FeeApi {

    private final FinanceService financeService;

    @Override
    public ObligationView openOnSubmit(String tenantId, Long registrationId, Long unitId) {
        return financeService.openOnSubmit(tenantId, registrationId, unitId);
    }

    @Override
    public ObligationView openOnSubmit(String tenantId, Long registrationId, Long unitId, Integer rosterRevision) {
        return financeService.openOnSubmit(tenantId, registrationId, unitId, rosterRevision);
    }

    @Override
    public void onEntryClosed(String tenantId, Long registrationId) {
        financeService.onEntryClosed(tenantId, registrationId);
    }

    @Override
    public void declarePaid(String tenantId, Long registrationId) {
        financeService.declarePaid(tenantId, registrationId);
    }

    @Override
    public Optional<ObligationView> current(String tenantId, Long registrationId) {
        return financeService.current(tenantId, registrationId);
    }

    @Override
    public void requireParticipationReady(String tenantId, Long registrationId) {
        financeService.requireParticipationReady(tenantId, registrationId);
    }

    @Override
    public void placeInitialPolicy(String tenantId, Long unitId, BigDecimal amount, String paymentMode, String instruction, Long qrFileId) {
        financeService.placeInitialPolicy(tenantId, unitId, amount, paymentMode, instruction, qrFileId);
    }

    @Override
    public void reviseUnusedDraftPolicy(String tenantId, Long eventId, Long unitId, BigDecimal amount) {
        financeService.reviseUnusedDraftPolicy(tenantId, eventId, unitId, amount);
    }

    @Override
    public void discardUnusedDraftPricing(String tenantId, Long eventId) {
        financeService.discardUnusedDraftPricing(tenantId, eventId);
    }

    @Override
    public Optional<Long> activeQrFileId(String tenantId, Long unitId) {
        return financeService.activeQrFileId(tenantId, unitId);
    }

    @Override
    public boolean eventPaymentReady(String tenantId, Long eventId) {
        return financeService.eventPaymentReady(tenantId, eventId);
    }

    @Override
    public int eventPaymentRevision(String tenantId,Long eventId){return financeService.eventPaymentRevision(tenantId,eventId);}

    @Override
    public PaymentSettings paymentInstructions(String tenantId, Long registrationId) {
        return financeService.paymentInstructions(tenantId, registrationId);
    }

    @Override
    public java.util.List<PublicUnitPrice> publicUnitPrices(String tenantId, Long eventId) {
        return financeService.publicUnitPrices(tenantId, eventId);
    }

    @Override
    public boolean unsettled(String tenantId, Long registrationId) {
        return financeService.unsettled(tenantId, registrationId);
    }

    @Override
    public void settleCancellation(String tenantId, Long eventId) {
        financeService.settleCancellation(tenantId, eventId);
    }
}
