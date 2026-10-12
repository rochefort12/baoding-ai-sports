package org.dromara.sports.finance.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.finance.service.FinanceService;
import org.dromara.sports.finance.service.FinanceService.EventChoice;
import org.dromara.sports.finance.service.FinanceService.ObligationCard;
import org.dromara.sports.finance.service.FinanceService.UnitPrice;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.util.List;

/**
 * 承办方收费记账。确认到账不审核报名。
 */
@Validated
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/b/fees")
public class FeeOrganizerController {

    private final FinanceService financeService;

    /** Permission checked against this registration's actual event; includes closed original duties. */
    @GetMapping("/registrations/{registrationId}/history")
    public R<List<FinanceService.ObligationHistory>> history(@PathVariable Long registrationId) {
        return R.ok(financeService.history(registrationId));
    }

    /** 指定义务的真实收款/分配/退款事实；只向本组织 payment 授权返回。 */
    @GetMapping("/obligations/{obligationId}/records")
    public R<FinanceService.FundRecords> records(@PathVariable Long obligationId) {
        return R.ok(financeService.records(obligationId));
    }

    /** 只关闭人工核实后的重复请求异常，原到账、退款和资格不变。 */
    @PostMapping("/obligations/{obligationId}/exceptions/{exceptionId}/resolve")
    public R<FinanceService.PaymentExceptionRecord> resolveDuplicateException(@PathVariable Long obligationId, @PathVariable Long exceptionId,
                                                                             @Validated @RequestBody ResolveExceptionRequest request) {
        return R.ok(financeService.resolveDuplicateException(obligationId, exceptionId, request.expectedVersion(), request.note(), request.requestKey()));
    }

    @GetMapping("/events")
    public R<List<EventChoice>> events() {
        return R.ok(financeService.events());
    }

    @GetMapping("/events/{eventId}/payment-config")
    public R<org.dromara.sports.api.FeeApi.PaymentSettings> paymentConfig(@PathVariable Long eventId) {
        return R.ok(financeService.eventPaymentConfig(eventId));
    }

    @GetMapping("/events/{eventId}/payment-config/{channelType}/qr")
    public void paymentConfigQr(@PathVariable Long eventId, @PathVariable String channelType, jakarta.servlet.http.HttpServletResponse response) throws java.io.IOException {
        org.dromara.sports.api.StoredObjectApi.ImageBody image = financeService.eventPaymentQr(eventId, channelType);
        response.setContentType(image.contentType()); response.getOutputStream().write(image.body());
    }

    @org.springframework.web.bind.annotation.PutMapping("/events/{eventId}/payment-config")
    public R<org.dromara.sports.api.FeeApi.PaymentSettings> savePaymentConfig(@PathVariable Long eventId, @RequestBody org.dromara.sports.api.FeeApi.PaymentSettings request) {
        return R.ok(financeService.saveEventPaymentConfig(eventId, request));
    }

    @GetMapping("/units")
    public R<List<UnitPrice>> units(@RequestParam @NotNull Long eventId) {
        return R.ok(financeService.units(eventId));
    }

    @PostMapping("/units/{unitId}")
    public R<UnitPrice> publish(@PathVariable Long unitId, @Validated @RequestBody PublishRequest request) {
        return R.ok(financeService.publish(unitId, request.amount(), request.paymentMode(), request.payInstruction(), request.qrFileId()));
    }

    @GetMapping("/units/{unitId}/obligations")
    public R<List<ObligationCard>> obligations(@PathVariable Long unitId) {
        return R.ok(financeService.obligations(unitId));
    }

    @PostMapping("/obligations/{obligationId}/confirm")
    public R<ObligationCard> confirm(@PathVariable Long obligationId, @Validated @RequestBody ConfirmRequest request) {
        return R.ok(financeService.confirmManual(obligationId, request.payerName(), request.amount(), request.occurredAt(),
            request.note(), request.payerAccountId(), request.requestKey()));
    }

    @PostMapping("/obligations/{obligationId}/callback")
    public R<ObligationCard> callback(@PathVariable Long obligationId, @Validated @RequestBody CallbackRequest request) {
        return R.ok(financeService.confirmCallback(obligationId, request.externalRef(), request.amount(), request.payerName()));
    }

    @PostMapping("/obligations/{obligationId}/reverse")
    public R<ObligationCard> reverse(@PathVariable Long obligationId, @Validated @RequestBody KeyRequest request) {
        return R.ok(financeService.reverse(obligationId, request.paymentId(), request.requestKey()));
    }

    @PostMapping("/actions/{actionId}/no-refund")
    public R<ObligationCard> noRefund(@PathVariable Long actionId, @RequestBody(required = false) NoteRequest request) {
        return R.ok(financeService.closeWithoutRefund(actionId, request == null ? null : request.note()));
    }

    @PostMapping("/actions/{actionId}/refund")
    public R<ObligationCard> refund(@PathVariable Long actionId, @Validated @RequestBody RefundRequest request) {
        return R.ok(financeService.recordRefund(actionId, request.note(), request.requestKey(), request.amount(), request.occurredAt(), request.recipientName(), request.recipientBasis()));
    }

    @GetMapping("/units/{unitId}/payment-qr")
    public void paymentQr(@PathVariable Long unitId, jakarta.servlet.http.HttpServletResponse response) throws java.io.IOException {
        org.dromara.sports.api.StoredObjectApi.ImageBody image = financeService.paymentQr(unitId);
        response.setContentType(image.contentType());
        response.getOutputStream().write(image.body());
    }

    public record PublishRequest(@NotNull BigDecimal amount, @NotBlank String paymentMode, String payInstruction, Long qrFileId) {
    }

    public record ResolveExceptionRequest(@NotNull @jakarta.validation.constraints.Min(0) Integer expectedVersion,
                                          @NotBlank @jakarta.validation.constraints.Size(max=1000) String note,
                                          @NotBlank @jakarta.validation.constraints.Pattern(regexp="[a-zA-Z0-9:_.-]{1,128}") String requestKey) { }

    public record ConfirmRequest(@NotBlank String payerName, @NotNull BigDecimal amount, @NotBlank String occurredAt, String note,
                                 Long payerAccountId, @NotBlank String requestKey) {
    }

    public record CallbackRequest(@NotBlank String externalRef, @NotNull BigDecimal amount, String payerName) {
    }

    public record KeyRequest(@NotBlank String requestKey, Long paymentId) {
    }

    public record NoteRequest(String note) {
    }

    public record RefundRequest(@NotBlank String note, @NotBlank String requestKey, @NotNull BigDecimal amount, @NotBlank String occurredAt, @NotBlank String recipientName, String recipientBasis) {
    }
}
