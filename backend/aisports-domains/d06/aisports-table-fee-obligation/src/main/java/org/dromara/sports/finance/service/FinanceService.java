package org.dromara.sports.finance.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.core.lock.MutualLock;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.FeeApi.ObligationView;
import org.dromara.sports.api.FeeApi.PaymentSettings;
import org.dromara.sports.api.FeeApi.PaymentChannel;
import org.dromara.sports.finance.domain.SportsEventPaymentConfig;
import org.dromara.sports.finance.mapper.SportsEventPaymentConfigMapper;
import org.dromara.sports.api.OrganizationQualificationApi;
import org.dromara.sports.api.StoredObjectApi;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.api.RegistrationReviewApi;
import org.dromara.sports.api.OrganizationSessionApi.ManagedOrganization;
import org.dromara.sports.finance.FeeRules;
import org.dromara.sports.finance.domain.BillingEvent;
import org.dromara.sports.finance.domain.BillingRegistration;
import org.dromara.sports.finance.domain.BillingUnit;
import org.dromara.sports.finance.domain.SportsFeeObligation;
import org.dromara.sports.finance.domain.SportsFeePolicy;
import org.dromara.sports.finance.domain.SportsPayment;
import org.dromara.sports.finance.domain.SportsPaymentAction;
import org.dromara.sports.finance.domain.SportsPaymentAllocation;
import org.dromara.sports.finance.domain.SportsPaymentException;
import org.dromara.sports.finance.domain.SportsRefund;
import org.dromara.sports.finance.mapper.BillingEventMapper;
import org.dromara.sports.finance.mapper.BillingRegistrationMapper;
import org.dromara.sports.finance.mapper.BillingUnitMapper;
import org.dromara.sports.finance.mapper.SportsFeeObligationMapper;
import org.dromara.sports.finance.mapper.SportsFeePolicyMapper;
import org.dromara.sports.finance.mapper.SportsPaymentActionMapper;
import org.dromara.sports.finance.mapper.SportsPaymentAllocationMapper;
import org.dromara.sports.finance.mapper.SportsPaymentExceptionMapper;
import org.dromara.sports.finance.mapper.SportsPaymentMapper;
import org.dromara.sports.finance.mapper.SportsRefundMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.dromara.sports.platform.core.ActionContext;

import java.math.BigDecimal;
import java.util.Optional;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * 收费写在赛事租户。人工审核不在确认到账时通过；无需审核的收费报名到账后尝试自动通过。
 */
@Service
@RequiredArgsConstructor
public class FinanceService {

    static final String PAYMENT_ACTION = "payment";
    private static final String PAYEE = "organizer";
    private static final String CURRENCY = "CNY";
    private static final long WAIT_MILLIS = 3000;
    private static final long LEASE_MILLIS = 30000;
    private static final ZoneOffset SHANGHAI = ZoneOffset.ofHours(8);
    private static final DateTimeFormatter PAID_AT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");
    private static final DateTimeFormatter PAID_AT_INPUT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private final SportsFeePolicyMapper policyMapper;
    private final SportsFeeObligationMapper obligationMapper;
    private final SportsPaymentMapper paymentMapper;
    private final SportsPaymentAllocationMapper allocationMapper;
    private final SportsPaymentExceptionMapper exceptionMapper;
    private final SportsPaymentActionMapper actionMapper;
    private final SportsRefundMapper refundMapper;
    private final BillingRegistrationMapper registrationMapper;
    private final BillingUnitMapper unitMapper;
    private final BillingEventMapper eventMapper;
    private final OrganizationSessionApi sessionApi;
    private final RegistrationReviewApi registrationReviewApi;
    private final OrganizationQualificationApi qualificationApi;
    private final MutualLock mutualLock;
    private final ObjectMapper objectMapper;
    private final PlatformTransactionManager transactionManager;
    private final StoredObjectApi storedObjectApi;
    private final SportsEventPaymentConfigMapper paymentConfigMapper;
    private final org.dromara.sports.platform.core.ScopedJdbc exceptionJdbc;

    /**
     * 草稿删除的资金边界：价格及收款设置只是配置，不代表付款。
     * 保留所有曾被报名或义务使用的版本，禁止借删除赛事抹去收款、退款和异常历史。
     * 只能加入办赛删除事务；持有同一赛事行锁，配置/提交不会在检查后并发穿入。
     */
    @org.springframework.transaction.annotation.Transactional(
        propagation = org.springframework.transaction.annotation.Propagation.MANDATORY, rollbackFor = Exception.class)
    public void discardUnusedDraftPricing(String tenantId, Long eventId) {
        TenantHelper.dynamic(tenantId, () -> {
            BillingEvent event = eventMapper.lock(eventId);
            if (event == null || !tenantId.equals(event.getTenantId())
                || !"draft".equals(event.getPublicationStatus()) || !"normal".equals(event.getHoldingStatus())) {
                throw new ServiceException("只有未发布的办赛草稿可以删除费用设置");
            }
            if (Boolean.TRUE.equals(event.getRegistrationReviewLocked())) {
                throw new ServiceException("已有正式报名历史，不能删除这场办赛草稿");
            }
            List<SportsFeePolicy> unused = new ArrayList<>();
            for (BillingUnit unit : unitMapper.selectList(Wrappers.<BillingUnit>lambdaQuery()
                .eq(BillingUnit::getEventId, eventId))) {
                Long entries = registrationMapper.selectCount(Wrappers.<BillingRegistration>lambdaQuery()
                    .eq(BillingRegistration::getUnitId, unit.getId()));
                if (entries != null && entries > 0) {
                    throw new ServiceException("已有报名历史，不能删除这场办赛草稿");
                }
                for (SportsFeePolicy policy : policyMapper.selectList(Wrappers.<SportsFeePolicy>lambdaQuery()
                    .eq(SportsFeePolicy::getUnitId, unit.getId()))) {
                    Long obligations = obligationMapper.selectCount(Wrappers.<SportsFeeObligation>lambdaQuery()
                        .eq(SportsFeeObligation::getFeePolicyId, policy.getId()));
                    if (obligations != null && obligations > 0) {
                        throw new ServiceException("已有付款义务或资金历史，不能删除这场办赛草稿");
                    }
                    unused.add(policy);
                }
            }
            // 全部验证完成才开始清理，包含停用的旧配置；从不删除付款义务或到账记录。
            for (SportsFeePolicy policy : unused) {
                saved(policyMapper.deleteById(policy.getId()), "费用设置刚被更新，请刷新后再删除草稿");
            }
            paymentConfigMapper.delete(Wrappers.<SportsEventPaymentConfig>lambdaQuery()
                .eq(SportsEventPaymentConfig::getEventId, eventId));
            return null;
        });
    }

    public ObligationView openOnSubmit(String tenantId, Long registrationId, Long unitId) {
        return openOnSubmit(tenantId, registrationId, unitId, null);
    }

    public ObligationView openOnSubmit(String tenantId, Long registrationId, Long unitId, Integer rosterRevision) {
        if (rosterRevision != null && rosterRevision < 1) throw new ServiceException("提交版本无效");
        return TenantHelper.dynamic(tenantId, () -> locked("fee:" + tenantId + ":" + registrationId, () -> {
            BillingUnit unit = unitMapper.selectById(unitId);
            if (unit == null || eventMapper.lock(unit.getEventId()) == null) throw new ServiceException("赛事项目不存在");
            releaseStaleObligation(registrationId);
            if (openObligation(registrationId) != null) {
                throw new ServiceException("这条报名已经有未结束的付款义务");
            }
            SportsFeePolicy policy = activePolicy(unitId);
            if (policy == null) {
                throw new ServiceException("这个项目还没有生效的收费版本");
            }
            String status = FeeRules.obligationStatus(policy.getPaymentMode(), policy.getAmount());
            SportsFeeObligation obligation = new SportsFeeObligation();
            obligation.setRegistrationId(registrationId);
            obligation.setFeePolicyId(policy.getId());
            obligation.setTotalAmount(policy.getAmount());
            obligation.setCurrency(CURRENCY);
            obligation.setStatus(status);
            obligation.setQuoteSnapshot(snapshot(policy, rosterRevision));
            obligation.setRequestKey("billing:" + registrationId + ":" + UUID.randomUUID());
            obligation.setVersion(0);
            obligationMapper.insert(obligation);
            return view(obligation, instruction(obligation));
        }));
    }

    public void onEntryClosed(String tenantId, Long registrationId) {
        TenantHelper.dynamic(tenantId, () -> locked("fee:" + tenantId + ":" + registrationId, () -> {
            SportsFeeObligation obligation = latestLive(registrationId);
            if (obligation == null) {
                return null;
            }
            obligation = lockObligation(obligation.getId());
            closeForInactiveEntry(obligation);
            return null;
        }));
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.finance.financeservice.declarepaid",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public void declarePaid(String tenantId, Long registrationId) {
        TenantHelper.dynamic(tenantId, () -> locked("fee:" + tenantId + ":" + registrationId, () -> {
            SportsFeeObligation obligation = latest(registrationId);
            if (obligation == null || "not_required".equals(obligation.getStatus())) {
                throw new ServiceException("这条报名不需要付款");
            }
            if (!"open".equals(obligation.getStatus())) {
                throw new ServiceException("当前不能标记付款完成");
            }
            if (obligation.getDeclaredAt() == null) {
                obligation.setDeclaredAt(now());
                saved(obligationMapper.updateById(obligation), "这条报名付款已被更新，请再试一次");
            }
            return null;
        }));
    }

    public Optional<ObligationView> current(String tenantId, Long registrationId) {
        if (tenantId == null || registrationId == null) {
            return Optional.empty();
        }
        return TenantHelper.dynamic(tenantId, () -> {
            SportsFeeObligation obligation = latest(registrationId);
            if (obligation == null) {
                return Optional.empty();
            }
            return Optional.of(view(obligation, instruction(obligation)));
        });
    }

    /** Current funds are locked in the caller's transaction; prior qualification is not a receipt guarantee. */
    public void requireParticipationReady(String tenantId, Long registrationId) {
        TenantHelper.dynamic(tenantId, () -> {
            SportsFeeObligation latest = latest(registrationId);
            if (latest == null) throw new ServiceException("请先核对本次报名的付款义务");
            SportsFeeObligation obligation = lockObligation(latest.getId());
            boolean free = "not_required".equals(obligation.getStatus()) && obligation.getTotalAmount().signum() == 0;
            boolean paid = "settled".equals(obligation.getStatus())
                && netAmount(obligation.getId()).compareTo(obligation.getTotalAmount()) >= 0;
            if (!free && !paid) throw new ServiceException("本次报名的有效收款不足，请核对收款后再办理报到或场次");
            return null;
        });
    }

    public List<EventChoice> events() {
        ManagedOrganization organization = requirePayment();
        return TenantHelper.dynamic(organization.tenantId(), () -> eventMapper.selectList(Wrappers.<BillingEvent>lambdaQuery()
                .eq(BillingEvent::getOrganizationId, organization.organizationId())
                .orderByDesc(BillingEvent::getId))
            .stream().map(event -> new EventChoice(event.getId(), event.getName())).toList());
    }

    public List<UnitPrice> units(Long eventId) {
        ManagedOrganization organization = requirePayment();
        return TenantHelper.dynamic(organization.tenantId(), () -> {
            requireEvent(organization, eventId);
            boolean unified = !settings(config(eventId)).channels().isEmpty();
            List<BillingUnit> units = unitMapper.selectList(Wrappers.<BillingUnit>lambdaQuery()
                .eq(BillingUnit::getEventId, eventId)
                .orderByAsc(BillingUnit::getId));
            List<UnitPrice> cards = new ArrayList<>();
            for (BillingUnit unit : units) {
                SportsFeePolicy active = activePolicy(unit.getId());
                cards.add(new UnitPrice(unit.getId(), unit.getName(),
                    active == null ? null : active.getAmount(),
                    active == null ? null : unified && !"free".equals(active.getPaymentMode()) ? "event" : active.getPaymentMode(),
                    active == null ? null : active.getPayInstruction(),
                    active == null ? null : active.getQrFileId()));
            }
            return cards;
        });
    }

    /**
     * 新项目的第一版收费。不检查付款权限，由建立项目的事务一起提交。
     * 已经有相同生效版本时直接返回，避免重试再插一版。
     */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.finance.financeservice.placeinitialpolicy",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public void placeInitialPolicy(String tenantId, Long unitId, BigDecimal amount, String paymentMode, String instruction, Long qrFileId) {
        String mode = requiredMode(paymentMode);
        BigDecimal price = normalize(amount);
        FeeRules.obligationStatus(mode, price);
        String note = blankToNull(instruction);
        Long qr = qrFile(tenantId, mode, qrFileId);
        TenantHelper.dynamic(tenantId, () -> {
            SportsFeePolicy current = activePolicy(unitId);
            if (current != null) {
                if (mode.equals(current.getPaymentMode()) && FeeRules.sameMoney(current.getAmount(), price)
                    && java.util.Objects.equals(note, blankToNull(current.getPayInstruction()))
                    && java.util.Objects.equals(qr, current.getQrFileId())) {
                    return null;
                }
                throw new ServiceException("这个项目已经有不同的收费版本");
            }
            SportsFeePolicy policy = new SportsFeePolicy();
            policy.setUnitId(unitId);
            policy.setRevision(1);
            policy.setPricingUnit("entry");
            policy.setAmount(price);
            policy.setPaymentMode(mode);
            policy.setPayInstruction(note);
            policy.setQrFileId(qr);
            policy.setPricingRules("{\"pricing\":\"entry\"}");
            policy.setPayerModes("{}");
            policy.setCollectionPaths("{\"subject\":\"organizer\"}");
            policy.setRefundTerms("{}");
            policy.setStatus("active");
            policy.setVersion(0);
            policyMapper.insert(policy);
            return null;
        });
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.finance.financeservice.publish",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public UnitPrice publish(Long unitId, BigDecimal amount, String paymentMode, String instruction, Long qrFileId) {
        ManagedOrganization organization = requirePayment();
        String mode = requiredMode(paymentMode);
        BigDecimal price = normalize(amount);
        FeeRules.obligationStatus(mode, price);
        String note = blankToNull(instruction);
        Long qr = qrFile(organization.tenantId(), mode, qrFileId);
        return TenantHelper.dynamic(organization.tenantId(), () -> locked("fee-policy:" + organization.tenantId() + ":" + unitId, () -> {
            BillingUnit unit = unitMapper.selectById(unitId);
            if (unit == null) {
                throw new ServiceException("竞赛项目不存在");
            }
            requireEvent(organization, unit.getEventId());
            requirePaymentEditable(organization, unit.getEventId());
            SportsFeePolicy policy = activatePolicy(unitId, price, mode, note, qr);
            return new UnitPrice(unitId, unit.getName(), policy.getAmount(), policy.getPaymentMode(), policy.getPayInstruction(), policy.getQrFileId());
        }));
    }

    /**
     * 连续聊天只改本人空草稿的整单价。调用方持有赛事/任务事务；此处先复验赛事锁，
     * 不取 fee-policy Redis 锁，避免和工作区的 Redis → 赛事顺序形成环。
     */
    @org.springframework.transaction.annotation.Transactional(
        propagation = org.springframework.transaction.annotation.Propagation.MANDATORY, rollbackFor = Exception.class)
    public void reviseUnusedDraftPolicy(String tenantId, Long eventId, Long unitId, BigDecimal amount) {
        ManagedOrganization organization = requirePayment();
        if (!java.util.Objects.equals(tenantId, organization.tenantId())) throw new ServiceException("组织会话不匹配");
        BigDecimal price = normalize(amount);
        String mode = price.signum() == 0 ? "free" : "event";
        FeeRules.obligationStatus(mode, price);
        TenantHelper.dynamic(tenantId, () -> {
            BillingEvent event = eventMapper.lock(eventId);
            if (event == null || !java.util.Objects.equals(tenantId, event.getTenantId())
                || !java.util.Objects.equals(organization.organizationId(), event.getOrganizationId())) {
                throw new ServiceException("赛事不存在");
            }
            if (!"draft".equals(event.getPublicationStatus()) || !"normal".equals(event.getHoldingStatus())) {
                throw new ServiceException("只有未发布的办赛草稿可以继续修改费用");
            }
            if (!java.util.Objects.equals(0, event.getPublishedRevision())
                || Boolean.TRUE.equals(event.getRegistrationReviewLocked())
                || eventMapper.hasDraftBusinessHistory(tenantId, eventId)) {
                throw new ServiceException("赛事已有发布、报名或资金历史，不能继续修改草稿费用");
            }
            BillingUnit unit = unitMapper.selectOne(Wrappers.<BillingUnit>lambdaQuery()
                .eq(BillingUnit::getId, unitId).last("FOR UPDATE"));
            if (unit == null || !java.util.Objects.equals(eventId, unit.getEventId())
                || !java.util.Objects.equals(tenantId, unit.getTenantId())) throw new ServiceException("赛事项目不存在");
            SportsFeePolicy current = activePolicy(unitId);
            // 无意义的重复聊天保存不产生价格历史；既有渠道及当前支付方式保持。
            if (current != null && FeeRules.sameMoney(current.getAmount(), price)) return null;
            activatePolicy(unitId, price, mode, null, null);
            return null;
        });
    }

    /** 赛事行锁下复用正式配价版本规则；旧金额和全部旧版本始终保留。 */
    private SportsFeePolicy activatePolicy(Long unitId, BigDecimal price, String mode, String note, Long qr) {
        SportsFeePolicy current = activePolicy(unitId);
        if (current != null) {
            current.setStatus("retired");
            saved(policyMapper.updateById(current), "收费版本已被更新，请再试一次");
        }
        Integer max = policyMapper.selectList(Wrappers.<SportsFeePolicy>lambdaQuery()
                .eq(SportsFeePolicy::getUnitId, unitId))
            .stream().map(SportsFeePolicy::getRevision).max(Integer::compareTo).orElse(0);
        SportsFeePolicy policy = new SportsFeePolicy();
        policy.setUnitId(unitId);
        policy.setRevision(max + 1);
        policy.setPricingUnit("entry");
        policy.setAmount(price);
        policy.setPaymentMode(mode);
        policy.setPayInstruction(note);
        policy.setQrFileId(qr);
        policy.setPricingRules("{\"pricing\":\"entry\"}");
        policy.setPayerModes("{}");
        policy.setCollectionPaths("{\"subject\":\"organizer\"}");
        policy.setRefundTerms("{}");
        policy.setStatus("active");
        policy.setVersion(0);
        policyMapper.insert(policy);
        return policy;
    }

    public List<ObligationCard> obligations(Long unitId) {
        ManagedOrganization organization = requirePayment();
        return TenantHelper.dynamic(organization.tenantId(), () -> {
            BillingUnit unit = unitMapper.selectById(unitId);
            if (unit == null) {
                throw new ServiceException("竞赛项目不存在");
            }
            requireEvent(organization, unit.getEventId());
            List<BillingRegistration> registrations = registrationMapper.selectList(Wrappers.<BillingRegistration>lambdaQuery()
                .eq(BillingRegistration::getUnitId, unitId));
            List<ObligationCard> cards = new ArrayList<>();
            for (BillingRegistration registration : registrations) {
                SportsFeeObligation obligation = latest(registration.getId());
                if (obligation == null) {
                    continue;
                }
                cards.add(toCard(obligation, registration.getStatus()));
            }
            return cards;
        });
    }

    /** All actual duties remain reachable after withdrawal/refund. This does not reopen them for payment. */
    public List<ObligationHistory> history(Long registrationId) {
        if (org.dromara.sports.platform.core.BusinessIdentity.getUserType() == org.dromara.common.core.enums.UserType.PLATFORM_USER)
            throw new ServiceException("请先进入办赛组织");
        ManagedOrganization organization = requirePayment();
        if (!organization.tenantId().equals(org.dromara.sports.platform.core.BusinessIdentity.getTenantId()))
            throw new ServiceException("组织会话不匹配");
        return TenantHelper.dynamic(organization.tenantId(), () -> {
            BillingRegistration registration = registrationMapper.selectById(registrationId);
            BillingUnit unit = registration == null ? null : unitMapper.selectById(registration.getUnitId());
            if (unit == null) throw new ServiceException("报名不存在");
            requireEvent(organization, unit.getEventId());
            List<SportsFeeObligation> duties = obligationMapper.selectList(Wrappers.<SportsFeeObligation>lambdaQuery()
                .eq(SportsFeeObligation::getRegistrationId, registrationId).orderByDesc(SportsFeeObligation::getId));
            Long current = duties.isEmpty() ? null : duties.get(0).getId();
            return duties.stream().map(duty -> new ObligationHistory(duty.getId(), rosterRevision(duty),
                duty.getCreateTime() == null ? null : duty.getCreateTime().toInstant().atOffset(SHANGHAI).toString(), duty.getTotalAmount(), netAmount(duty.getId()),
                duty.getStatus(), paymentMode(duty), duty.getId().equals(current), pendingDuty(organization.tenantId(), duty))).toList();
        });
    }

    public record ObligationHistory(Long obligationId, Integer rosterRevision, String createdAt, BigDecimal dueAmount,
                                    BigDecimal netAmount, String status, String paymentMode, boolean current, boolean pending) { }

    /** Old snapshots have no revision: never invent one from row order or the current roster. */
    private Integer rosterRevision(SportsFeeObligation duty) {
        try {
            JsonNode value = objectMapper.readTree(duty.getQuoteSnapshot()).path("rosterRevision");
            return value.isIntegralNumber() && value.canConvertToInt() && value.asInt() > 0 ? value.asInt() : null;
        } catch (Exception invalid) { return null; }
    }

    /** 本组织用途授权后查询，保留冲正事实；不把付款声明生成实际收款。 */
    public FundRecords records(Long obligationId) {
        if (org.dromara.sports.platform.core.BusinessIdentity.getUserType() == org.dromara.common.core.enums.UserType.PLATFORM_USER) {
            throw new ServiceException("请先进入办赛组织");
        }
        ManagedOrganization organization = requirePayment();
        if (!organization.tenantId().equals(org.dromara.sports.platform.core.BusinessIdentity.getTenantId())) {
            throw new ServiceException("组织会话不匹配");
        }
        return TenantHelper.dynamic(organization.tenantId(), () -> {
            SportsFeeObligation obligation = requireObligation(obligationId);
            BillingRegistration registration = registrationMapper.selectById(obligation.getRegistrationId());
            if (registration == null) throw new ServiceException("报名不存在");
            BillingUnit unit = unitMapper.selectById(registration.getUnitId());
            if (unit == null) throw new ServiceException("竞赛项目不存在");
            requireEvent(organization, unit.getEventId());
            List<SportsPaymentAllocation> allocations = allocationMapper.selectList(Wrappers.<SportsPaymentAllocation>lambdaQuery()
                .eq(SportsPaymentAllocation::getObligationId, obligationId).orderByAsc(SportsPaymentAllocation::getId));
            List<ReceiptRecord> receipts = new ArrayList<>();
            List<RefundRecord> refunds = new ArrayList<>();
            java.util.Set<Long> seen = new java.util.HashSet<>();
            for (SportsPaymentAllocation allocation : allocations) {
                SportsPayment payment = paymentMapper.selectById(allocation.getPaymentId());
                if (payment == null) continue;
                receipts.add(new ReceiptRecord(payment.getId(), payment.getPayerName(), payment.getAmount(),
                    allocation.getAmount(), payment.getOccurredAt(), payment.getConfirmedAt(), payment.getStatus(), allocation.getStatus(), refundedAmount(payment.getId()), pendingAction(payment.getId()) == null ? null : pendingAction(payment.getId()).getId()));
                if (seen.add(payment.getId())) {
                    for (SportsRefund refund : refundMapper.selectList(Wrappers.<SportsRefund>lambdaQuery()
                        .eq(SportsRefund::getPaymentId, payment.getId()).orderByAsc(SportsRefund::getId))) {
                        refunds.add(new RefundRecord(refund.getId(), payment.getId(), refund.getCompletedAmount(),
                            refund.getCompletedAt(), refund.getStatus(), refund.getReason(), refund.getRecipientName(), refund.getRecipientBasis()));
                    }
                }
            }
            return new FundRecords(receipts, refunds, exceptionRecords(organization.tenantId(), obligationId), netAmount(obligation.getId()), obligation.getTotalAmount());
        });
    }

    public record ReceiptRecord(Long paymentId, String payerName, BigDecimal amount, BigDecimal allocatedAmount,
                                OffsetDateTime occurredAt, OffsetDateTime confirmedAt, String status, String allocationStatus, BigDecimal refundedAmount, Long pendingActionId) { }
    public record RefundRecord(Long refundId, Long paymentId, BigDecimal amount, OffsetDateTime completedAt, String status, String reason, String recipientName, String recipientBasis) { }
    public record PaymentExceptionRecord(Long exceptionId, Long paymentId, String exceptionType, String externalReference,
                                         BigDecimal reportedAmount, String status, Integer version, String resolutionNote,
                                         String resolvedAt, Long responsibleUserId) { }
    public record FundRecords(List<ReceiptRecord> receipts, List<RefundRecord> refunds, List<PaymentExceptionRecord> exceptions, BigDecimal netAmount, BigDecimal dueAmount) { }

    /**
     * 人工核对重复请求冲突，不登记到账、不调整原资金或恢复资格。
     * 本组织payment岗位按原账本填写依据；原异常保留，结论与审计在同一事务提交。
     */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.finance.payment_exception.resolve_duplicate", title="人工核对重复收款异常", agent=false,
        reads={"asp_payment_exception","asp_fee_obligation","asp_registration","asp_competition_unit","asp_event","asp_organization","asp_staff_grant","asp_account_tenant_principal","asp_payment_allocation"},
        writes={"asp_payment_exception","asp_audit_event"})
    public PaymentExceptionRecord resolveDuplicateException(Long obligationId, Long exceptionId, Integer expectedVersion, String note, String requestKey) {
        if (org.dromara.sports.platform.core.TrustedRunContext.current() != null || !LoginHelper.isLogin()
            || LoginHelper.getUserType() != org.dromara.common.core.enums.UserType.SYS_USER) {
            throw new ServiceException("请由本组织资金责任岗位本人核对", 403);
        }
        ManagedOrganization organization = requirePayment();
        String explanation = required(note, 1000, "实际账本核对依据与处理说明");
        String key = required(requestKey, 128, "请求键");
        if (!key.matches("[a-zA-Z0-9:_.-]{1,128}") || expectedVersion == null || expectedVersion < 0) {
            throw new ServiceException("请核对当前异常版本和有效请求编号", 400);
        }
        return TenantHelper.dynamic(organization.tenantId(), () -> locked("fee-exception:" + organization.tenantId() + ":" + exceptionId, () -> {
            // 不同异常同时复用同一键也须串行；锁只保护本租户这一笔核对请求。
            exceptionJdbc.lock("fee-exception-key:" + organization.tenantId() + ":" + key);
            requireOwnedObligation(organization, lockObligation(obligationId));
            var row = exceptionJdbc.one("SELECT x.*,x.resolution::text AS resolution FROM asp_payment_exception x WHERE x.id=? AND x.tenant_id=? AND (x.obligation_id=? OR (x.obligation_id IS NULL AND EXISTS(SELECT 1 FROM asp_payment_allocation a WHERE a.payment_id=x.payment_id AND a.obligation_id=?))) FOR UPDATE",
                exceptionId, organization.tenantId(), obligationId, obligationId);
            if (row == null) throw new ServiceException("异常不属于本次付款义务", 404);
            if (!"duplicate_payment".equals(row.get("exception_type"))) throw new ServiceException("当前入口只办理重复请求冲突，请联系平台核实其他异常", 409);
            var previous = exceptionJdbc.one("SELECT id FROM asp_payment_exception WHERE tenant_id=? AND resolution->>'requestKey'=?", organization.tenantId(), key);
            JsonNode resolution = resolution(row);
            if (previous != null) {
                if (((Number) previous.get("id")).longValue() != exceptionId || !"resolved".equals(row.get("status"))
                    || !explanation.equals(resolution.path("note").asText()) || expectedVersion != resolution.path("expectedVersion").asInt(-1)
                    || !String.valueOf(LoginHelper.getUserId()).equals(resolution.path("responsibleUserId").asText())) {
                    throw new ServiceException("这个请求编号已用于不同核对内容，请刷新核对", 409);
                }
                return exceptionRecord(row);
            }
            if ("resolved".equals(row.get("status"))) throw new ServiceException("这条异常已经核对结案，请刷新查看原说明", 409);
            if (!java.util.Set.of("open", "investigating", "disputed").contains(String.valueOf(row.get("status")))) throw new ServiceException("异常状态需要平台核实，不能直接结案", 409);
            if (((Number) row.get("version")).intValue() != expectedVersion) throw new ServiceException("异常已被更新，请刷新后核对", 409);
            var evidence = objectMapper.createObjectNode();
            evidence.put("note", explanation); evidence.put("requestKey", key); evidence.put("expectedVersion", expectedVersion);
            evidence.put("responsibleUserId", String.valueOf(LoginHelper.getUserId()));
            evidence.put("actorAccountId", String.valueOf(organization.accountId())); evidence.put("resolvedAt", now().toString());
            String serialized = evidence.toString();
            saved(exceptionJdbc.update("UPDATE asp_payment_exception SET status='resolved',owner_id=?,resolution=?::jsonb,version=version+1,update_time=CURRENT_TIMESTAMP WHERE id=? AND tenant_id=? AND version=? AND status<>'resolved'",
                LoginHelper.getUserId(), serialized, exceptionId, organization.tenantId(), expectedVersion), "异常已被更新，请刷新后核对");
            var summary = evidence.deepCopy(); summary.put("exceptionType", "duplicate_payment"); summary.put("originalVersion", expectedVersion); summary.put("newVersion", expectedVersion + 1);
            exceptionJdbc.update("INSERT INTO asp_audit_event(id,tenant_id,actor_account_id,action,object_type,object_id,request_id,occurred_at,summary) VALUES (?,?,?,'finance.duplicate_payment.resolve','payment_exception',?,?,CURRENT_TIMESTAMP,?::jsonb)",
                org.dromara.sports.platform.core.BusinessSupport.nextId(), organization.tenantId(), organization.accountId(), exceptionId, key, summary.toString());
            var saved = new LinkedHashMap<>(row); saved.put("status", "resolved"); saved.put("owner_id", LoginHelper.getUserId()); saved.put("resolution", serialized); saved.put("version", expectedVersion + 1);
            return exceptionRecord(saved);
        }));
    }

    private List<PaymentExceptionRecord> exceptionRecords(String tenantId, Long obligationId) {
        return exceptionJdbc.list("SELECT x.*,x.resolution::text AS resolution FROM asp_payment_exception x WHERE x.tenant_id=? AND (x.obligation_id=? OR (x.obligation_id IS NULL AND EXISTS(SELECT 1 FROM asp_payment_allocation a WHERE a.payment_id=x.payment_id AND a.obligation_id=?))) ORDER BY x.create_time,x.id",
            tenantId, obligationId, obligationId).stream().map(this::exceptionRecord).toList();
    }
    private JsonNode resolution(Map<String,Object> row) {
        try { return objectMapper.readTree(row.get("resolution") == null ? "{}" : row.get("resolution").toString()); }
        catch (JsonProcessingException invalid) { throw new ServiceException("异常核对记录格式有误，请联系平台核实"); }
    }
    private PaymentExceptionRecord exceptionRecord(Map<String,Object> row) {
        JsonNode resolution = resolution(row);
        return new PaymentExceptionRecord(((Number) row.get("id")).longValue(), row.get("payment_id") == null ? null : ((Number) row.get("payment_id")).longValue(),
            String.valueOf(row.get("exception_type")), row.get("external_reference") == null ? null : row.get("external_reference").toString(),
            row.get("reported_amount") == null ? null : new BigDecimal(row.get("reported_amount").toString()), String.valueOf(row.get("status")), ((Number) row.get("version")).intValue(),
            resolution.path("note").asText(null), resolution.path("resolvedAt").asText(null), row.get("owner_id") == null ? null : ((Number) row.get("owner_id")).longValue());
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.finance.financeservice.confirmmanual",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public ObligationCard confirmManual(Long obligationId, String payerName, BigDecimal reportedAmount, String occurredAt,
                                        String note, Long payerAccountId, String requestKey) {
        ManagedOrganization organization = requirePayment();
        String name = required(payerName, 200, "实际付款人");
        String key = required(requestKey, 128, "请求键");
        BigDecimal reported = normalize(reportedAmount);
        String remark = optional(note, 1000, "备注");
        OffsetDateTime paidAt = parsePaidAt(required(occurredAt, 32, "实际到账时间"));
        return TenantHelper.dynamic(organization.tenantId(), () -> locked("fee-pay:" + obligationId, () -> {
            SportsFeeObligation owned = lockObligation(obligationId);
            requireOwnedObligation(organization, owned);
            SportsPayment existing = paymentMapper.selectOne(Wrappers.<SportsPayment>lambdaQuery()
                .eq(SportsPayment::getRequestKey, key));
            if (existing != null) {
                if (sameManualFacts(existing, obligationId, name, payerAccountId, reported, paidAt)) {
                    return finishSettlement(organization.tenantId(), obligationOfPayment(existing));
                }
                SportsFeeObligation requested = lockObligation(obligationId);
                recordException(requested, existing.getId(), "duplicate_payment", key, reported);
                throw new ServiceException("这个请求已经用于不同的付款内容");
            }
            SportsFeeObligation obligation = lockObligation(obligationId);
            requireOwnedObligation(organization, obligation);
            if ("not_required".equals(obligation.getStatus()) || reported.signum() <= 0) throw new ServiceException("免费报名不登记收款，实际金额必须大于零");
            SportsPayment payment = newPayment(obligation, name, payerAccountId,
                payerAccountId == null ? "external" : "known", "manual", null, key);
            payment.setAmount(reported);
            payment.setOccurredAt(paidAt);
            payment.setEvidence(evidence(remark));
            paymentMapper.insert(payment);
            insertAllocation(payment, obligation, key);
            refreshNetStatus(obligation);
            if (!isLiveEntry(obligation) || netAmount(obligation.getId()).compareTo(obligation.getTotalAmount()) > 0) ensurePendingAction(obligation, "真实到账需人工核对退改或多付款项");
            return finishSettlement(organization.tenantId(), obligation);
        }));
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.finance.financeservice.confirmcallback",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public ObligationCard confirmCallback(Long obligationId, String externalRef, BigDecimal reportedAmount, String payerName) {
        throw new ServiceException("一期只允许核对真实付款后人工登记，不启用支付回调确认");
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.finance.financeservice.reverse",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public ObligationCard reverse(Long obligationId, String requestKey) { return reverse(obligationId, null, requestKey); }
    @org.dromara.sports.platform.core.SportsAction(value="legacy.finance.financeservice.reverse",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public ObligationCard reverse(Long obligationId, Long paymentId, String requestKey) {
        ManagedOrganization organization = requirePayment();
        required(requestKey, 128, "请求键");
        return TenantHelper.dynamic(organization.tenantId(), () -> locked("fee-pay:" + obligationId, () -> {
            SportsFeeObligation obligation = lockObligation(obligationId);
            requireOwnedObligation(organization, obligation);
            if (paymentId == null) throw new ServiceException("请在原收款记录上选择具体要撤销的错误到账");
            SportsPayment payment = paymentMapper.selectById(paymentId);
            if (paymentId != null && allocationMapper.selectCount(Wrappers.<SportsPaymentAllocation>lambdaQuery().eq(SportsPaymentAllocation::getPaymentId, paymentId).eq(SportsPaymentAllocation::getObligationId, obligationId)) == 0) throw new ServiceException("原收款不属于此义务");
            if (payment != null && "reversed".equals(payment.getStatus())) return toCard(obligation);
            if (payment == null) {
                throw new ServiceException("没有可以撤销的到账确认");
            }
            if (refundedAmount(payment.getId()).signum() > 0) throw new ServiceException("这笔收款已有真实退款，请先受控核对，不能直接撤销到账");
            payment.setStatus("reversed");
            saved(paymentMapper.updateById(payment), "到账已被更新，请再试一次");
            SportsPaymentAllocation allocation = allocationMapper.selectOne(Wrappers.<SportsPaymentAllocation>lambdaQuery()
                .eq(SportsPaymentAllocation::getPaymentId, payment.getId())
                .eq(SportsPaymentAllocation::getStatus, "effective"));
            if (allocation != null) {
                allocation.setStatus("reversed");
                allocationMapper.updateById(allocation);
            }
            refreshNetStatus(obligation);
            SportsPaymentAction pending = pendingAction(payment.getId());
            if (pending != null) {
                pending.setStatus("closed_no_refund");
                pending.setNote("到账确认已冲正，不再处理退款");
                actionMapper.updateById(pending);
            }
            return toCard(obligation);
        }));
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.finance.financeservice.closewithoutrefund",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public ObligationCard closeWithoutRefund(Long actionId, String note) {
        return finishAction(actionId, "closed_no_refund", required(note, 1000, "无需退款原因"), null);
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.finance.financeservice.recordrefund",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public ObligationCard recordRefund(Long actionId, String note, String requestKey) {
        throw new ServiceException("请填写实际退款金额、时间和接收人后登记");
    }

    /** 每次退款锁原义务，累计不得超过该原款；部分退款保留待办。 */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.finance.financeservice.recordrefund",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public ObligationCard recordRefund(Long actionId, String note, String requestKey, BigDecimal amount, String occurredAt, String recipient, String recipientBasis) {
        ManagedOrganization organization = requirePayment();
        String key = required(requestKey, 128, "请求键");
        String reason = required(note, 1000, "退款依据");
        String receiver = required(recipient, 200, "退款接收人");
        OffsetDateTime at = parsePaidAt(required(occurredAt, 32, "实际退款时间"));
        BigDecimal actual = normalize(amount);
        if (actual.signum() <= 0) throw new ServiceException("实际退款金额须大于零");
        return TenantHelper.dynamic(organization.tenantId(), () -> {
            SportsPaymentAction action = actionMapper.selectById(actionId);
            if (action == null) throw new ServiceException("退款事项不存在");
            return locked("fee-pay:" + action.getObligationId(), () -> {
                SportsFeeObligation obligation = lockObligation(action.getObligationId());
                requireOwnedObligation(organization, obligation);
                SportsPayment payment = paymentMapper.selectById(action.getPaymentId());
                if (payment == null || !"confirmed".equals(payment.getStatus())) throw new ServiceException("原收款不再有效");
                String basis = optional(recipientBasis, 1000, "接收人变更授权依据");
                if (!receiver.equals(payment.getPayerName()) && (basis == null || basis.isBlank())) throw new ServiceException("接收人与原付款人不同，请填写核验授权依据");
                SportsRefund previous = refundMapper.selectOne(Wrappers.<SportsRefund>lambdaQuery().eq(SportsRefund::getPaymentId, payment.getId()).eq(SportsRefund::getRequestKey, key));
                if (previous != null) {
                    if (!FeeRules.sameMoney(previous.getCompletedAmount(), actual) || !java.util.Objects.equals(previous.getRecipientName(), receiver) || !java.util.Objects.equals(previous.getRecipientBasis(), basis) || !java.util.Objects.equals(previous.getReason(), reason) || previous.getCompletedAt() == null || !previous.getCompletedAt().isEqual(at)) throw new ServiceException("请求键已用于不同退款事实");
                    return toCard(obligation);
                }
                SportsPaymentAction current = actionMapper.selectById(actionId);
                if (!"pending".equals(current.getStatus())) throw new ServiceException("没有待处理的退款事项");
                BigDecimal cumulative = refundedAmount(payment.getId()).add(actual);
                if (cumulative.compareTo(payment.getAmount()) > 0) throw new ServiceException("累计退款不能超过原有效收款");
                SportsRefund refund = new SportsRefund(); refund.setPaymentId(payment.getId()); refund.setRequestedAmount(actual); refund.setApprovedAmount(actual); refund.setCompletedAmount(actual); refund.setStatus("completed"); refund.setReason(reason); refund.setRecipientName(receiver); refund.setRecipientBasis(basis); refund.setRequestKey(key); refund.setCompletedAt(at); refund.setVersion(0); refundMapper.insert(refund);
                current.setStatus(cumulative.compareTo(payment.getAmount()) == 0 ? "refunded" : "pending"); current.setNote(reason); saved(actionMapper.updateById(current), "退款待办已变化，请刷新");
                refreshNetStatus(obligation);
                return toCard(obligation);
            });
        });
    }

    private ObligationCard finishAction(Long actionId, String status, String note, String refundKey) {
        ManagedOrganization organization = requirePayment();
        return TenantHelper.dynamic(organization.tenantId(), () -> {
            SportsPaymentAction action = actionMapper.selectById(actionId);
            if (action == null || !"pending".equals(action.getStatus())) {
                throw new ServiceException("没有待处理的退款事项");
            }
            return locked("fee-pay:" + action.getObligationId(), () -> {
                requireOwnedObligation(organization, lockObligation(action.getObligationId()));
                SportsPaymentAction current = actionMapper.selectById(actionId);
                if (current == null || !"pending".equals(current.getStatus())) {
                    throw new ServiceException("没有待处理的退款事项");
                }
                current.setStatus(status);
                current.setNote(note);
                saved(actionMapper.updateById(current), "资金后续已被更新，请再试一次");
                return toCard(requireObligation(current.getObligationId()));
            });
        });
    }

    private SportsPayment newPayment(SportsFeeObligation obligation, String payerName, Long payerAccountId, String presence,
                                     String source, String externalRef, String requestKey) {
        SportsPayment payment = new SportsPayment();
        payment.setPayerAccountId(payerAccountId);
        payment.setPayerName(payerName);
        payment.setPayerPresence(presence);
        payment.setPaymentMode(paymentMode(obligation));
        payment.setConfirmationSource(source);
        payment.setPayeeSubject(PAYEE);
        payment.setTransactionId(externalRef);
        payment.setAmount(obligation.getTotalAmount());
        payment.setCurrency(CURRENCY);
        payment.setStatus("confirmed");
        payment.setEvidence("{}");
        payment.setConfirmedAt(now());
        payment.setRequestKey(requestKey);
        payment.setVersion(0);
        return payment;
    }

    private void insertAllocation(SportsPayment payment, SportsFeeObligation obligation, String requestKey) {
        SportsPaymentAllocation allocation = new SportsPaymentAllocation();
        allocation.setPaymentId(payment.getId());
        allocation.setObligationId(obligation.getId());
        allocation.setAmount(payment.getAmount());
        allocation.setStatus("effective");
        allocation.setRequestKey(requestKey);
        allocation.setVersion(0);
        allocationMapper.insert(allocation);
    }

    private void recordException(SportsFeeObligation obligation, Long paymentId, String type, String reference, BigDecimal reported) {
        // The rejected request holds this obligation's row lock. An immediate REQUIRES_NEW
        // insert waits on its foreign-key check against that same outer lock indefinitely.
        // Persist the rejected attempt only after rollback releases the lock; restore the
        // original server-issued identity and table declaration for the independent audit.
        Long obligationId = obligation.getId();
        String tenantId = obligation.getTenantId();
        ActionContext sourceContext = ActionContext.current();
        Runnable persist = () -> {
            ActionContext previous = ActionContext.current();
            if (sourceContext != null) ActionContext.bind(sourceContext);
            try {
                TenantHelper.dynamic(tenantId, () -> {
                    TransactionTemplate template = new TransactionTemplate(transactionManager);
                    template.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
                    return template.execute(status -> {
                        SportsPaymentException exception = new SportsPaymentException();
                        exception.setTenantId(tenantId);
                        exception.setPaymentId(paymentId);
                        exception.setObligationId(obligationId);
                        exception.setExceptionType(type);
                        exception.setExternalReference(reference);
                        exception.setReportedAmount(reported);
                        exception.setStatus("open");
                        exception.setVersion(0);
                        exceptionMapper.insert(exception);
                        return null;
                    });
                });
            } finally {
                if (previous == null) ActionContext.clear(); else ActionContext.bind(previous);
            }
        };
        if (TransactionSynchronizationManager.isActualTransactionActive()
            && TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override public void afterCompletion(int status) { persist.run(); }
            });
        } else {
            persist.run();
        }
    }

    private void ensurePendingAction(SportsFeeObligation obligation, String note) {
        for (SportsPaymentAllocation allocation : allocationMapper.selectList(Wrappers.<SportsPaymentAllocation>lambdaQuery().eq(SportsPaymentAllocation::getObligationId, obligation.getId()).eq(SportsPaymentAllocation::getStatus, "effective"))) {
            SportsPayment payment = paymentMapper.selectById(allocation.getPaymentId());
            if (payment == null || !"confirmed".equals(payment.getStatus()) || payment.getAmount().subtract(refundedAmount(payment.getId())).signum() <= 0 || pendingAction(payment.getId()) != null) continue;
            SportsPaymentAction action = new SportsPaymentAction(); action.setPaymentId(payment.getId()); action.setObligationId(obligation.getId()); action.setStatus("pending"); action.setNote(note); action.setVersion(0); actionMapper.insert(action);
        }
    }

    private void requireOwnedObligation(ManagedOrganization organization, SportsFeeObligation obligation) {
        BillingRegistration registration = registrationMapper.selectById(obligation.getRegistrationId());
        BillingUnit unit = registration == null ? null : unitMapper.selectById(registration.getUnitId());
        if (unit == null) throw new ServiceException("报名不存在");
        requireEvent(organization, unit.getEventId());
    }
    private BigDecimal refundedAmount(Long paymentId) {
        return refundMapper.selectList(Wrappers.<SportsRefund>lambdaQuery().eq(SportsRefund::getPaymentId, paymentId).eq(SportsRefund::getStatus, "completed")).stream().map(r -> r.getCompletedAmount() == null ? BigDecimal.ZERO : r.getCompletedAmount()).reduce(BigDecimal.ZERO, BigDecimal::add);
    }
    private BigDecimal netAmount(Long obligationId) {
        BigDecimal net = BigDecimal.ZERO;
        for (SportsPaymentAllocation allocation : allocationMapper.selectList(Wrappers.<SportsPaymentAllocation>lambdaQuery().eq(SportsPaymentAllocation::getObligationId, obligationId).eq(SportsPaymentAllocation::getStatus, "effective"))) {
            SportsPayment payment = paymentMapper.selectById(allocation.getPaymentId());
            if (payment != null && "confirmed".equals(payment.getStatus())) net = net.add(allocation.getAmount()).subtract(refundedAmount(payment.getId()));
        }
        return net;
    }
    private boolean isLiveEntry(SportsFeeObligation obligation) {
        BillingRegistration registration = registrationMapper.selectById(obligation.getRegistrationId());
        BillingUnit unit = registration == null ? null : unitMapper.selectById(registration.getUnitId());
        BillingEvent event = unit == null ? null : eventMapper.selectById(unit.getEventId());
        SportsFeeObligation current = latest(obligation.getRegistrationId());
        return registration != null && ("submitted".equals(registration.getStatus()) || "approved".equals(registration.getStatus())) && event != null && "normal".equals(event.getHoldingStatus()) && current != null && obligation.getId().equals(current.getId());
    }
    private void refreshNetStatus(SportsFeeObligation obligation) {
        if ("not_required".equals(obligation.getStatus())) return;
        obligation.setStatus(!isLiveEntry(obligation) ? "void" : netAmount(obligation.getId()).compareTo(obligation.getTotalAmount()) >= 0 ? "settled" : "open");
        saved(obligationMapper.updateById(obligation), "资金状态已变化，请刷新");
    }

    private SportsPayment confirmedPayment(Long obligationId) {
        List<SportsPaymentAllocation> allocations = allocationMapper.selectList(Wrappers.<SportsPaymentAllocation>lambdaQuery()
            .eq(SportsPaymentAllocation::getObligationId, obligationId)
            .eq(SportsPaymentAllocation::getStatus, "effective"));
        for (SportsPaymentAllocation allocation : allocations) {
            SportsPayment payment = paymentMapper.selectById(allocation.getPaymentId());
            if (payment != null && "confirmed".equals(payment.getStatus())) {
                return payment;
            }
        }
        return null;
    }

    private SportsPaymentAction pendingAction(Long paymentId) {
        return actionMapper.selectOne(Wrappers.<SportsPaymentAction>lambdaQuery()
            .eq(SportsPaymentAction::getPaymentId, paymentId)
            .eq(SportsPaymentAction::getStatus, "pending"));
    }

    private SportsPaymentAction actionFor(SportsPayment payment) {
        if (payment == null) {
            return null;
        }
        return actionMapper.selectOne(Wrappers.<SportsPaymentAction>lambdaQuery()
            .eq(SportsPaymentAction::getPaymentId, payment.getId())
            .orderByDesc(SportsPaymentAction::getId)
            .last("limit 1"));
    }

    /**
     * 同一把确认键只能重放同一笔义务、付款人、金额和到账时间。
     * 页面每次点击会换新键；这里拦住的是同一请求被改去另一笔事实。
     */
    private boolean sameManualFacts(SportsPayment payment, Long obligationId, String payerName, Long payerAccountId,
                                    BigDecimal reported, OffsetDateTime paidAt) {
        SportsPaymentAllocation allocation = allocationMapper.selectOne(Wrappers.<SportsPaymentAllocation>lambdaQuery()
            .eq(SportsPaymentAllocation::getPaymentId, payment.getId())
            .eq(SportsPaymentAllocation::getStatus, "effective"));
        if (allocation == null || !obligationId.equals(allocation.getObligationId())) {
            return false;
        }
        if (payerName == null || !payerName.equals(payment.getPayerName())) {
            return false;
        }
        if (!java.util.Objects.equals(payerAccountId, payment.getPayerAccountId())) {
            return false;
        }
        if (!FeeRules.sameMoney(payment.getAmount(), reported)) {
            return false;
        }
        return payment.getOccurredAt() != null && paidAt != null && payment.getOccurredAt().isEqual(paidAt);
    }

    private SportsFeeObligation obligationOfPayment(SportsPayment payment) {
        SportsPaymentAllocation allocation = allocationMapper.selectOne(Wrappers.<SportsPaymentAllocation>lambdaQuery()
            .eq(SportsPaymentAllocation::getPaymentId, payment.getId())
            .last("limit 1"));
        if (allocation == null) {
            throw new ServiceException("付款义务不存在");
        }
        return requireObligation(allocation.getObligationId());
    }

    /**
     * 到账已经写在当前事务里。自动通过失败时不把这笔真实到账回滚掉。
     */
    private ObligationCard finishSettlement(String tenantId, SportsFeeObligation obligation) {
        try {
            registrationReviewApi.tryAutoApproveAfterPayment(tenantId, obligation.getRegistrationId());
        } catch (ServiceException exception) {
            // 资格没有自动通过时，承办方仍能看到这笔已确认到账。
        }
        return toCard(requireObligation(obligation.getId()));
    }

    private ObligationCard toCard(SportsFeeObligation obligation) {
        BillingRegistration registration = registrationMapper.selectById(obligation.getRegistrationId());
        return toCard(obligation, registration == null ? "" : registration.getStatus());
    }

    private ObligationCard toCard(SportsFeeObligation obligation, String registrationStatus) {
        SportsPayment payment = confirmedPayment(obligation.getId());
        SportsPaymentAction action = actionMapper.selectOne(Wrappers.<SportsPaymentAction>lambdaQuery().eq(SportsPaymentAction::getObligationId, obligation.getId()).eq(SportsPaymentAction::getStatus, "pending").orderByDesc(SportsPaymentAction::getId).last("limit 1"));
        OffsetDateTime paidAt = payment == null ? null : (payment.getOccurredAt() != null ? payment.getOccurredAt() : payment.getConfirmedAt());
        return new ObligationCard(obligation.getId(), obligation.getRegistrationId(), registrationStatus, obligation.getStatus(),
            obligation.getTotalAmount(), paymentMode(obligation), payment == null ? null : payment.getPayerName(),
            paidAt == null ? null : paidAt.withOffsetSameInstant(SHANGHAI).format(PAID_AT),
            payment == null ? null : text(payment.getEvidence(), "confirmerName"),
            action == null ? null : action.getId(), action == null ? null : action.getStatus());
    }

    private SportsFeePolicy activePolicy(Long unitId) {
        return policyMapper.selectOne(Wrappers.<SportsFeePolicy>lambdaQuery()
            .eq(SportsFeePolicy::getUnitId, unitId)
            .eq(SportsFeePolicy::getStatus, "active"));
    }

    /**
     * 撤回或拒绝后再次提交时，上一笔未付款义务如果还停在 not_required 或 open，先按关闭规则作废。
     * 已到账的 settled 留在原行，本次提交另记新义务。
     */
    private void releaseStaleObligation(Long registrationId) {
        SportsFeeObligation existing = openObligation(registrationId);
        if (existing == null) {
            return;
        }
        BillingRegistration registration = registrationMapper.selectById(registrationId);
        String entryStatus = registration == null ? "" : registration.getStatus();
        if (!"draft".equals(entryStatus) && !"rejected".equals(entryStatus)) {
            return;
        }
        closeForInactiveEntry(lockObligation(existing.getId()));
    }

    private void closeForInactiveEntry(SportsFeeObligation obligation) {
        if (netAmount(obligation.getId()).signum() > 0) {
            ensurePendingAction(obligation, "报名已失效，等待承办方处理已到账款项");
        }
        String next = FeeRules.afterEntryClosed(obligation.getStatus());
        if (!next.equals(obligation.getStatus())) {
            obligation.setStatus(next);
            saved(obligationMapper.updateById(obligation), "付款义务已被更新，请再试一次");
        }
    }

    private SportsFeeObligation openObligation(Long registrationId) {
        return obligationMapper.selectOne(Wrappers.<SportsFeeObligation>lambdaQuery()
            .eq(SportsFeeObligation::getRegistrationId, registrationId)
            .in(SportsFeeObligation::getStatus, "not_required", "open"));
    }

    private SportsFeeObligation latestLive(Long registrationId) {
        return obligationMapper.selectOne(Wrappers.<SportsFeeObligation>lambdaQuery()
            .eq(SportsFeeObligation::getRegistrationId, registrationId)
            .in(SportsFeeObligation::getStatus, "not_required", "open", "settled")
            .orderByDesc(SportsFeeObligation::getId)
            .last("limit 1"));
    }

    private SportsFeeObligation latest(Long registrationId) {
        return obligationMapper.selectOne(Wrappers.<SportsFeeObligation>lambdaQuery()
            .eq(SportsFeeObligation::getRegistrationId, registrationId)
            .orderByDesc(SportsFeeObligation::getId)
            .last("limit 1"));
    }

    private SportsFeeObligation lockObligation(Long obligationId) {
        SportsFeeObligation obligation = obligationMapper.selectOne(Wrappers.<SportsFeeObligation>lambdaQuery().eq(SportsFeeObligation::getId, obligationId).last("FOR UPDATE"));
        if (obligation == null) throw new ServiceException("付款义务不存在");
        return obligation;
    }
    private SportsFeeObligation requireObligation(Long obligationId) {
        SportsFeeObligation obligation = obligationMapper.selectById(obligationId);
        if (obligation == null) {
            throw new ServiceException("付款义务不存在");
        }
        return obligation;
    }

    private void requireEvent(ManagedOrganization organization, Long eventId) {
        BillingEvent event = eventMapper.selectById(eventId);
        if (event == null || !organization.organizationId().equals(event.getOrganizationId())) {
            throw new ServiceException("赛事不存在");
        }
    }

    private ManagedOrganization requirePayment() {
        if (org.dromara.sports.platform.core.BusinessIdentity.getUserType() == org.dromara.common.core.enums.UserType.PLATFORM_USER) throw new ServiceException("请先进入有授权的组织");
        ManagedOrganization organization = sessionApi.managedOrganization(org.dromara.sports.platform.core.BusinessIdentity.getUserId())
            .orElseThrow(() -> new ServiceException("当前账号不能管理这个组织的收费"));
        if (!qualificationApi.hasStaffAction(organization.tenantId(), organization.organizationId(), organization.accountId(), PAYMENT_ACTION)) {
            throw new ServiceException("当前账号不能确认到账");
        }
        if (!java.util.Objects.equals(organization.tenantId(), org.dromara.sports.platform.core.BusinessIdentity.getTenantId())) throw new ServiceException("组织会话不匹配");
        return organization;
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.finance.financeservice.settlecancellation",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public void settleCancellation(String tenantId, Long eventId) {
        transaction().execute(status -> TenantHelper.dynamic(tenantId, () -> {
            List<Long> unitIds = unitMapper.selectList(Wrappers.<BillingUnit>lambdaQuery()
                    .eq(BillingUnit::getEventId, eventId))
                .stream().map(BillingUnit::getId).toList();
            if (unitIds.isEmpty()) {
                return null;
            }
            List<BillingRegistration> registrations = registrationMapper.selectList(Wrappers.<BillingRegistration>lambdaQuery()
                .in(BillingRegistration::getUnitId, unitIds));
            for (BillingRegistration registration : registrations) {
                SportsFeeObligation obligation = latest(registration.getId());
                if (obligation == null || "not_required".equals(obligation.getStatus())) continue;
                SportsFeeObligation lockedObligation = lockObligation(obligation.getId());
                if (netAmount(lockedObligation.getId()).signum() > 0) ensurePendingAction(lockedObligation, "赛事取消，真实款项需按原规则人工收尾");
                lockedObligation.setStatus("void"); saved(obligationMapper.updateById(lockedObligation), "付款义务已变化");
            }
            return null;
        }));
    }

    public boolean unsettled(String tenantId, Long registrationId) {
        if (tenantId == null || registrationId == null) return false;
        return Boolean.TRUE.equals(TenantHelper.dynamic(tenantId, () -> {
            return obligationMapper.selectList(Wrappers.<SportsFeeObligation>lambdaQuery()
                .eq(SportsFeeObligation::getRegistrationId, registrationId))
                .stream().anyMatch(duty -> pendingDuty(tenantId, duty));
        }));
    }

    private boolean pendingDuty(String tenantId, SportsFeeObligation duty) {
        if ("open".equals(duty.getStatus())) return true;
        Long pending = actionMapper.selectCount(Wrappers.<SportsPaymentAction>lambdaQuery()
            .eq(SportsPaymentAction::getObligationId, duty.getId()).eq(SportsPaymentAction::getStatus, "pending"));
        if (pending != null && pending > 0) return true;
        // Legacy exceptions may only identify a payment; its original allocation establishes the scope.
        return exceptionJdbc.count("SELECT count(*) FROM asp_payment_exception x WHERE x.tenant_id=? AND x.status<>'resolved' AND (x.obligation_id=? OR (x.obligation_id IS NULL AND EXISTS(SELECT 1 FROM asp_payment_allocation a WHERE a.payment_id=x.payment_id AND a.obligation_id=?)))",
            tenantId, duty.getId(), duty.getId()) > 0;
    }

    private ObligationView view(SportsFeeObligation obligation, String instruction) {
        SportsPaymentAction pending = actionMapper.selectOne(Wrappers.<SportsPaymentAction>lambdaQuery()
            .eq(SportsPaymentAction::getObligationId, obligation.getId())
            .eq(SportsPaymentAction::getStatus, "pending")
            .orderByDesc(SportsPaymentAction::getId)
            .last("limit 1"));
        return new ObligationView(obligation.getId(), obligation.getFeePolicyId(), obligation.getTotalAmount(),
            paymentMode(obligation), obligation.getStatus(), instruction, obligation.getDeclaredAt() != null,
            pending == null ? null : pending.getId());
    }

    private String paymentMode(SportsFeeObligation obligation) {
        return text(obligation.getQuoteSnapshot(), "paymentMode");
    }

    private String instruction(SportsFeeObligation obligation) {
        return text(obligation.getQuoteSnapshot(), "payInstruction");
    }

    private String text(String json, String field) {
        if (json == null || json.isBlank()) {
            return null;
        }
        try {
            JsonNode node = objectMapper.readTree(json).get(field);
            if (node == null || node.isNull()) {
                return null;
            }
            String value = node.asText();
            return value.isBlank() ? null : value;
        } catch (JsonProcessingException exception) {
            return null;
        }
    }

    private String evidence(String note) {
        Map<String, String> body = new LinkedHashMap<>();
        body.put("confirmerName", LoginHelper.getUsername() == null ? "" : LoginHelper.getUsername());
        body.put("note", note == null ? "" : note);
        try {
            return objectMapper.writeValueAsString(body);
        } catch (JsonProcessingException exception) {
            throw new ServiceException("到账备注无法保存");
        }
    }

    private OffsetDateTime parsePaidAt(String value) {
        if (value == null || value.isBlank()) {
            return now();
        }
        try {
            return LocalDateTime.parse(value.trim(), PAID_AT_INPUT).atOffset(SHANGHAI);
        } catch (DateTimeParseException exception) {
            throw new ServiceException("到账时间格式应为 yyyy-MM-dd HH:mm:ss");
        }
    }

    private String optional(String value, int max, String label) {
        if (value == null || value.isBlank()) {
            return null;
        }
        String trimmed = value.trim();
        if (trimmed.length() > max) {
            throw new ServiceException(label + "不超过" + max + "字");
        }
        return trimmed;
    }

    private String snapshot(SportsFeePolicy policy, Integer rosterRevision) {
        Map<String, Object> body = new LinkedHashMap<>();
        if (rosterRevision != null) body.put("rosterRevision", rosterRevision);
        body.put("amount", policy.getAmount().toPlainString());
        body.put("paymentMode", policy.getPaymentMode());
        body.put("payInstruction", policy.getPayInstruction() == null ? "" : policy.getPayInstruction());
        BillingUnit unit = unitMapper.selectById(policy.getUnitId());
        PaymentSettings settings = "free".equals(policy.getPaymentMode()) ? new PaymentSettings(0, "", List.of()) : settings(config(unit.getEventId()));
        if ("event".equals(policy.getPaymentMode()) || !settings.channels().isEmpty()) {
            if (settings.channels().isEmpty()) throw new ServiceException("赛事尚未设置收款渠道，请联系承办方");
            body.put("paymentMode", "event");
            body.put("paymentSettings", settings);
            body.put("payInstruction", settings.instruction());
        } else if (policy.getQrFileId() != null) {
            body.put("qrFileId", policy.getQrFileId().toString());
        }
        try {
            return objectMapper.writeValueAsString(body);
        } catch (JsonProcessingException exception) {
            throw new ServiceException("收费快照无法保存");
        }
    }

    private <T> T locked(String key, java.util.function.Supplier<T> action) {
        return mutualLock.execute(key, WAIT_MILLIS, LEASE_MILLIS, () -> transaction().execute(status -> action.get()));
    }

    private void saved(int updated, String message) {
        if (updated != 1) {
            throw new ServiceException(message);
        }
    }

    private TransactionTemplate transaction() {
        TransactionTemplate template = new TransactionTemplate(transactionManager);
        template.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRED);
        return template;
    }

    private OffsetDateTime now() {
        return OffsetDateTime.now(SHANGHAI);
    }

    private BigDecimal normalize(BigDecimal amount) {
        if (amount == null) {
            throw new ServiceException("请填写金额");
        }
        try { if (amount.precision() - amount.scale() > 16) throw new ArithmeticException(); return amount.setScale(2, java.math.RoundingMode.UNNECESSARY); }
        catch (ArithmeticException invalid) { throw new ServiceException("金额须为合法人民币金额，最多两位小数"); }
    }

    private String requiredMode(String mode) {
        if (!"free".equals(mode) && !"offline".equals(mode) && !"organizer_qr".equals(mode) && !"event".equals(mode)) {
            throw new ServiceException("收款方式无效");
        }
        return mode;
    }

    private String required(String value, int max, String label) {
        if (value == null || value.isBlank()) {
            throw new ServiceException("请填写" + label);
        }
        String trimmed = value.trim();
        if (trimmed.length() > max) {
            throw new ServiceException(label + "不超过" + max + "字");
        }
        return trimmed;
    }

    private String blankToNull(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim();
    }

    public record EventChoice(Long eventId, String name) {
    }

    public PaymentSettings eventPaymentConfig(Long eventId) {
        ManagedOrganization organization = requirePayment();
        return TenantHelper.dynamic(organization.tenantId(), () -> {
            requireEvent(organization, eventId);
            return settings(config(eventId));
        });
    }

    public StoredObjectApi.ImageBody eventPaymentQr(Long eventId, String channelType) {
        ManagedOrganization organization = requirePayment();
        PaymentSettings settings = eventPaymentConfig(eventId);
        Long fileId = settings.channels().stream().filter(channel -> channel.type().equals(channelType)).map(PaymentChannel::qrFileId)
            .filter(java.util.Objects::nonNull).findFirst().orElseThrow(() -> new ServiceException("这个收款渠道没有二维码"));
        return storedObjectApi.readOwned(fileId, organization.tenantId());
    }

    /** 整场维护，PG赛事行锁与首笔正式提交串行；空配置可保存草稿但收费赛事不能发布/提交。 */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.finance.financeservice.saveeventpaymentconfig",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public PaymentSettings saveEventPaymentConfig(Long eventId, PaymentSettings request) {
        ManagedOrganization organization = requirePayment();
        if (request == null) throw new ServiceException("请填写赛事收款设置");
        return TenantHelper.dynamic(organization.tenantId(), () -> transaction().execute(status -> {
            requirePaymentEditable(organization, eventId);
            SportsEventPaymentConfig row = config(eventId);
            int revision = row == null ? 0 : row.getVersion();
            if (request.revision() != revision) throw new ServiceException("收款设置已被他人修改，请刷新后重试");
            List<PaymentChannel> channels = EventPaymentRules.normalize(request.channels());
            for (PaymentChannel channel : channels) {
                if (channel.qrFileId() != null) storedObjectApi.requireImage(channel.qrFileId(), StoredObjectApi.PAYMENT_QR, organization.tenantId());
            }
            String instruction = optional(request.instruction(), 1000, "赛事付款说明");
            try {
                String json = objectMapper.writeValueAsString(Map.of("schemaVersion", 1, "instruction", instruction == null ? "" : instruction, "channels", channels));
                if (row == null) {
                    row = new SportsEventPaymentConfig(); row.setEventId(eventId); row.setVersion(0); row.setSettings(json);
                    paymentConfigMapper.insert(row);
                } else {
                    row.setSettings(json);
                    saved(paymentConfigMapper.updateById(row), "收款设置已被更新，请刷新后重试");
                }
                return settings(config(eventId));
            } catch (JsonProcessingException invalid) { throw new ServiceException("赛事收款设置无法保存"); }
        }));
    }

    private void requirePaymentEditable(ManagedOrganization organization, Long eventId) {
        BillingEvent event = eventMapper.lock(eventId);
        if (event == null || !organization.organizationId().equals(event.getOrganizationId())) throw new ServiceException("赛事不存在");
        if (Boolean.TRUE.equals(event.getRegistrationReviewLocked())) throw new ServiceException("已有正式报名，项目金额及赛事收款设置已锁定");
        if ("cancelled".equals(event.getHoldingStatus()) || event.getEndsAt() != null && !now().isBefore(event.getEndsAt())) throw new ServiceException("赛事已停止办理，不能修改收款设置");
    }

    private SportsEventPaymentConfig config(Long eventId) {
        return paymentConfigMapper.selectOne(Wrappers.<SportsEventPaymentConfig>lambdaQuery().eq(SportsEventPaymentConfig::getEventId, eventId));
    }

    private PaymentSettings settings(SportsEventPaymentConfig row) {
        if (row == null) return new PaymentSettings(0, "", List.of());
        try {
            JsonNode node = objectMapper.readTree(row.getSettings());
            return new PaymentSettings(row.getVersion(), node.path("instruction").asText(""),
                objectMapper.readerForListOf(PaymentChannel.class).readValue(node.path("channels")));
        } catch (java.io.IOException invalid) { throw new ServiceException("赛事收款设置无法读取，请联系承办方核对"); }
    }

    public boolean eventPaymentReady(String tenantId, Long eventId) {
        return TenantHelper.dynamic(tenantId, () -> !settings(config(eventId)).channels().isEmpty());
    }

    /** Revision-only publication check; the event lock held by the caller also serializes all settings writers. */
    public int eventPaymentRevision(String tenantId,Long eventId){
        return TenantHelper.dynamic(tenantId,()->{var row=config(eventId);if(row==null)return -1;if(row.getVersion()==null)throw new ServiceException("赛事收款设置版本无法核对，请刷新后办理");return row.getVersion();});
    }

    /** 只读当次义务快照；旧义务可从不可变旧收费版本回补收款码，不用当前生效版本。 */
    public PaymentSettings paymentInstructions(String tenantId, Long registrationId) {
        return TenantHelper.dynamic(tenantId, () -> {
            SportsFeeObligation obligation = latest(registrationId);
            if (obligation == null) throw new ServiceException("请先正式提交报名，再查看付款指引");
            try {
                JsonNode quote = objectMapper.readTree(obligation.getQuoteSnapshot());
                if (quote.has("paymentSettings")) return objectMapper.treeToValue(quote.get("paymentSettings"), PaymentSettings.class);
                if ("free".equals(quote.path("paymentMode").asText())) return new PaymentSettings(0, "", List.of());
                SportsFeePolicy policy = policyMapper.selectById(obligation.getFeePolicyId());
                Long qr = quote.hasNonNull("qrFileId") ? Long.valueOf(quote.path("qrFileId").asText()) : policy == null ? null : policy.getQrFileId();
                String note = quote.path("payInstruction").asText("");
                return new PaymentSettings(0, note, List.of(new PaymentChannel(qr == null ? "offline" : "custom_qr", qr == null ? "线下付款" : "承办方收款码", qr, null, null, null, note)));
            } catch (java.io.IOException | NumberFormatException invalid) { throw new ServiceException("本次报名的付款指引无法读取，请联系承办方核对"); }
        });
    }

    public java.util.List<org.dromara.sports.api.FeeApi.PublicUnitPrice> publicUnitPrices(String tenantId, Long eventId) {
        return TenantHelper.dynamic(tenantId, () -> {
            boolean unified = !settings(config(eventId)).channels().isEmpty();
            java.util.List<BillingUnit> units = unitMapper.selectList(Wrappers.<BillingUnit>lambdaQuery()
                .eq(BillingUnit::getEventId, eventId)
                .orderByAsc(BillingUnit::getId));
            java.util.List<org.dromara.sports.api.FeeApi.PublicUnitPrice> prices = new java.util.ArrayList<>();
            for (BillingUnit unit : units) {
                SportsFeePolicy active = activePolicy(unit.getId());
                if (active == null) {
                    // 保留未配置项目，公开展示待确认；发布门禁不能因过滤缺项而误认全部费用已完成。
                    prices.add(new org.dromara.sports.api.FeeApi.PublicUnitPrice(unit.getId(), unit.getName(), null, null, null));
                    continue;
                }
                prices.add(new org.dromara.sports.api.FeeApi.PublicUnitPrice(unit.getId(), unit.getName(), active.getAmount(),
                    unified && !"free".equals(active.getPaymentMode()) ? "event" : active.getPaymentMode(), unified ? null : active.getPayInstruction()));
            }
            return prices;
        });
    }

    public Optional<Long> activeQrFileId(String tenantId, Long unitId) {
        return TenantHelper.dynamic(tenantId, () -> {
            SportsFeePolicy active = activePolicy(unitId);
            if (active == null || !"organizer_qr".equals(active.getPaymentMode()) || active.getQrFileId() == null) {
                return Optional.<Long>empty();
            }
            return Optional.of(active.getQrFileId());
        });
    }

    public StoredObjectApi.ImageBody paymentQr(Long unitId) {
        ManagedOrganization organization = requirePayment();
        return TenantHelper.dynamic(organization.tenantId(), () -> {
            BillingUnit unit = unitMapper.selectById(unitId);
            if (unit == null) {
                throw new ServiceException("竞赛项目不存在");
            }
            requireEvent(organization, unit.getEventId());
            SportsFeePolicy active = activePolicy(unitId);
            if (active == null || active.getQrFileId() == null) {
                throw new ServiceException("这场没有收款码");
            }
            return storedObjectApi.readOwned(active.getQrFileId(), organization.tenantId());
        });
    }

    private Long qrFile(String tenantId, String mode, Long qrFileId) {
        if (!"organizer_qr".equals(mode)) {
            return null;
        }
        if (qrFileId == null) {
            throw new ServiceException("请先上传收款码");
        }
        storedObjectApi.requireImage(qrFileId, StoredObjectApi.PAYMENT_QR, tenantId);
        return qrFileId;
    }

    public record UnitPrice(Long unitId, String unitName, BigDecimal amount, String paymentMode, String payInstruction, Long qrFileId) {
    }

    public record ObligationCard(Long obligationId, Long registrationId, String registrationStatus, String obligationStatus,
                                 BigDecimal amount, String paymentMode, String payerName, String paidAt, String confirmerName,
                                 Long actionId, String actionStatus) {
    }
}
