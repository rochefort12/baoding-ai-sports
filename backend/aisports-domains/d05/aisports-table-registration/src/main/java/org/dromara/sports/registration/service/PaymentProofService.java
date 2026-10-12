package org.dromara.sports.registration.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.api.StoredObjectApi;
import org.dromara.sports.registration.domain.SportsRegistrationPaymentProof;
import org.dromara.sports.registration.mapper.SportsRegistrationPaymentProofMapper;
import org.dromara.sports.registration.service.RegistrationService.ProofContext;
import org.springframework.stereotype.Service;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.HexFormat;
import java.util.List;
import java.util.Objects;

/** 上传与声明/到账完全独立；先存对象，再在报名锁内复核当前义务，避免凭证跨次报名沿用。 */
@Service
@RequiredArgsConstructor
public class PaymentProofService {
    private final RegistrationService registrations;
    private final SportsRegistrationPaymentProofMapper mapper;
    private final StoredObjectApi storage;

    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.paymentproofservice.upload",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_file","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_file","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public ProofCard upload(Long registrationId, String requestKey, byte[] body) {
        if (requestKey == null || requestKey.isBlank() || requestKey.length() > 128) {
            throw new ServiceException("请提供有效的上传请求键");
        }
        if (body == null || body.length == 0 || body.length > 5 * 1024 * 1024) {
            throw new ServiceException("请上传不超过 5MB 的 JPG、PNG 或 WebP 图片");
        }
        String digest = digest(body);
        ProofContext initial = registrations.withParticipantProof(registrationId, ctx -> { requireOpen(ctx); return ctx; });
        ProofCard existing = registrations.withParticipantProof(registrationId, ctx -> findDuplicate(ctx, requestKey, digest));
        if (existing != null) return existing;
        long fileId = storage.keepPaymentProof(initial.accountId(), initial.tenantId(), body);
        return registrations.withParticipantProof(registrationId, ctx -> {
            if (ctx.obligation() == null || !Objects.equals(initial.obligation().obligationId(), ctx.obligation().obligationId())) {
                throw new ServiceException("报名付款义务已经变化，请重新上传");
            }
            requireOpen(ctx);
            ProofCard repeated = findDuplicate(ctx, requestKey, digest);
            if (repeated != null) return repeated;
            if (mapper.selectCount(query(ctx)) >= 5) throw new ServiceException("本次报名最多上传 5 张付款凭证");
            SportsRegistrationPaymentProof row = new SportsRegistrationPaymentProof();
            row.setTenantId(ctx.tenantId()); row.setRegistrationId(registrationId);
            row.setObligationId(ctx.obligation().obligationId()); row.setUploadedByAccountId(ctx.accountId());
            row.setFileId(fileId); row.setRequestKey(requestKey); row.setContentDigest(digest);
            row.setUploadedAt(OffsetDateTime.now(ZoneOffset.ofHours(8))); row.setVersion(0);
            mapper.insert(row);
            return card(row);
        });
    }

    public List<ProofCard> list(Long registrationId, boolean organizer) {
        return organizer ? registrations.withOrganizerProof(registrationId, this::listCurrent)
            : registrations.withParticipantProof(registrationId, this::listCurrent);
    }

    public StoredObjectApi.ImageBody image(Long registrationId, Long proofId, boolean organizer) {
        return organizer ? registrations.withOrganizerProof(registrationId, ctx -> read(ctx, proofId))
            : registrations.withParticipantProof(registrationId, ctx -> read(ctx, proofId));
    }

    private StoredObjectApi.ImageBody read(ProofContext ctx, Long proofId) {
        SportsRegistrationPaymentProof row = mapper.selectById(proofId);
        if (row == null || !ctx.registrationId().equals(row.getRegistrationId())) throw new ServiceException("付款凭证不存在");
        return storage.readPaymentProof(row.getFileId(), ctx.tenantId());
    }

    private List<ProofCard> listCurrent(ProofContext ctx) {
        if (ctx.obligation() == null) return List.of();
        return mapper.selectList(query(ctx).orderByAsc(SportsRegistrationPaymentProof::getId)).stream().map(this::card).toList();
    }

    private com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<SportsRegistrationPaymentProof> query(ProofContext ctx) {
        return Wrappers.<SportsRegistrationPaymentProof>lambdaQuery()
            .eq(SportsRegistrationPaymentProof::getRegistrationId, ctx.registrationId())
            .eq(SportsRegistrationPaymentProof::getObligationId, ctx.obligation().obligationId());
    }

    private ProofCard findDuplicate(ProofContext ctx, String key, String digest) {
        if (ctx.obligation() == null) return null;
        SportsRegistrationPaymentProof row = mapper.selectOne(query(ctx)
            .eq(SportsRegistrationPaymentProof::getUploadedByAccountId, ctx.accountId())
            .eq(SportsRegistrationPaymentProof::getRequestKey, key));
        if (row == null) return null;
        if (!digest.equals(row.getContentDigest())) throw new ServiceException("相同上传请求不能更换凭证内容");
        return card(row);
    }

    private void requireOpen(ProofContext ctx) {
        if (!"submitted".equals(ctx.registrationStatus()) || !"normal".equals(ctx.holdingStatus())
            || ctx.obligation() == null || !"open".equals(ctx.obligation().status()) || ctx.obligation().amount().signum() <= 0) {
            throw new ServiceException("仅已提交且待核对付款的收费报名可以上传凭证");
        }
    }

    private ProofCard card(SportsRegistrationPaymentProof row) {
        return new ProofCard(row.getId(), row.getObligationId(), row.getFileId(), row.getUploadedAt());
    }
    private String digest(byte[] body) {
        try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(body)); }
        catch (NoSuchAlgorithmException e) { throw new IllegalStateException("SHA-256 unavailable", e); }
    }
    public record ProofCard(Long id, Long obligationId, Long fileId, OffsetDateTime uploadedAt) { }
}
