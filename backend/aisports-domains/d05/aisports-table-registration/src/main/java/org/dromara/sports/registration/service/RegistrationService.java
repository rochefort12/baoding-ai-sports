package org.dromara.sports.registration.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.core.lock.MutualLock;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.CompetitionWithdrawalApi;
import org.dromara.sports.api.EventRegistrationApi;
import org.dromara.sports.api.FeeApi;
import org.dromara.sports.api.FeeApi.ObligationView;
import org.dromara.sports.api.StoredObjectApi;
import org.dromara.sports.api.EventRegistrationApi.DeclarationNotice;
import org.dromara.sports.api.EventRegistrationApi.EventRegistrationGate;
import org.dromara.sports.api.EventRegistrationApi.ManagedEventOption;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.api.PlatformAccountApi;
import org.dromara.sports.api.InvitationNoticeApi;
import org.dromara.sports.api.PlatformAccountApi.InviteCandidate;
import org.dromara.sports.api.PlatformAccountApi.RegistrationProfile;
import org.dromara.sports.api.TeamMembershipApi;
import org.dromara.sports.registration.DeclarationAckRules;
import org.dromara.sports.registration.RegistrationRules;
import org.dromara.sports.registration.domain.SportsDeclarationAck;
import org.dromara.sports.registration.domain.SportsAuditEvent;
import org.dromara.sports.registration.domain.SportsCapacityPool;
import org.dromara.sports.registration.domain.SportsCompetitionUnit;
import org.dromara.sports.registration.domain.SportsQualificationReview;
import org.dromara.sports.registration.domain.SportsRegistration;
import org.dromara.sports.registration.domain.SportsRegistrationIdempotency;
import org.dromara.sports.registration.domain.SportsRegistrationMember;
import org.dromara.sports.registration.domain.SportsRegistrationSubmitKey;
import org.dromara.sports.registration.domain.SportsRosterMember;
import org.dromara.sports.registration.domain.SportsRosterVersion;
import org.dromara.sports.registration.domain.SportsSport;
import org.dromara.sports.registration.domain.DraftRevisionEvent;
import org.dromara.sports.registration.mapper.SportsDeclarationAckMapper;
import org.dromara.sports.registration.mapper.SportsAuditEventMapper;
import org.dromara.sports.registration.mapper.SportsCapacityPoolMapper;
import org.dromara.sports.registration.mapper.SportsCompetitionUnitMapper;
import org.dromara.sports.registration.mapper.SportsQualificationReviewMapper;
import org.dromara.sports.registration.mapper.SportsRegistrationIdempotencyMapper;
import org.dromara.sports.registration.mapper.SportsRegistrationMapper;
import org.dromara.sports.registration.mapper.SportsRegistrationMemberMapper;
import org.dromara.sports.registration.mapper.SportsRegistrationSubmitKeyMapper;
import org.dromara.sports.registration.mapper.SportsRosterMemberMapper;
import org.dromara.sports.registration.mapper.SportsRosterVersionMapper;
import org.dromara.sports.registration.mapper.SportsSportMapper;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * 报名写入赛事所属组织的租户。成员变更和提交共用竞赛单元容量锁；代表队伍先取队伍锁。
 */
@Service
@RequiredArgsConstructor
public class RegistrationService {

    private static final ZoneOffset SHANGHAI = ZoneOffset.ofHours(8);
    private static final long WAIT_MILLIS = 3000;
    private static final long LEASE_MILLIS = 30000;
    private static final String CREATE_UNIT = "create-unit";

    private final SportsSportMapper sportMapper;
    private final SportsCompetitionUnitMapper unitMapper;
    private final SportsCapacityPoolMapper poolMapper;
    private final SportsRegistrationMapper registrationMapper;
    private final SportsRegistrationMemberMapper memberMapper;
    private final SportsDeclarationAckMapper declarationAckMapper;
    private final SportsRegistrationSubmitKeyMapper submitKeyMapper;
    private final SportsRegistrationIdempotencyMapper idempotencyMapper;
    private final SportsRosterVersionMapper rosterVersionMapper;
    private final SportsRosterMemberMapper rosterMemberMapper;
    private final SportsQualificationReviewMapper reviewMapper;
    private final SportsAuditEventMapper auditEventMapper;
    private final FieldCatalogService fieldCatalogService;
    private final EventRegistrationApi eventRegistrationApi;
    private final CompetitionWithdrawalApi competitionWithdrawalApi;
    private final OrganizationSessionApi sessionApi;
    private final org.dromara.sports.api.OrganizationQualificationApi qualificationApi;
    private final PlatformAccountApi platformAccountApi;
    private final InvitationNoticeApi invitationNoticeApi;
    private final TeamMembershipApi teamMembershipApi;
    private final FeeApi feeApi;
    private final StoredObjectApi storedObjectApi;
    private final MutualLock mutualLock;
    private final ObjectMapper objectMapper;
    private final PlatformTransactionManager transactionManager;
    private final org.dromara.sports.api.CompetitionTypeApi competitionTypes;
    /** Action-private account labels: only an already authorized registration relationship is queried. */
    private final org.dromara.sports.platform.core.ScopedJdbc invitationReads;

    public List<ManagedEventOption> listManagedEvents() {
        return eventRegistrationApi.listManaged();
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.registrationservice.createunit",capability="unit.create",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public UnitCard createUnit(UnitDraft draft) {
        if (draft == null || draft.eventId() == null) {
            throw new ServiceException("请选择赛事");
        }
        if (!eventRegistrationApi.acceptsNewBusiness(draft.eventId())) {
            throw new ServiceException("赛事已进入收尾，或主办方资格已暂停，不能新增项目");
        }
        EventRegistrationGate gate = eventRegistrationApi.managedGate(draft.eventId())
            .orElseThrow(() -> new ServiceException("赛事不存在"));
        if (!"normal".equals(gate.holdingStatus())) {
            throw new ServiceException("已取消的赛事不能建立竞赛项目");
        }
        OffsetDateTime now = now();
        if (gate.endsAt() != null && !now.isBefore(gate.endsAt())) {
            throw new ServiceException("比赛已经结束，不能建立竞赛项目");
        }
        RegistrationRules.MemberBounds bounds = RegistrationRules.bounds(draft.entryType(), draft.minMembers(), draft.maxMembers());
        int limit = draft.limitCount() == null ? 0 : draft.limitCount();
        if (limit < 1) {
            throw new ServiceException("请填写至少 1 个名额");
        }
        String name = required(draft.name(), 200, "项目名称");
        String key = required(draft.requestKey(), 128, "请求键");
        PricedFee fee = pricedFee(draft);
        String hash = createHash(gate.eventId(), name, draft.entryType(), bounds.min(), bounds.max(), limit, fee);
        Long accountId = organizerAccountId();
        return transaction().execute(status -> TenantHelper.dynamic(gate.tenantId(), () -> {
            DraftRevisionEvent lockedEvent = lockManagedMutationEvent(gate);
            if (!"normal".equals(lockedEvent.getHoldingStatus())) throw new ServiceException("已取消的赛事不能建立竞赛项目");
            if (lockedEvent.getEndsAt() != null && !now().isBefore(lockedEvent.getEndsAt())) {
                throw new ServiceException("比赛已经结束，不能建立竞赛项目");
            }
            if (!eventRegistrationApi.acceptsNewBusiness(draft.eventId())) {
                throw new ServiceException("赛事已进入收尾，或主办方资格已暂停，不能新增项目");
            }
            SportsRegistrationIdempotency existing = idempotencyMapper.selectOne(Wrappers.<SportsRegistrationIdempotency>lambdaQuery()
                .eq(SportsRegistrationIdempotency::getAccountId, accountId)
                .eq(SportsRegistrationIdempotency::getOperation, CREATE_UNIT)
                .eq(SportsRegistrationIdempotency::getRequestKey, key));
            if (existing != null) {
                if (!hash.equals(existing.getPayloadHash()) || !"completed".equals(existing.getStatus())) {
                    throw new ServiceException("这个请求已经用于不同内容");
                }
                return createdUnit(existing.getResultReference());
            }
            requireUniqueUnitName(gate.eventId(), name, null);
            SportsCompetitionUnit unit = new SportsCompetitionUnit();
            unit.setTenantId(gate.tenantId());
            unit.setEventId(gate.eventId());
            unit.setSportId(badmintonId());
            unit.setCompetitionTypeId(competitionTypes.supported(unit.getSportId(),draft.entryType(),bounds.min(),bounds.max())
                .orElseThrow(() -> new ServiceException("一期开放羽毛球单打1人和双打2人，其他类型待规则验证后开放")));
            unit.setName(name);
            unit.setEntryType(draft.entryType());
            unit.setMinMembers(bounds.min());
            unit.setMaxMembers(bounds.max());
            unit.setStatus("open");
            unit.setVersion(0);
            unitMapper.insert(unit);
            SportsCapacityPool pool = new SportsCapacityPool();
            pool.setTenantId(gate.tenantId());
            pool.setEventId(gate.eventId());
            pool.setUnitId(unit.getId());
            pool.setCapacityUnit("entry");
            pool.setDedupeScope("entry");
            pool.setLimitCount(limit);
            pool.setUsedCount(0);
            pool.setStatus("active");
            pool.setVersion(0);
            poolMapper.insert(pool);
            feeApi.placeInitialPolicy(gate.tenantId(), unit.getId(), fee.amount(), fee.mode(), fee.instruction(), fee.qrFileId());
            SportsRegistrationIdempotency row = new SportsRegistrationIdempotency();
            row.setTenantId(gate.tenantId());
            row.setAccountId(accountId);
            row.setOperation(CREATE_UNIT);
            row.setRequestKey(key);
            row.setPayloadHash(hash);
            row.setStatus("completed");
            row.setResultReference("{\"unitId\":\"" + unit.getId() + "\"}");
            row.setExpiresAt(now.plusDays(30));
            row.setVersion(0);
            try {
                idempotencyMapper.insert(row);
            } catch (DataIntegrityViolationException exception) {
                throw new ServiceException("建立项目正在处理，请再提交一次");
            }
            return toUnit(unit, pool);
        }));
    }

    public List<UnitCard> listManagedUnits(Long eventId) {
        EventRegistrationGate gate = eventRegistrationApi.managedGate(eventId)
            .orElseThrow(() -> new ServiceException("赛事不存在"));
        return unitsOf(gate.eventId());
    }

    public List<UnitCard> listPublicUnits(Long eventId) {
        requireParticipant();
        EventRegistrationGate gate = visibleGate(eventId);
        if (!"normal".equals(gate.holdingStatus())) {
            throw new ServiceException("已取消的赛事不能报名");
        }
        return TenantHelper.dynamic(gate.tenantId(), () -> unitsOf(gate.eventId()));
    }

    public List<EntryCard> listMine(Long eventId) {
        Long accountId = requireParticipant();
        List<Long> captainTeams = platformAccountApi.currentRegistrationProfile()
            .map(profile -> teamMembershipApi.activeCaptainTeamIds(profile.personId()))
            .orElse(List.of());
        return TenantHelper.ignore(() -> {
            Map<Long, SportsRegistration> rows = new LinkedHashMap<>();
            for (SportsRegistration row : registrationMapper.selectList(Wrappers.<SportsRegistration>lambdaQuery()
                .and(q -> q.eq(SportsRegistration::getManagerAccountId, accountId).or().eq(SportsRegistration::getSubmitterAccountId, accountId)))) {
                rows.put(row.getId(), row);
            }
            List<SportsRegistration> ordered = new ArrayList<>(rows.values());
            ordered.sort(Comparator.comparing(SportsRegistration::getId).reversed());
            List<EntryCard> cards = new ArrayList<>();
            for (SportsRegistration row : ordered) {
                SportsCompetitionUnit unit = unitMapper.selectById(row.getUnitId());
                if (eventId != null && (unit == null || !eventId.equals(unit.getEventId()))) {
                    continue;
                }
                cards.add(toEntry(row, unit, canManage(row)));
            }
            return cards;
        });
    }

    /** 引导对话读取指定账号自己的报名。调用方必须已经从登录态得到这个账号，不能改用模型传来的编号。 */
    public String guideSnapshot(Long accountId, int offset) {
        if (accountId == null) {
            return "{\"loggedIn\":false}";
        }
        int from = Math.max(0, Math.min(offset, 10000));
        return TenantHelper.ignore(() -> {
            java.util.Map<Long, SportsRegistration> rows = new java.util.LinkedHashMap<>();
            for (SportsRegistration row : registrationMapper.selectList(Wrappers.<SportsRegistration>lambdaQuery()
                .eq(SportsRegistration::getSubmitterAccountId, accountId))) {
                rows.put(row.getId(), row);
            }
            for (SportsRegistrationMember member : memberMapper.selectList(Wrappers.<SportsRegistrationMember>lambdaQuery()
                .eq(SportsRegistrationMember::getAccountId, accountId))) {
                SportsRegistration row = registrationMapper.selectById(member.getRegistrationId());
                if (row != null) {
                    rows.putIfAbsent(row.getId(), row);
                }
            }
            java.util.List<SportsRegistration> ordered = new java.util.ArrayList<>(rows.values());
            ordered.sort(java.util.Comparator.comparing(SportsRegistration::getId).reversed());
            int pendingInvites = 0;
            for (SportsRegistrationMember member : memberMapper.selectList(Wrappers.<SportsRegistrationMember>lambdaQuery()
                .eq(SportsRegistrationMember::getAccountId, accountId)
                .eq(SportsRegistrationMember::getStatus, "pending_confirmation"))) {
                pendingInvites++;
            }
            int start = Math.min(from, ordered.size());
            int to = Math.min(start + 8, ordered.size());
            com.fasterxml.jackson.databind.node.ObjectNode root = objectMapper.createObjectNode();
            root.put("loggedIn", true);
            root.put("total", ordered.size());
            root.put("offset", from);
            root.put("limit", 8);
            root.put("hasMore", to < ordered.size());
            root.put("pendingInvites", pendingInvites);
            com.fasterxml.jackson.databind.node.ArrayNode entries = root.putArray("entries");
            for (SportsRegistration row : ordered.subList(start, to)) {
                SportsCompetitionUnit unit = unitMapper.selectById(row.getUnitId());
                EntryCard card = toEntry(row, unit, true);
                String eventName = unit == null ? "" : eventRegistrationApi.findEvent(unit.getEventId()).map(gate -> gate.name()).orElse("");
                com.fasterxml.jackson.databind.node.ObjectNode entry = entries.addObject();
                entry.put("registrationId", card.id() == null ? "" : card.id().toString());
                entry.put("eventName", eventName);
                entry.put("unitName", card.unitName() == null ? "" : card.unitName());
                entry.put("status", card.status() == null ? "" : card.status());
                entry.put("holding", card.eventHolding() == null ? "" : card.eventHolding());
                entry.put("paymentDeclared", card.paymentDeclared());
                entry.put("obligationStatus", card.obligationStatus() == null ? "" : card.obligationStatus());
                entry.put("feeAmount", card.feeAmount() == null ? "" : card.feeAmount().toPlainString());
                int confirmed = 0;
                int members = 0;
                if (card.members() != null) {
                    for (MemberCard member : card.members()) {
                        if ("declined".equals(member.status())) {
                            continue;
                        }
                        members++;
                        if ("confirmed".equals(member.status())) {
                            confirmed++;
                        }
                    }
                }
                entry.put("confirmedMembers", confirmed);
                entry.put("memberCount", members);
            }
            try {
                return objectMapper.writeValueAsString(root);
            } catch (com.fasterxml.jackson.core.JsonProcessingException exception) {
                throw new ServiceException("报名进度读取失败，请重试或打开我的参赛");
            }
        });
    }

    public List<EntryCard> listUnitEntries(Long unitId) {
        SportsCompetitionUnit unit = unitMapper.selectById(unitId);
        if (unit == null || eventRegistrationApi.managedGate(unit.getEventId()).isEmpty()) {
            throw new ServiceException("竞赛项目不存在");
        }
        List<SportsRegistration> rows = new ArrayList<>(registrationMapper.selectList(Wrappers.<SportsRegistration>lambdaQuery()
            .eq(SportsRegistration::getUnitId, unitId)
            .in(SportsRegistration::getStatus, "submitted", "approved", "rejected")));
        for (SportsRegistration draft : registrationMapper.selectList(Wrappers.<SportsRegistration>lambdaQuery()
            .eq(SportsRegistration::getUnitId, unitId)
            .eq(SportsRegistration::getStatus, "draft"))) {
            // A withdrawal returns to draft, but the organizer retains its actual submitted history.
            // Never-submitted private drafts are still excluded unless they carry a genuine funds responsibility.
            if ((draft.getRosterRevision() != null && draft.getRosterRevision() > 0) || feeApi.unsettled(draft.getTenantId(), draft.getId())) {
                rows.add(draft);
            }
        }
        rows.sort(Comparator.comparing(SportsRegistration::getSubmittedAt, Comparator.nullsLast(Comparator.reverseOrder())));
        return rows.stream().map(row -> toEntry(row, unit, false)).toList();
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.registrationservice.createdraft",capability="registration.create",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public EntryCard createDraft(Long unitId, String requestKey, Long teamId) {
        return createDraft(unitId, requestKey, teamId, null);
    }

    /** Prepare the selected roster atomically. The captain never confirms another member's participation. */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.registrationservice.createdraft",capability="registration.create",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public EntryCard createDraft(Long unitId, String requestKey, Long teamId, List<Long> memberAccountIds) {
        RegistrationProfile profile = requireProfile();
        String key = required(requestKey, 128, "请求键");
        SportsCompetitionUnit unit = openUnit(unitId);
        EventRegistrationGate gate = visibleGate(unit.getEventId());
        if (!"normal".equals(gate.holdingStatus())) {
            throw new ServiceException("已取消的赛事不能报名");
        }
        if (!RegistrationRules.beforeClose(gate.registrationClosesAt(), now())) {
            throw new ServiceException("报名已经截止");
        }
        if (teamId == null) {
            if (memberAccountIds != null) throw new ServiceException("选择队伍后才能带入队员名单");
            return transaction().execute(status -> TenantHelper.dynamic(gate.tenantId(), () -> createPersonal(profile, unit, gate, key)));
        }
        // Same lock order as submit/member changes; prevents a team transfer or concurrent roster edit midway.
        return mutualLock.execute("team:" + teamId, WAIT_MILLIS, LEASE_MILLIS,
            () -> mutualLock.execute(capacityKey(gate.tenantId(), unit.getId()), WAIT_MILLIS, LEASE_MILLIS,
                () -> transaction().execute(status -> TenantHelper.dynamic(gate.tenantId(), () ->
                    memberAccountIds == null ? createTeam(profile, unit, gate, key, teamId)
                        : prepareTeamRoster(profile, unit, gate, key, teamId, memberAccountIds)))));
    }

    private EntryCard prepareTeamRoster(RegistrationProfile profile, SportsCompetitionUnit unit,
                                        EventRegistrationGate gate, String key, Long teamId, List<Long> requested) {
        List<Long> selected = TeamRosterSelection.checked(requested, unit.getMinMembers(), unit.getMaxMembers());
        if (teamMembershipApi.findActive(teamId).isEmpty() || !teamMembershipApi.isActiveCaptain(teamId, profile.personId())) {
            throw new ServiceException("只有当前队长可以代表有效队伍报名");
        }
        String hash = TeamRosterSelection.digest(unit.getId(), teamId, selected);
        SportsRegistrationIdempotency replay = idempotencyMapper.selectOne(Wrappers.<SportsRegistrationIdempotency>lambdaQuery()
            .eq(SportsRegistrationIdempotency::getAccountId, profile.accountId())
            .eq(SportsRegistrationIdempotency::getOperation, "prepare_team_roster")
            .eq(SportsRegistrationIdempotency::getRequestKey, key));
        if (replay != null) {
            if (!hash.equals(replay.getPayloadHash()) || !"completed".equals(replay.getStatus())) {
                throw new ServiceException("这个请求已经用于另一份参赛名单");
            }
            try {
                Long id = objectMapper.readTree(replay.getResultReference()).path("registrationId").asLong();
                // Replay returns current state, never repopulates a later edited/withdrawn roster.
                SportsRegistration row = requireManageableInTenant(profile, id);
                if (!teamId.equals(row.getTeamId()) || !unit.getId().equals(row.getUnitId())) throw new ServiceException("报名请求依据不一致");
                return toEntry(row, unit, true);
            } catch (JsonProcessingException exception) { throw new ServiceException("报名请求记录无法读取"); }
        }
        if (!teamMembershipApi.containsActiveAccounts(teamId, selected)) throw new ServiceException("名单包含已离队或账号不可用的成员，请重新选择");
        EntryCard draft = createTeam(profile, unit, gate, key, teamId);
        SportsRegistration registration = requireManageableInTenant(profile, draft.id());
        requireEditable(registration);
        List<SportsRegistrationMember> current = memberMapper.selectList(Wrappers.<SportsRegistrationMember>lambdaQuery()
            .eq(SportsRegistrationMember::getRegistrationId, registration.getId()));
        if (!current.isEmpty()) {
            // A second request cannot silently overwrite an existing roster or its member confirmations.
            if (!current.stream().map(SportsRegistrationMember::getAccountId).sorted().toList().equals(selected)) {
                throw new ServiceException("这支队伍已有报名名单，请从报名详情继续核对；本次未修改名单");
            }
        } else {
            for (Long account : selected) {
                addTeammateLocked(profile, registration.getId(), account);
                if (!profile.accountId().equals(account)) notifyInvitation(registration, unit, account, false);
            }
        }
        SportsRegistrationIdempotency row = new SportsRegistrationIdempotency();
        row.setTenantId(gate.tenantId()); row.setAccountId(profile.accountId()); row.setOperation("prepare_team_roster");
        row.setRequestKey(key); row.setPayloadHash(hash); row.setStatus("completed");
        row.setResultReference("{\"registrationId\":\"" + registration.getId() + "\"}");
        row.setExpiresAt(now().plusDays(30)); row.setVersion(0); idempotencyMapper.insert(row);
        return toEntry(registration, unit, true);
    }

    private EntryCard createPersonal(RegistrationProfile profile, SportsCompetitionUnit unit, EventRegistrationGate gate, String key) {
        SportsRegistration existing = registrationMapper.selectOne(Wrappers.<SportsRegistration>lambdaQuery()
            .eq(SportsRegistration::getUnitId, unit.getId())
            .eq(SportsRegistration::getSubmitterAccountId, profile.accountId()));
        if (existing != null && existing.getTeamId() == null) {
            return toEntry(existing, unit, true);
        }
        if (existing != null) {
            throw new ServiceException("你在这个项目里已经有一条代表队伍的报名");
        }
        rejectReusedKey(profile.accountId(), key);
        SportsRegistration registration = newRegistration(profile, unit, gate, key);
        registrationMapper.insert(registration);
        SportsRegistrationMember self = new SportsRegistrationMember();
        self.setTenantId(gate.tenantId());
        self.setRegistrationId(registration.getId());
        self.setUnitId(unit.getId());
        self.setAccountId(profile.accountId());
        self.setPersonId(profile.personId());
        self.setStatus("confirmed");
        self.setSelfMember(true);
        self.setPersonSnapshot(snapshot(profile));
        self.setOccupying(false);
        self.setVersion(0);
        memberMapper.insert(self);
        return toEntry(registration, unit, true);
    }

    private EntryCard createTeam(RegistrationProfile profile, SportsCompetitionUnit unit, EventRegistrationGate gate, String key, Long teamId) {
        if (teamMembershipApi.findActive(teamId).isEmpty() || !teamMembershipApi.isActiveCaptain(teamId, profile.personId())) {
            throw new ServiceException("只有队长可以代表队伍报名");
        }
        SportsRegistration existingTeam = registrationMapper.selectOne(Wrappers.<SportsRegistration>lambdaQuery()
            .eq(SportsRegistration::getUnitId, unit.getId())
            .eq(SportsRegistration::getTeamId, teamId));
        if (existingTeam != null) {
            return toEntry(existingTeam, unit, true);
        }
        SportsRegistration existingSubmitter = registrationMapper.selectOne(Wrappers.<SportsRegistration>lambdaQuery()
            .eq(SportsRegistration::getUnitId, unit.getId())
            .eq(SportsRegistration::getSubmitterAccountId, profile.accountId()));
        if (existingSubmitter != null) {
            throw new ServiceException("你在这个项目里已经有一条报名");
        }
        rejectReusedKey(profile.accountId(), key);
        SportsRegistration registration = newRegistration(profile, unit, gate, key);
        registration.setTeamId(teamId);
        registrationMapper.insert(registration);
        return toEntry(registration, unit, true);
    }

    private SportsRegistration newRegistration(RegistrationProfile profile, SportsCompetitionUnit unit, EventRegistrationGate gate, String key) {
        SportsRegistration registration = new SportsRegistration();
        registration.setTenantId(gate.tenantId());
        registration.setUnitId(unit.getId());
        registration.setSubmitterAccountId(profile.accountId());
        registration.setManagerAccountId(profile.accountId());
        registration.setOperatorAccountId(profile.accountId());
        registration.setRequestKey(key);
        registration.setStatus("draft");
        registration.setRosterRevision(0);
        registration.setVersion(0);
        return registration;
    }

    private void rejectReusedKey(Long accountId, String key) {
        SportsRegistration sameKey = registrationMapper.selectOne(Wrappers.<SportsRegistration>lambdaQuery()
            .eq(SportsRegistration::getSubmitterAccountId, accountId)
            .eq(SportsRegistration::getRequestKey, key));
        if (sameKey != null) {
            throw new ServiceException("这个请求已经用于另一条报名");
        }
    }

    private void notifyInvitation(SportsRegistration registration, SportsCompetitionUnit unit, Long target, boolean requestSms) {
        SportsRegistrationMember member = memberMapper.selectOne(Wrappers.<SportsRegistrationMember>lambdaQuery().eq(SportsRegistrationMember::getRegistrationId, registration.getId()).eq(SportsRegistrationMember::getAccountId, target));
        if (member == null || !"pending_confirmation".equals(member.getStatus())) throw new ServiceException("邀请已变化，请刷新");
        String sender = platformAccountApi.currentRegistrationProfile().map(RegistrationProfile::legalName).orElse("报名发起人");
        String eventName = eventRegistrationApi.findEvent(unit.getEventId()).map(EventRegistrationGate::name).orElse("赛事");
        invitationNoticeApi.created("registration-invite", member.getId(), member.getVersion() == null ? 0 : member.getVersion(), target,
            "收到参赛邀请", sender + "邀请你参加“" + eventName + " · " + unit.getName() + "”，请本人查看并确认；确认后仍需正式提交报名。",
            "/portal/registration/invite/" + member.getInviteToken(), requestSms);
    }

    /** Capture the removed recipient before deleting the member; the old private invite must cease to work. */
    private void notifyRemoved(SportsRegistration registration, SportsCompetitionUnit unit, SportsRegistrationMember member, String reason) {
        if (java.util.Objects.equals(platformAccountApi.currentAccountId().orElse(null), member.getAccountId())) return;
        String eventName = eventRegistrationApi.findEvent(unit.getEventId()).map(EventRegistrationGate::name).orElse("赛事");
        invitationNoticeApi.created("registration-roster-removed", member.getId(), member.getVersion() == null ? 0 : member.getVersion(), member.getAccountId(),
            "参赛名单已调整", "你在“" + eventName + " · " + unit.getName() + "”中的本次参赛邀请已取消（" + reason + "）。原邀请链接已失效，你的其他报名不受影响。",
            "/portal/registration", false);
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.registrationservice.invite",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public EntryCard invite(Long registrationId, String phone) { return invite(registrationId, phone, false); }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.registrationservice.invite",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public EntryCard invite(Long registrationId, String phone, boolean requestSms) {
        Long accountId = requireParticipant();
        InviteCandidate candidate = platformAccountApi.findInviteCandidate(phone)
            .orElseThrow(() -> new ServiceException("这个手机号还没有注册"));
        if (accountId.equals(candidate.accountId())) {
            throw new ServiceException("不能邀请自己");
        }
        RegistrationProfile profile = requireProfile();
        SportsRegistration owned = requireManageable(profile, registrationId);
        if (owned.getTeamId() != null) {
            throw new ServiceException("代表队伍报名请从当前队员中选择");
        }
        return withEntryLock(owned, () -> inTenant(owned.getTenantId(), () -> {
            SportsRegistration registration = requireManageableInTenant(profile, registrationId);
            requireEditable(registration);
            SportsCompetitionUnit unit = openUnit(registration.getUnitId());
            SportsRegistrationMember existing = memberMapper.selectOne(Wrappers.<SportsRegistrationMember>lambdaQuery()
                .eq(SportsRegistrationMember::getRegistrationId, registration.getId())
                .eq(SportsRegistrationMember::getAccountId, candidate.accountId()));
            if (existing != null && "confirmed".equals(existing.getStatus())) {
                throw new ServiceException("对方已经在这条报名里");
            }
            if (existing != null && "pending_confirmation".equals(existing.getStatus())) {
                notifyInvitation(registration, unit, candidate.accountId(), requestSms);
                return toEntry(registration, unit, true);
            }
            long active = memberMapper.selectCount(Wrappers.<SportsRegistrationMember>lambdaQuery()
                .eq(SportsRegistrationMember::getRegistrationId, registration.getId())
                .ne(SportsRegistrationMember::getStatus, "declined"));
            if (active >= unit.getMaxMembers()) {
                throw new ServiceException("成员人数已达上限");
            }
            ensureFree(unit.getId(), candidate.accountId(), registration.getId(), "对方已经在这个项目里有一条有效报名");
            if (existing != null) {
                String token = newToken();
                int version = existing.getVersion() == null ? 0 : existing.getVersion();
                int updated = memberMapper.update(null, Wrappers.<SportsRegistrationMember>lambdaUpdate()
                    .eq(SportsRegistrationMember::getId, existing.getId())
                    .eq(SportsRegistrationMember::getVersion, version)
                    .set(SportsRegistrationMember::getStatus, "pending_confirmation")
                    .set(SportsRegistrationMember::getInviteToken, token)
                    .set(SportsRegistrationMember::getPersonId, null)
                    .set(SportsRegistrationMember::getPersonSnapshot, null)
                    .set(SportsRegistrationMember::getOccupying, false)
                    .set(SportsRegistrationMember::getVersion, version + 1));
                if (updated != 1) {
                    throw new ServiceException("邀请已被更新，请再试一次");
                }
                notifyInvitation(registration, unit, candidate.accountId(), requestSms);
                return toEntry(registration, unit, true);
            }
            SportsRegistrationMember member = new SportsRegistrationMember();
            member.setTenantId(registration.getTenantId());
            member.setRegistrationId(registration.getId());
            member.setUnitId(unit.getId());
            member.setAccountId(candidate.accountId());
            member.setStatus("pending_confirmation");
            member.setSelfMember(false);
            member.setInviteToken(newToken());
            member.setOccupying(false);
            member.setVersion(0);
            memberMapper.insert(member);
            notifyInvitation(registration, unit, candidate.accountId(), requestSms);
                return toEntry(registration, unit, true);
        }));
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.registrationservice.addteammate",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public EntryCard addTeammate(Long registrationId, Long accountId) {
        RegistrationProfile profile = requireProfile();
        SportsRegistration owned = requireManageable(profile, registrationId);
        if (owned.getTeamId() == null) {
            throw new ServiceException("这条报名不代表长期队伍");
        }
        if (!teamMembershipApi.containsActiveAccounts(owned.getTeamId(), List.of(accountId))) {
            throw new ServiceException("只能选择当前队伍成员");
        }
        return withEntryLock(owned, () -> inTenant(owned.getTenantId(), () -> {
            addTeammateLocked(profile, registrationId, accountId);
            if (!profile.accountId().equals(accountId)) notifyInvitation(owned, openUnit(owned.getUnitId()), accountId, false);
            // Delivery is projected after the transactional notice exists, avoiding a false "not created" status.
            return toEntry(registrationMapper.selectById(registrationId), openUnit(owned.getUnitId()), true);
        }));
    }

    /** Explicit recovery for older pending invitations; reading an entry never creates notifications. */
    @org.dromara.sports.platform.core.SportsAction(value="registration.invitation.remind", title="发送本人参赛站内邀请",
        reads={"asp_account","asp_person","asp_registration","asp_registration_member","asp_competition_unit","asp_capacity_pool","asp_event","asp_team","asp_team_member","asp_declaration_ack","asp_event_field","asp_org_field","asp_fee_obligation","asp_fee_policy","asp_event_payment_config","asp_payment_action","asp_payment_exception","asp_payment","asp_payment_allocation","asp_refund","asp_notification","asp_notification_delivery"},
        writes={"asp_notification","asp_notification_delivery"})
    public EntryCard remindInvitation(Long registrationId, Long memberId) {
        RegistrationProfile profile = requireProfile();
        SportsRegistration owned = requireManageable(profile, registrationId);
        return withEntryLock(owned, () -> inTenant(owned.getTenantId(), () -> {
            SportsRegistration registration = requireManageableInTenant(profile, registrationId);
            requireEditable(registration);
            SportsRegistrationMember member = memberMapper.selectById(memberId);
            if (member == null || !registration.getId().equals(member.getRegistrationId())
                || !"pending_confirmation".equals(member.getStatus()) || profile.accountId().equals(member.getAccountId()))
                throw new ServiceException("只能向本条报名的待确认成员发送邀请");
            SportsCompetitionUnit unit = openUnit(registration.getUnitId());
            notifyInvitation(registration, unit, member.getAccountId(), false);
            return toEntry(registration, unit, true);
        }));
    }

    private EntryCard addTeammateLocked(RegistrationProfile profile, Long registrationId, Long accountId) {
        SportsRegistration registration = requireManageableInTenant(profile, registrationId);
        requireEditable(registration);
        if (!teamMembershipApi.containsActiveAccounts(registration.getTeamId(), List.of(accountId))) {
            throw new ServiceException("只能选择当前队伍成员");
        }
        SportsCompetitionUnit unit = openUnit(registration.getUnitId());
        SportsRegistrationMember existing = memberMapper.selectOne(Wrappers.<SportsRegistrationMember>lambdaQuery()
            .eq(SportsRegistrationMember::getRegistrationId, registration.getId())
            .eq(SportsRegistrationMember::getAccountId, accountId));
        if (existing != null && "confirmed".equals(existing.getStatus())) {
            throw new ServiceException("对方已经在这条报名里");
        }
        if (existing != null && "pending_confirmation".equals(existing.getStatus())) {
            return toEntry(registration, unit, true);
        }
        long active = memberMapper.selectCount(Wrappers.<SportsRegistrationMember>lambdaQuery()
            .eq(SportsRegistrationMember::getRegistrationId, registration.getId())
            .ne(SportsRegistrationMember::getStatus, "declined"));
        if (active >= unit.getMaxMembers()) {
            throw new ServiceException("成员人数已达上限");
        }
        ensureFree(unit.getId(), accountId, registration.getId(), "对方已经在这个项目里有一条有效报名");
        boolean self = profile.accountId().equals(accountId);
        if (existing != null) {
            deleteMemberRevision(registration, existing);
        }
        SportsRegistrationMember member = new SportsRegistrationMember();
        member.setTenantId(registration.getTenantId());
        member.setRegistrationId(registration.getId());
        member.setUnitId(unit.getId());
        member.setAccountId(accountId);
        member.setStatus(self ? "confirmed" : "pending_confirmation");
        member.setSelfMember(self);
        member.setInviteToken(self ? null : newToken());
        member.setPersonId(self ? profile.personId() : null);
        member.setPersonSnapshot(self ? snapshot(profile) : null);
        member.setOccupying(false);
        member.setVersion(0);
        memberMapper.insert(member);
        return toEntry(registration, unit, true);
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.registrationservice.removemember",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public EntryCard removeMember(Long registrationId, Long memberId) {
        RegistrationProfile profile = requireProfile();
        SportsRegistration owned = requireManageable(profile, registrationId);
        return withEntryLock(owned, () -> inTenant(owned.getTenantId(), () -> {
            SportsRegistration registration = requireManageableInTenant(profile, registrationId);
            requireEditable(registration);
            SportsRegistrationMember member = memberMapper.selectById(memberId);
            if (member == null || !registration.getId().equals(member.getRegistrationId())) {
                throw new ServiceException("成员不存在");
            }
            if (registration.getTeamId() == null && Boolean.TRUE.equals(member.getSelfMember())) {
                throw new ServiceException("不能移除报名提交人");
            }
            SportsCompetitionUnit unit = openUnit(registration.getUnitId());
            deleteMemberRevision(registration, member);
            notifyRemoved(registration, unit, member, "报名办理人移出名单");
            return toEntry(registration, unit, true);
        }));
    }

    /**
     * 被邀请人能看到自己参与的报名。草稿阶段看得到邀请内容；提交和审核之后仍然看得到整单状态。
     */
    public List<InviteView> listReceived() {
        Long accountId = requireParticipant();
        return TenantHelper.ignore(() -> {
            List<SportsRegistrationMember> members = memberMapper.selectList(Wrappers.<SportsRegistrationMember>lambdaQuery()
                .eq(SportsRegistrationMember::getAccountId, accountId)
                .eq(SportsRegistrationMember::getSelfMember, false)
                .orderByDesc(SportsRegistrationMember::getId));
            List<InviteView> views = new ArrayList<>();
            for (SportsRegistrationMember member : members) {
                // 身份约束同时落实在查询与投影处，历史邀请也不能带出其他人的私有入口。
                if (!accountId.equals(member.getAccountId()) || Boolean.TRUE.equals(member.getSelfMember())) {
                    continue;
                }
                SportsRegistration registration = registrationMapper.selectById(member.getRegistrationId());
                if (registration == null) {
                    continue;
                }
                views.add(toInviteView(member, registration, unitMapper.selectById(member.getUnitId()), true));
            }
            return views;
        });
    }

    public InviteView inviteView(String token) {
        Long accountId = requireParticipant();
        return TenantHelper.ignore(() -> {
            SportsRegistrationMember member = memberByToken(token);
            if (!accountId.equals(member.getAccountId())) {
                throw new ServiceException("这不是你的邀请");
            }
            SportsRegistration registration = registrationMapper.selectById(member.getRegistrationId());
            if (registration == null) {
                throw new ServiceException("报名不存在");
            }
            return toInviteView(member, registration, unitMapper.selectById(member.getUnitId()));
        });
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.registrationservice.confirminvite",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public InviteView confirmInvite(String token) {
        RegistrationProfile profile = requireProfile();
        SportsRegistrationMember located = TenantHelper.ignore(() -> memberByToken(token));
        if (!profile.accountId().equals(located.getAccountId())) {
            throw new ServiceException("这不是你的邀请");
        }
        SportsRegistration owned = registrationForLock(located.getRegistrationId());
        return withEntryLock(owned, () -> inTenant(owned.getTenantId(), () -> {
            SportsRegistrationMember member = memberMapper.selectById(located.getId());
            if (member == null) {
                throw new ServiceException("邀请不存在");
            }
            SportsRegistration registration = registrationMapper.selectById(member.getRegistrationId());
            requireEditable(registration);
            if ("declined".equals(member.getStatus())) {
                throw new ServiceException("你已经拒绝这条邀请");
            }
            if (!"confirmed".equals(member.getStatus())) {
                ensureFree(member.getUnitId(), member.getAccountId(), member.getRegistrationId(), "你已经在这个项目里有一条有效报名");
                requireSelfDeclaration(member, registration.getUnitId(), profile.accountId());
                member.setStatus("confirmed");
                member.setPersonId(profile.personId());
                member.setPersonSnapshot(snapshot(profile));
                if (memberMapper.updateById(member) != 1) {
                    throw new ServiceException("邀请已被更新，请再试一次");
                }
            }
            return toInviteView(memberMapper.selectById(member.getId()), registrationMapper.selectById(registration.getId()),
                unitMapper.selectById(member.getUnitId()));
        }));
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.registrationservice.declineinvite",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public InviteView declineInvite(String token) {
        Long accountId = requireParticipant();
        SportsRegistrationMember located = TenantHelper.ignore(() -> memberByToken(token));
        if (!accountId.equals(located.getAccountId())) {
            throw new ServiceException("这不是你的邀请");
        }
        SportsRegistration owned = registrationForLock(located.getRegistrationId());
        return withEntryLock(owned, () -> inTenant(owned.getTenantId(), () -> {
            SportsRegistrationMember member = memberMapper.selectById(located.getId());
            if (member == null) {
                throw new ServiceException("邀请不存在");
            }
            SportsRegistration registration = registrationMapper.selectById(member.getRegistrationId());
            requireEditable(registration);
            if (!"declined".equals(member.getStatus())) {
                member.setStatus("declined");
                member.setOccupying(false);
                if (memberMapper.updateById(member) != 1) {
                    throw new ServiceException("邀请已被更新，请再试一次");
                }
            }
            return toInviteView(memberMapper.selectById(member.getId()), registrationMapper.selectById(registration.getId()),
                unitMapper.selectById(member.getUnitId()));
        }));
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.registrationservice.submit",capability="registration.submit",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public EntryCard submit(Long registrationId, String requestKey) {
        RegistrationProfile profile = requireProfile();
        String key = required(requestKey, 128, "请求键");
        SportsRegistration owned = requireManageable(profile, registrationId);
        return withEntryLock(owned, () -> inTenant(owned.getTenantId(), () -> submitLocked(profile, registrationId, key)));
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.registrationservice.declarepaid",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public EntryCard declarePaid(Long registrationId) {
        RegistrationProfile profile = requireProfile();
        SportsRegistration owned = requireManageable(profile, registrationId);
        return TenantHelper.dynamic(owned.getTenantId(), () -> {
            SportsRegistration registration = requireManageableInTenant(profile, registrationId);
            SportsCompetitionUnit paidUnit = unitMapper.selectById(registration.getUnitId());
            EventRegistrationGate paidGate = paidUnit == null ? null : visibleGate(paidUnit.getEventId());
            if (paidGate == null || !"normal".equals(paidGate.holdingStatus())) {
                throw new ServiceException("赛事已取消，不能再声明付款");
            }
            feeApi.declarePaid(registration.getTenantId(), registration.getId());
            return toEntry(registration, unitMapper.selectById(registration.getUnitId()), true);
        });
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.registrationservice.withdraw",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public EntryCard withdraw(Long registrationId) {
        RegistrationProfile profile = requireProfile();
        SportsRegistration owned = requireManageable(profile, registrationId);
        return mutualLock.execute(capacityKey(owned.getTenantId(), owned.getUnitId()), WAIT_MILLIS, LEASE_MILLIS,
            () -> transaction().execute(status -> TenantHelper.dynamic(owned.getTenantId(),
                () -> releaseLocked(requireManageableInTenant(profile, registrationId), "draft", profile.accountId()))));
    }

    /** 删除仅限从未正式提交的草稿；撤回后回到draft的申请仍保留名单和资金历史。 */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.registrationservice.deletedraft",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public void deleteDraft(Long registrationId) {
        RegistrationProfile profile = requireProfile();
        SportsRegistration owned = requireManageable(profile, registrationId);
        withEntryLock(owned,
            () -> transaction().execute(status -> TenantHelper.dynamic(owned.getTenantId(), () -> {
                SportsRegistration row = requireManageableInTenant(profile, registrationId);
                if (!"draft".equals(row.getStatus()) || row.getSubmittedAt() != null
                    || submitKeyMapper.exists(Wrappers.<SportsRegistrationSubmitKey>lambdaQuery().eq(SportsRegistrationSubmitKey::getRegistrationId, registrationId))
                    || rosterVersionMapper.exists(Wrappers.<SportsRosterVersion>lambdaQuery().eq(SportsRosterVersion::getRegistrationId, registrationId))
                    || feeApi.current(row.getTenantId(), registrationId).isPresent()) {
                    throw new ServiceException("仅能删除从未提交的报名草稿；已有正式报名或资金历史请保留，通过撤回或资金办理处理");
                }
                List<SportsRegistrationMember> members = membersOf(registrationId);
                if (members.stream().anyMatch(member -> Boolean.TRUE.equals(member.getOccupying())))
                    throw new ServiceException("报名仍有名额占用，不能作为草稿删除");
                List<Long> memberIds = members.stream().map(SportsRegistrationMember::getId).toList();
                SportsCompetitionUnit removedUnit = unitMapper.selectById(row.getUnitId());
                if (removedUnit == null) throw new ServiceException("报名项目不存在，请联系承办方核对");
                for (SportsRegistrationMember member : members) notifyRemoved(row, removedUnit, member, "报名办理人删除了未提交的草稿");
                if (!memberIds.isEmpty()) {
                    declarationAckMapper.delete(Wrappers.<SportsDeclarationAck>lambdaQuery().in(SportsDeclarationAck::getRegistrationMemberId, memberIds));
                }
                fieldCatalogService.deleteDraftValues(memberIds);
                memberMapper.delete(Wrappers.<SportsRegistrationMember>lambdaQuery().eq(SportsRegistrationMember::getRegistrationId, registrationId));
                int removed = registrationMapper.delete(Wrappers.<SportsRegistration>lambdaQuery()
                    .eq(SportsRegistration::getId, registrationId).eq(SportsRegistration::getStatus, "draft")
                    .eq(SportsRegistration::getVersion, row.getVersion() == null ? 0 : row.getVersion()));
                if (removed != 1) throw new ServiceException("草稿刚被更新，请刷新后再删除");
                SportsAuditEvent audit = new SportsAuditEvent();
                audit.setTenantId(row.getTenantId()); audit.setActorAccountId(profile.accountId());
                audit.setAction("delete-registration-draft"); audit.setObjectType("registration"); audit.setObjectId(registrationId);
                audit.setRequestId(UUID.randomUUID().toString()); audit.setOccurredAt(now()); audit.setVersion(0);
                audit.setSummary("{\"neverSubmitted\":true,\"memberCount\":" + members.size() + "}");
                if (auditEventMapper.insert(audit) != 1) throw new ServiceException("草稿删除记录未保存，请重试");
                // 邀请随成员行删除失效；不释放容量、不触碰付款、名单或正式提交幂等记录。
                return null;
            })));
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.registrationservice.approve",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public EntryCard approve(Long registrationId) {
        return review(registrationId, "approved", "整单通过");
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.registrationservice.reject",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public EntryCard reject(Long registrationId, String reason) {
        return review(registrationId, "rejected", required(reason, 1000, "拒绝原因"));
    }

    /**
     * 调高或调低整单名额。新上限不能低于已经占用的数量，也不自动拒绝已有报名。
     */
    /** 无正式提交历史可调整项目类型；有历史只准名称一般更正，不能改旧名单含义。 */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.registrationservice.updateunit",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public UnitCard updateUnit(Long unitId, String name, String entryType, Integer min, Integer max, boolean remove) {
        SportsCompetitionUnit unit = unitMapper.selectById(unitId);
        if (unit == null || !"open".equals(unit.getStatus())) throw new ServiceException("项目不存在");
        EventRegistrationGate gate = eventRegistrationApi.managedGate(unit.getEventId()).orElseThrow(() -> new ServiceException("无权管理项目"));
        if (!"normal".equals(gate.holdingStatus()) || (gate.endsAt() != null && !now().isBefore(gate.endsAt()))) throw new ServiceException("历史赛事不能调整项目");
        return mutualLock.execute(capacityKey(unit.getTenantId(), unitId), WAIT_MILLIS, LEASE_MILLIS,
            () -> transaction().execute(status -> TenantHelper.dynamic(gate.tenantId(), () -> {
                DraftRevisionEvent lockedEvent = lockManagedMutationEvent(gate);
                if (!"normal".equals(lockedEvent.getHoldingStatus())
                    || lockedEvent.getEndsAt() != null && !now().isBefore(lockedEvent.getEndsAt())) {
                    throw new ServiceException("历史赛事不能调整项目");
                }
                SportsCompetitionUnit current = unitMapper.selectById(unitId);
                if (current == null || !"open".equals(current.getStatus())) throw new ServiceException("项目已被更新");
                boolean history = registrationMapper.selectCount(Wrappers.<SportsRegistration>lambdaQuery().eq(SportsRegistration::getUnitId, unitId).gt(SportsRegistration::getRosterRevision, 0)) > 0;
                if (remove) {
                    if (history) throw new ServiceException("已有正式提交历史的项目不能删除");
                    current.setStatus("closed"); // 关闭无提交项目，旧草稿不可再提交；保留费用/文件引用供清理核对。
                } else {
                    String title = required(name, 200, "项目名称");
                    RegistrationRules.MemberBounds bounds = RegistrationRules.bounds(entryType, min, max);
                    if (history && (!current.getEntryType().equals(entryType) || current.getMinMembers() != bounds.min() || current.getMaxMembers() != bounds.max())) throw new ServiceException("已有正式提交，不能调整项目类型和人数");
                    requireUniqueUnitName(current.getEventId(), title, unitId);
                    current.setCompetitionTypeId(competitionTypes.supported(current.getSportId(), entryType, bounds.min(), bounds.max()).orElseThrow(() -> new ServiceException("该比赛类型人数规则尚未开放")));
                    current.setName(title); current.setEntryType(entryType); current.setMinMembers(bounds.min()); current.setMaxMembers(bounds.max());
                }
                if (unitMapper.updateById(current) != 1) throw new ServiceException("项目已更新，请刷新");
                return toUnit(current, poolOf(unitId));
            })));
    }

    private void requireUniqueUnitName(Long eventId, String name, Long except) {
        var query = Wrappers.<SportsCompetitionUnit>lambdaQuery().eq(SportsCompetitionUnit::getEventId, eventId).eq(SportsCompetitionUnit::getStatus, "open").apply("lower(btrim(name)) = lower({0})", name);
        if (except != null) query.ne(SportsCompetitionUnit::getId, except);
        if (unitMapper.selectCount(query) > 0) throw new ServiceException("本赛事已有同名项目，请使用可区分的项目名称");
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.registrationservice.adjustlimit",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public UnitCard adjustLimit(Long unitId, int limit) {
        SportsCompetitionUnit unit = unitMapper.selectById(unitId);
        if (unit == null) throw new ServiceException("竞赛项目不存在");
        EventRegistrationGate gate = eventRegistrationApi.managedGate(unit.getEventId())
            .orElseThrow(() -> new ServiceException("竞赛项目不存在"));
        return mutualLock.execute(capacityKey(unit.getTenantId(), unitId), WAIT_MILLIS, LEASE_MILLIS,
            () -> transaction().execute(status -> TenantHelper.dynamic(unit.getTenantId(), () -> {
                lockManagedMutationEvent(gate);
                SportsCapacityPool pool = poolOf(unitId);
                if (limit < 1) {
                    throw new ServiceException("名额至少为 1");
                }
                if (limit < pool.getUsedCount()) {
                    throw new ServiceException("名额不能低于已经占用的 " + pool.getUsedCount());
                }
                int previous = pool.getLimitCount() == null ? 0 : pool.getLimitCount();
                if (previous != limit) {
                    pool.setLimitCount(limit);
                    if (poolMapper.updateById(pool) != 1) {
                        throw new ServiceException("名额已被更新，请再试一次");
                    }
                    rememberLimitChange(pool, previous, limit);
                }
                return toUnit(unitMapper.selectById(unitId), poolMapper.selectById(pool.getId()));
            })));
    }

    /** 目录与名额写入口在事务内先锁赛事，与发布预览及聊天同步串行；不改变各入口原业务条件。 */
    private DraftRevisionEvent lockManagedMutationEvent(EventRegistrationGate gate) {
        DraftRevisionEvent event = unitMapper.lockDraftEvent(gate.tenantId(), gate.eventId());
        if (event == null || !java.util.Objects.equals(gate.tenantId(), event.getTenantId())
            || !java.util.Objects.equals(gate.organizationId(), event.getOrganizationId())) {
            throw new ServiceException("赛事不存在或组织归属已改变");
        }
        return event;
    }

    private EntryCard review(Long registrationId, String decision, String reason) {
        SportsRegistration located = registrationMapper.selectById(registrationId);
        if (located == null) {
            throw new ServiceException("报名不存在");
        }
        SportsCompetitionUnit unit = unitMapper.selectById(located.getUnitId());
        if (unit == null || eventRegistrationApi.managedGate(unit.getEventId()).isEmpty()) {
            throw new ServiceException("报名不存在");
        }
        return mutualLock.execute(capacityKey(located.getTenantId(), located.getUnitId()), WAIT_MILLIS, LEASE_MILLIS,
            () -> transaction().execute(status -> {
                SportsRegistration registration = registrationMapper.selectById(registrationId);
                if (registration == null || !"submitted".equals(registration.getStatus())) {
                    throw new ServiceException("只有已提交的报名可以审核");
                }
                EventRegistrationGate reviewGate = eventRegistrationApi.managedGate(unit.getEventId())
                    .orElseThrow(() -> new ServiceException("报名不存在"));
                if (!"normal".equals(reviewGate.holdingStatus())) {
                    throw new ServiceException("赛事已取消，不能再审核");
                }
                if ("approved".equals(decision)) {
                    // 页面禁用按钮不能代替服务端门禁；截止后的存量报名仍可审核，但开赛起不再授予资格。
                    if (reviewGate.startsAt() != null && !now().isBefore(reviewGate.startsAt())) {
                        throw new ServiceException("审核窗口已结束，不能新增参赛资格");
                    }
                    requireReceiptForApproval(registration);
                }
                if ("rejected".equals(decision)) {
                    releaseQuota(registration);
                }
                registration.setStatus("approved".equals(decision) ? "approved" : "rejected");
                if ("rejected".equals(decision)) {
                    feeApi.onEntryClosed(registration.getTenantId(), registration.getId());
                }
                registration.setOperatorAccountId(organizerAccountId());
                if (registrationMapper.updateById(registration) != 1) {
                    throw new ServiceException("报名已被更新，请刷新后再审核");
                }
                markRoster(registration, "approved".equals(decision));
                insertReview(registration, decision, reason);
                return toEntry(registration, unit, false);
            }));
    }

    private EntryCard submitLocked(RegistrationProfile profile, Long registrationId, String requestKey) {
        SportsRegistration registration = requireManageableInTenant(profile, registrationId);
        boolean requestConsumed = consumedHere(registration, requestKey);
        boolean storedConsumed = requestKey.equals(registration.getRequestKey())
            ? requestConsumed
            : consumedHere(registration, registration.getRequestKey());
        String action = RegistrationRules.submitAction(registration.getStatus(), registration.getRequestKey(), requestKey,
            requestConsumed, storedConsumed);
        SportsCompetitionUnit unit = openUnit(registration.getUnitId());
        if (RegistrationRules.RETURN.equals(action)) {
            return toEntry(registration, unit, true);
        }
        if (RegistrationRules.REPLACE.equals(action)) {
            SportsRegistration sameKey = registrationMapper.selectOne(Wrappers.<SportsRegistration>lambdaQuery()
                .eq(SportsRegistration::getSubmitterAccountId, registration.getSubmitterAccountId())
                .eq(SportsRegistration::getRequestKey, requestKey));
            if (sameKey != null && !sameKey.getId().equals(registration.getId())) {
                throw new ServiceException("这个请求已经用于另一条报名");
            }
            registration.setRequestKey(requestKey);
        }
        EventRegistrationGate gate = visibleGate(unit.getEventId());
        if (!"normal".equals(gate.holdingStatus())) {
            throw new ServiceException("已取消的赛事不能报名");
        }
        if (!RegistrationRules.windowOpen(gate.registrationOpensAt(), gate.registrationClosesAt(), now())) {
            throw new ServiceException("不在报名时间内");
        }
        List<SportsRegistrationMember> members = membersOf(registration.getId());
        long pending = members.stream().filter(member -> "pending_confirmation".equals(member.getStatus())).count();
        List<SportsRegistrationMember> confirmed = members.stream().filter(member -> "confirmed".equals(member.getStatus())).toList();
        if (pending > 0) {
            throw new ServiceException("还有成员未确认");
        }
        if (confirmed.size() < unit.getMinMembers() || confirmed.size() > unit.getMaxMembers()) {
            throw new ServiceException("已确认人数需要在 " + unit.getMinMembers() + " 到 " + unit.getMaxMembers() + " 之间");
        }
        requireDeclarations(unit.getEventId(), confirmed);
        for (SportsRegistrationMember member : confirmed) {
            if (member.getPersonId() == null || member.getPersonSnapshot() == null || member.getPersonSnapshot().isBlank()) {
                throw new ServiceException("成员档案未齐，不能提交");
            }
            ensureFree(unit.getId(), member.getAccountId(), registration.getId(),
                Boolean.TRUE.equals(member.getSelfMember()) ? "你已经在这个项目里有一条有效报名" : "有成员已经在这个项目里有一条有效报名");
        }
        if (registration.getTeamId() != null) {
            List<Long> personIds = confirmed.stream().map(SportsRegistrationMember::getPersonId).toList();
            if (!teamMembershipApi.containsActiveMembers(registration.getTeamId(), personIds)) {
                throw new ServiceException("当前参赛名单有人已离开长期队伍，请先处理名单");
            }
            registration.setTeamNameSnapshot(teamMembershipApi.findActive(registration.getTeamId())
                .orElseThrow(() -> new ServiceException("队伍已解散")).name());
        }
        fieldCatalogService.requireFilled(unit.getEventId(), confirmed);
        refreshOwnSnapshot(profile, confirmed);
        occupy(poolOf(unit.getId()));
        try {
            for (SportsRegistrationMember member : confirmed) {
                member.setOccupying(true);
                if (memberMapper.updateById(member) != 1) {
                    throw new ServiceException("报名已被更新，请再提交一次");
                }
            }
        } catch (DataIntegrityViolationException exception) {
            throw new ServiceException("有成员已经在这个项目里有一条有效报名");
        }
        freezeRoster(registration, confirmed, now());
        ObligationView obligation = feeApi.openOnSubmit(registration.getTenantId(), registration.getId(), unit.getId(), registration.getRosterRevision());
        registration.setFeePolicyId(obligation.feePolicyId());
        boolean autoFree = "none".equals(gate.registrationReview()) && "not_required".equals(obligation.status());
        registration.setStatus(autoFree ? "approved" : "submitted");
        registration.setSubmittedAt(now());
        registration.setOperatorAccountId(profile.accountId());
        rememberSubmitKey(registration);
        if (registrationMapper.updateById(registration) != 1) {
            throw new ServiceException("报名已被更新，请再提交一次");
        }
        eventRegistrationApi.lockRegistrationReview(gate.tenantId(), gate.eventId());
        if (autoFree) {
            markRoster(registration, true);
            insertSystemReview(registration, "approved", "无需审核，提交检查通过");
        }
        return toEntry(registration, unit, true);
    }

    private EntryCard releaseLocked(SportsRegistration registration, String nextStatus, Long operatorAccountId) {
        if ("approved".equals(registration.getStatus())) {
            ensureApprovedCanWithdraw(registration);
        } else if (!"submitted".equals(registration.getStatus())) {
            throw new ServiceException("只有已提交或仍可整单撤回的已通过报名可以撤回");
        }
        releaseQuota(registration);
        registration.setStatus(nextStatus);
        registration.setOperatorAccountId(operatorAccountId);
        if (registrationMapper.updateById(registration) != 1) {
            throw new ServiceException("报名已被更新，请再试一次");
        }
        supersedeRosters(registration.getId());
        feeApi.onEntryClosed(registration.getTenantId(), registration.getId());
        SportsCompetitionUnit unit = unitMapper.selectById(registration.getUnitId());
        return toEntry(registration, unit, true);
    }

    private void ensureApprovedCanWithdraw(SportsRegistration registration) {
        SportsCompetitionUnit unit = unitMapper.selectById(registration.getUnitId());
        if (unit == null) {
            throw new ServiceException("竞赛项目不存在");
        }
        EventRegistrationGate gate = visibleGate(unit.getEventId());
        if (!RegistrationRules.beforeClose(gate.registrationClosesAt(), now())) {
            throw new ServiceException("报名已经截止，不能撤回已通过的报名");
        }
        SportsRosterVersion version = rosterVersionMapper.selectOne(Wrappers.<SportsRosterVersion>lambdaQuery()
            .eq(SportsRosterVersion::getRegistrationId, registration.getId())
            .eq(SportsRosterVersion::getRevision, registration.getRosterRevision()));
        List<Long> people = version == null ? List.of() : rosterMemberMapper.selectList(Wrappers.<SportsRosterMember>lambdaQuery()
                .eq(SportsRosterMember::getRosterVersionId, version.getId()))
            .stream().map(SportsRosterMember::getPersonId).toList();
        if (competitionWithdrawalApi.blocksFullWithdrawal(registration.getTenantId(), unit.getEventId(), unit.getId(), registration.getId(), people)) {
            throw new ServiceException("已经报到或已有场次，不能整单撤回");
        }
    }

    private void releaseQuota(SportsRegistration registration) {
        SportsCapacityPool pool = poolOf(registration.getUnitId());
        if (pool.getUsedCount() <= 0) {
            throw new ServiceException("名额数量异常");
        }
        pool.setUsedCount(pool.getUsedCount() - 1);
        try {
            if (poolMapper.updateById(pool) != 1) {
                throw new ServiceException("名额已被更新，请再试一次");
            }
        } catch (DataIntegrityViolationException exception) {
            throw new ServiceException("名额数量异常");
        }
        for (SportsRegistrationMember member : membersOf(registration.getId())) {
            if (Boolean.TRUE.equals(member.getOccupying())) {
                member.setOccupying(false);
                memberMapper.updateById(member);
            }
        }
    }

    private void occupy(SportsCapacityPool pool) {
        if (pool.getUsedCount() >= pool.getLimitCount()) {
            throw new ServiceException("名额已满");
        }
        pool.setUsedCount(pool.getUsedCount() + 1);
        try {
            if (poolMapper.updateById(pool) != 1) {
                throw new ServiceException("名额已被更新，请再提交一次");
            }
        } catch (DataIntegrityViolationException exception) {
            throw new ServiceException("名额已满");
        }
    }

    private void refreshOwnSnapshot(RegistrationProfile profile, List<SportsRegistrationMember> confirmed) {
        for (SportsRegistrationMember member : confirmed) {
            if (!profile.accountId().equals(member.getAccountId())) {
                continue;
            }
            member.setPersonId(profile.personId());
            member.setPersonSnapshot(snapshot(profile));
            if (memberMapper.updateById(member) != 1) {
                throw new ServiceException("报名已被更新，请再提交一次");
            }
        }
    }

    private void freezeRoster(SportsRegistration registration, List<SportsRegistrationMember> confirmed, OffsetDateTime now) {
        supersedeRosters(registration.getId());
        int revision = (registration.getRosterRevision() == null ? 0 : registration.getRosterRevision()) + 1;
        SportsRosterVersion version = new SportsRosterVersion();
        version.setTenantId(registration.getTenantId());
        version.setRegistrationId(registration.getId());
        version.setRevision(revision);
        version.setStatus("effective");
        version.setEffectiveAt(now);
        version.setChangeReason(revision == 1 ? "提交报名" : "重新提交");
        version.setVersion(0);
        rosterVersionMapper.insert(version);
        int position = 1;
        for (SportsRegistrationMember member : confirmed) {
            SportsRosterMember rosterMember = new SportsRosterMember();
            rosterMember.setTenantId(registration.getTenantId());
            rosterMember.setRosterVersionId(version.getId());
            rosterMember.setPersonId(member.getPersonId());
            rosterMember.setRole("starter");
            // Keep the exact submitted person data and field answers together in this immutable roster revision.
            try {
                var submitted = (com.fasterxml.jackson.databind.node.ObjectNode) objectMapper.readTree(member.getPersonSnapshot());
                submitted.set("fields", objectMapper.valueToTree(fieldCatalogService.snapshotValues(member.getId())));
                rosterMember.setPersonSnapshot(objectMapper.writeValueAsString(submitted));
            } catch (JsonProcessingException | ClassCastException invalid) {
                throw new ServiceException("名单资料无法冻结，请重新确认本人资料");
            }
            rosterMember.setQualificationStatus("pending");
            rosterMember.setPosition(position++);
            rosterMember.setVersion(0);
            rosterMemberMapper.insert(rosterMember);
        }
        registration.setRosterRevision(revision);
    }

    private void supersedeRosters(Long registrationId) {
        List<SportsRosterVersion> versions = rosterVersionMapper.selectList(Wrappers.<SportsRosterVersion>lambdaQuery()
            .eq(SportsRosterVersion::getRegistrationId, registrationId));
        for (SportsRosterVersion version : versions) {
            if ("effective".equals(version.getStatus()) || "frozen".equals(version.getStatus())) {
                version.setStatus("superseded");
                rosterVersionMapper.updateById(version);
            }
        }
    }

    private void markRoster(SportsRegistration registration, boolean approved) {
        if (registration.getRosterRevision() == null || registration.getRosterRevision() < 1) {
            throw new ServiceException("名单尚未冻结");
        }
        SportsRosterVersion version = rosterVersionMapper.selectOne(Wrappers.<SportsRosterVersion>lambdaQuery()
            .eq(SportsRosterVersion::getRegistrationId, registration.getId())
            .eq(SportsRosterVersion::getRevision, registration.getRosterRevision()));
        if (version == null) {
            throw new ServiceException("名单尚未冻结");
        }
        version.setStatus(approved ? "frozen" : "effective");
        rosterVersionMapper.updateById(version);
        List<SportsRosterMember> members = rosterMemberMapper.selectList(Wrappers.<SportsRosterMember>lambdaQuery()
            .eq(SportsRosterMember::getRosterVersionId, version.getId()));
        for (SportsRosterMember member : members) {
            member.setQualificationStatus(approved ? "approved" : "rejected");
            rosterMemberMapper.updateById(member);
        }
    }

    /**
     * 收费且无需审核的报名，在真实到账后重验。已开赛、已取消或不再是已提交时保留到账。
     */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.registrationservice.tryautoapproveafterpayment",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public void tryAutoApproveAfterPayment(String tenantId, Long registrationId) {
        TenantHelper.dynamic(tenantId, () -> {
            SportsRegistration registration = registrationMapper.selectById(registrationId);
            if (registration == null || !"submitted".equals(registration.getStatus())) {
                return null;
            }
            SportsCompetitionUnit unit = unitMapper.selectById(registration.getUnitId());
            if (unit == null) {
                return null;
            }
            EventRegistrationGate gate = eventRegistrationApi.findEvent(unit.getEventId()).orElse(null);
            if (gate == null || !"none".equals(gate.registrationReview()) || !"normal".equals(gate.holdingStatus())) {
                return null;
            }
            if (gate.startsAt() != null && !now().isBefore(gate.startsAt())) {
                return null;
            }
            // 任意一笔到账（含不足额或重复回调）都会触发这里，不能把调用本身当成足额实收。
            requireReceiptForApproval(registration);
            registration.setStatus("approved");
            registration.setOperatorAccountId(registration.getSubmitterAccountId());
            if (registrationMapper.updateById(registration) != 1) {
                return null;
            }
            markRoster(registration, true);
            insertSystemReview(registration, "approved", "无需审核，到账后检查通过");
            return null;
        });
    }

    /**
     * 收费报名通过前必须已足额到账。声明付款不算。免费义务直接通过。
     */
    private void requireReceiptForApproval(SportsRegistration registration) {
        ObligationView obligation = feeApi.current(registration.getTenantId(), registration.getId())
            .orElseThrow(() -> new ServiceException("这条报名还没有收费记录，不能通过"));
        if ("not_required".equals(obligation.status()) || "settled".equals(obligation.status())) {
            return;
        }
        throw new ServiceException("收费报名要先确认足额到账，才能通过");
    }

    private void insertReview(SportsRegistration registration, String decision, String reason) {
        insertReview(registration, decision, reason, org.dromara.sports.platform.core.BusinessIdentity.getUserId());
    }

    private void insertSystemReview(SportsRegistration registration, String decision, String reason) {
        insertReview(registration, decision, reason, null);
    }

    private void insertReview(SportsRegistration registration, String decision, String reason, Long reviewerId) {
        SportsQualificationReview review = new SportsQualificationReview();
        review.setTenantId(registration.getTenantId());
        review.setRegistrationId(registration.getId());
        review.setDecision(decision);
        review.setBasis(basis(registration.getRosterRevision()));
        review.setReviewerId(reviewerId);
        review.setReviewedAt(now());
        review.setReason(reason);
        review.setVersion(0);
        reviewMapper.insert(review);
    }

    private String basis(Integer revision) {
        try {
            return objectMapper.writeValueAsString(Map.of("rosterRevision", revision == null ? 0 : revision));
        } catch (JsonProcessingException exception) {
            throw new ServiceException("审核依据无法保存");
        }
    }

    private SportsCapacityPool poolOf(Long unitId) {
        SportsCapacityPool pool = poolMapper.selectOne(Wrappers.<SportsCapacityPool>lambdaQuery()
            .eq(SportsCapacityPool::getUnitId, unitId)
            .eq(SportsCapacityPool::getCapacityUnit, "entry"));
        if (pool == null) {
            throw new ServiceException("这个项目还没有名额");
        }
        return pool;
    }

    private void ensureFree(Long unitId, Long accountId, Long registrationId, String message) {
        Long count = memberMapper.selectCount(Wrappers.<SportsRegistrationMember>lambdaQuery()
            .eq(SportsRegistrationMember::getUnitId, unitId)
            .eq(SportsRegistrationMember::getAccountId, accountId)
            .eq(SportsRegistrationMember::getOccupying, true)
            .ne(SportsRegistrationMember::getRegistrationId, registrationId));
        if (count != null && count > 0) {
            throw new ServiceException(message);
        }
    }

    private List<UnitCard> unitsOf(Long eventId) {
        List<SportsCompetitionUnit> units = unitMapper.selectList(Wrappers.<SportsCompetitionUnit>lambdaQuery()
            .eq(SportsCompetitionUnit::getEventId, eventId)
            .eq(SportsCompetitionUnit::getStatus, "open")
            .orderByAsc(SportsCompetitionUnit::getId));
        List<UnitCard> cards = new ArrayList<>();
        for (SportsCompetitionUnit unit : units) {
            cards.add(toUnit(unit, poolOf(unit.getId())));
        }
        return cards;
    }

    /**
     * 按主键读取竞赛单元。参赛者登录租户是技术租户，单元写在赛事组织租户里，不能按当前租户过滤。
     */
    private SportsCompetitionUnit openUnit(Long unitId) {
        SportsCompetitionUnit unit = TenantHelper.ignore(() -> unitMapper.selectById(unitId));
        if (unit == null || !"open".equals(unit.getStatus())) {
            throw new ServiceException("竞赛项目不存在");
        }
        return unit;
    }

    private EventRegistrationGate visibleGate(Long eventId) {
        return eventRegistrationApi.publicGate(eventId).orElseThrow(() -> new ServiceException("赛事不存在或未公开"));
    }

    /**
     * 个人报名看提交人。代表队伍的报名看当前队长，不看创建人。
     */
    private SportsRegistration requireManageable(RegistrationProfile profile, Long registrationId) {
        SportsRegistration registration = TenantHelper.ignore(() -> registrationMapper.selectById(registrationId));
        assertManageable(registration, profile);
        return registration;
    }

    private SportsRegistration requireManageableInTenant(RegistrationProfile profile, Long registrationId) {
        SportsRegistration registration = registrationMapper.selectById(registrationId);
        assertManageable(registration, profile);
        return registration;
    }

    private void assertManageable(SportsRegistration registration, RegistrationProfile profile) {
        if (registration == null) {
            throw new ServiceException("报名不存在");
        }
        if (registration.getManagerAccountId() != null) {
            if (profile.accountId().equals(registration.getManagerAccountId())) return;
            throw new ServiceException("报名不存在或尚未交接给你");
        }
        if (registration.getTeamId() == null) {
            if (!profile.accountId().equals(registration.getSubmitterAccountId())) {
                throw new ServiceException("报名不存在");
            }
            return;
        }
        if (teamMembershipApi.isActiveCaptain(registration.getTeamId(), profile.personId())) {
            return;
        }
        if (profile.accountId().equals(registration.getSubmitterAccountId())) {
            throw new ServiceException("只有当前队长可以代表队伍报名");
        }
        throw new ServiceException("报名不存在");
    }

    /**
     * 只在容量锁内、重新读取报名之后调用。锁外读到的草稿挡不住随后已经冻结的提交。
     */
    private void requireEditable(SportsRegistration registration) {
        if (registration == null || (!"draft".equals(registration.getStatus()) && !"rejected".equals(registration.getStatus()))) {
            throw new ServiceException("当前报名不能修改成员");
        }
    }

    private void deleteMemberRevision(SportsRegistration registration, SportsRegistrationMember member) {
        if (Boolean.TRUE.equals(member.getOccupying())) {
            throw new ServiceException("已冻结的成员不能移除");
        }
        int version = member.getVersion() == null ? 0 : member.getVersion();
        int removed = memberMapper.delete(Wrappers.<SportsRegistrationMember>lambdaQuery()
            .eq(SportsRegistrationMember::getId, member.getId())
            .eq(SportsRegistrationMember::getRegistrationId, registration.getId())
            .eq(SportsRegistrationMember::getVersion, version)
            .eq(SportsRegistrationMember::getOccupying, false));
        if (removed != 1) {
            throw new ServiceException("成员已被更新，请再试一次");
        }
    }

    private SportsRegistrationMember memberByToken(String token) {
        String value = required(token, 64, "邀请");
        SportsRegistrationMember member = memberMapper.selectOne(Wrappers.<SportsRegistrationMember>lambdaQuery()
            .eq(SportsRegistrationMember::getInviteToken, value));
        if (member == null) {
            throw new ServiceException("邀请不存在");
        }
        return member;
    }

    private List<SportsRegistrationMember> membersOf(Long registrationId) {
        return memberMapper.selectList(Wrappers.<SportsRegistrationMember>lambdaQuery()
            .eq(SportsRegistrationMember::getRegistrationId, registrationId)
            .orderByAsc(SportsRegistrationMember::getId));
    }

    private Long badmintonId() {
        SportsSport sport = sportMapper.selectOne(Wrappers.<SportsSport>lambdaQuery()
            .eq(SportsSport::getCode, "badminton")
            .eq(SportsSport::getStatus, "active"));
        if (sport == null) {
            throw new ServiceException("羽毛球目录未初始化");
        }
        return sport.getId();
    }

    private Long organizerAccountId() {
        return sessionApi.managedOrganization(org.dromara.sports.platform.core.BusinessIdentity.getUserId())
            .orElseThrow(() -> new ServiceException("当前账号不能管理这个组织的报名"))
            .accountId();
    }

    private Long requireParticipant() {
        return platformAccountApi.currentAccountId().orElseThrow(() -> new ServiceException("请使用参赛者账号登录"));
    }

    private RegistrationProfile requireProfile() {
        requireParticipant();
        return platformAccountApi.currentRegistrationProfile().orElseThrow(() -> new ServiceException("请先完善本人档案"));
    }

    private String snapshot(RegistrationProfile profile) {
        Map<String, String> body = new LinkedHashMap<>();
        body.put("legalName", profile.legalName());
        body.put("gender", profile.gender());
        body.put("birthDate", profile.birthDate().toString());
        body.put("mobile", profile.mobile());
        try {
            return objectMapper.writeValueAsString(body);
        } catch (JsonProcessingException exception) {
            throw new ServiceException("档案快照无法保存");
        }
    }

    private String legalName(String snapshot) {
        if (snapshot == null || snapshot.isBlank()) {
            return null;
        }
        try {
            JsonNode node = objectMapper.readTree(snapshot);
            JsonNode name = node.get("legalName");
            return name == null || name.isNull() ? null : name.asText();
        } catch (JsonProcessingException exception) {
            return null;
        }
    }

    private PricedFee pricedFee(UnitDraft draft) {
        boolean charged = Boolean.TRUE.equals(draft.charged());
        BigDecimal amount = charged ? draft.amount() : BigDecimal.ZERO;
        if (amount == null) {
            throw new ServiceException("请填写报名费");
        }
        amount = amount.setScale(2, RoundingMode.HALF_UP);
        String mode = charged ? draft.paymentMode() : "free";
        if (mode == null || mode.isBlank()) {
            throw new ServiceException("请选择付款方式");
        }
        if (charged && amount.signum() <= 0) {
            throw new ServiceException("请填写报名费");
        }
        if (!charged && amount.signum() != 0) {
            throw new ServiceException("免费项目的金额必须为 0");
        }
        String instruction = draft.payInstruction() == null ? "" : draft.payInstruction().trim();
        if (instruction.length() > 1000) {
            throw new ServiceException("付款说明不超过1000字");
        }
        Long qrFileId = charged && "organizer_qr".equals(mode) ? draft.qrFileId() : null;
        return new PricedFee(amount, mode, charged ? instruction : "", qrFileId);
    }

    private String createHash(Long eventId, String name, String entryType, int min, int max, int limit, PricedFee fee) {
        String body = eventId + "\n" + name + "\n" + entryType + "\n" + min + "\n" + max + "\n" + limit + "\n"
            + fee.amount().toPlainString() + "\n" + fee.mode() + "\n" + fee.instruction() + "\n" + fee.qrFileId();
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(body.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 不可用", exception);
        }
    }

    private UnitCard createdUnit(String reference) {
        if (reference == null || reference.isBlank()) {
            throw new ServiceException("原来的项目记录不完整，请换一把请求键");
        }
        try {
            JsonNode node = objectMapper.readTree(reference);
            long unitId = Long.parseLong(node.path("unitId").asText());
            SportsCompetitionUnit unit = unitMapper.selectById(unitId);
            SportsCapacityPool pool = poolMapper.selectOne(Wrappers.<SportsCapacityPool>lambdaQuery()
                .eq(SportsCapacityPool::getUnitId, unitId));
            if (unit == null || pool == null) {
                throw new ServiceException("原来的项目记录不完整，请换一把请求键");
            }
            return toUnit(unit, pool);
        } catch (JsonProcessingException | NumberFormatException exception) {
            throw new ServiceException("原来的项目记录不完整，请换一把请求键");
        }
    }

    private UnitCard toUnit(SportsCompetitionUnit unit, SportsCapacityPool pool) {
        return new UnitCard(unit.getId(), unit.getEventId(), unit.getName(), unit.getEntryType(),
            unit.getMinMembers(), unit.getMaxMembers(), pool.getLimitCount(), pool.getUsedCount());
    }

    /** 当前登录成员本人确认这一版参赛声明。队长替别人点不会写入。 */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.registrationservice.acknowledgedeclaration",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public EntryCard acknowledgeDeclaration(Long registrationId) {
        RegistrationProfile profile = requireProfile();
        SportsRegistration owned = registrationForLock(registrationId);
        return withEntryLock(owned, () -> inTenant(owned.getTenantId(), () -> {
            SportsRegistration registration = registrationMapper.selectById(registrationId);
            if (registration == null) {
                throw new ServiceException("报名不存在");
            }
            SportsRegistrationMember member = memberMapper.selectOne(Wrappers.<SportsRegistrationMember>lambdaQuery()
                .eq(SportsRegistrationMember::getRegistrationId, registrationId)
                .eq(SportsRegistrationMember::getAccountId, profile.accountId())
                .ne(SportsRegistrationMember::getStatus, "declined"));
            if (member == null) {
                throw new ServiceException("请本人确认参赛声明，队长不能代确认");
            }
            SportsCompetitionUnit unit = unitMapper.selectById(registration.getUnitId());
            DeclarationNotice notice = noticeOf(unit == null ? null : unit.getEventId());
            if (DeclarationAckRules.required(notice.confirmRequired(), notice.text(), notice.fileId())) {
                saveAck(member, unit.getEventId(), profile.accountId(), DeclarationAckRules.digest(notice.text(), notice.fileId()));
            }
            return toEntry(registration, unit, true);
        }));
    }

    private void requireDeclarations(Long eventId, List<SportsRegistrationMember> confirmed) {
        DeclarationNotice notice = noticeOf(eventId);
        if (!DeclarationAckRules.required(notice.confirmRequired(), notice.text(), notice.fileId())) {
            return;
        }
        String digest = DeclarationAckRules.digest(notice.text(), notice.fileId());
        for (SportsRegistrationMember member : confirmed) {
            if (!digest.equals(ackDigest(member.getId()))) {
                throw new ServiceException("还有成员没有本人确认参赛声明");
            }
        }
    }

    private void requireSelfDeclaration(SportsRegistrationMember member, Long unitId, Long accountId) {
        SportsCompetitionUnit unit = unitMapper.selectById(unitId);
        DeclarationNotice notice = noticeOf(unit == null ? null : unit.getEventId());
        if (!DeclarationAckRules.required(notice.confirmRequired(), notice.text(), notice.fileId())) {
            return;
        }
        if (!accountId.equals(member.getAccountId()) || !DeclarationAckRules.digest(notice.text(), notice.fileId()).equals(ackDigest(member.getId()))) {
            throw new ServiceException("请先阅读并确认参赛声明");
        }
    }

    private void saveAck(SportsRegistrationMember member, Long eventId, Long accountId, String digest) {
        SportsDeclarationAck existing = declarationAckMapper.selectOne(Wrappers.<SportsDeclarationAck>lambdaQuery()
            .eq(SportsDeclarationAck::getRegistrationMemberId, member.getId()));
        if (existing == null) {
            SportsDeclarationAck row = new SportsDeclarationAck();
            row.setTenantId(member.getTenantId());
            row.setRegistrationMemberId(member.getId());
            row.setAccountId(accountId);
            row.setEventId(eventId);
            row.setContentDigest(digest);
            row.setAcknowledgedAt(now());
            row.setVersion(0);
            declarationAckMapper.insert(row);
            return;
        }
        existing.setContentDigest(digest);
        existing.setAcknowledgedAt(now());
        existing.setAccountId(accountId);
        if (declarationAckMapper.updateById(existing) != 1) {
            throw new ServiceException("确认刚被更新，请再试一次");
        }
    }

    private String ackDigest(Long memberId) {
        SportsDeclarationAck row = declarationAckMapper.selectOne(Wrappers.<SportsDeclarationAck>lambdaQuery()
            .eq(SportsDeclarationAck::getRegistrationMemberId, memberId));
        return row == null ? "" : row.getContentDigest();
    }

    private DeclarationNotice noticeOf(Long eventId) {
        if (eventId == null) {
            return new DeclarationNotice(false, "", null);
        }
        Optional<DeclarationNotice> found = eventRegistrationApi.declaration(eventId);
        return found == null ? new DeclarationNotice(false, "", null) : found.orElse(new DeclarationNotice(false, "", null));
    }

    private boolean selfAcknowledged(Long eventId, Long accountId, List<SportsRegistrationMember> members) {
        DeclarationNotice notice = noticeOf(eventId);
        if (!DeclarationAckRules.required(notice.confirmRequired(), notice.text(), notice.fileId())) {
            return true;
        }
        String digest = DeclarationAckRules.digest(notice.text(), notice.fileId());
        return accountId != null && members.stream().anyMatch(member -> accountId.equals(member.getAccountId()) && digest.equals(ackDigest(member.getId())));
    }

    private EntryCard toEntry(SportsRegistration registration, SportsCompetitionUnit unit, boolean includeToken) {
        Long viewerAccount = platformAccountApi.currentAccountId().orElse(null);
        Map<Long, InvitationIdentity> labels = includeToken ? invitationIdentities(registration) : Map.of();
        List<MemberCard> members = membersOf(registration.getId()).stream()
            .map(member -> new MemberCard(member.getId(), member.getAccountId(), member.getStatus(),
                java.util.Objects.equals(viewerAccount, member.getAccountId()), legalName(member.getPersonSnapshot()),
                includeToken && "pending_confirmation".equals(member.getStatus()) ? member.getInviteToken() : null,
                includeToken && "pending_confirmation".equals(member.getStatus()) ? invitationNoticeApi.delivery("registration-invite", member.getId(), member.getAccountId()) : null,
                labels.containsKey(member.getAccountId()) ? labels.get(member.getAccountId()).name() : null,
                labels.containsKey(member.getAccountId()) ? labels.get(member.getAccountId()).mobileTail() : null))
            .toList();
        ObligationView fee = feeApi.current(registration.getTenantId(), registration.getId()).orElse(null);
        EventRegistrationGate shown = unit == null ? null : eventRegistrationApi.findEvent(unit.getEventId()).orElse(null);
        return new EntryCard(registration.getId(), unit == null ? null : unit.getEventId(), registration.getUnitId(),
            unit == null ? "" : unit.getName(), unit == null ? "" : unit.getEntryType(), registration.getStatus(),
            registration.getRequestKey(), registration.getRosterRevision() == null ? 0 : registration.getRosterRevision(),
            currentKeyConsumed(registration), registration.getSubmittedAt(), members, registration.getTeamId(),
            teamDisplay(registration), canManage(registration),
            fee == null ? null : fee.amount(), fee == null ? null : fee.paymentMode(),
            fee == null ? null : fee.status(), fee == null ? null : fee.payInstruction(),
            fee == null ? null : fee.obligationId(), fee != null && fee.participantDeclared(),
            fee == null ? null : fee.pendingActionId(),
            shown == null ? null : shown.holdingStatus(), shown == null ? null : shown.publicationStatus(), unit == null ? 0 : unit.getMaxMembers(),
            noticeOf(unit == null ? null : unit.getEventId()).confirmRequired(),
            noticeOf(unit == null ? null : unit.getEventId()).text(),
            noticeOf(unit == null ? null : unit.getEventId()).fileId() != null,
            selfAcknowledged(unit == null ? null : unit.getEventId(), platformAccountApi.currentAccountId().orElse(null), membersOf(registration.getId())),
            feeApi.unsettled(registration.getTenantId(), registration.getId()));
    }

    /** No account search: name and four phone digits are limited to this exact authorized registration. */
    private Map<Long, InvitationIdentity> invitationIdentities(SportsRegistration registration) {
        if (registration == null || registration.getId() == null) return Map.of();
        Map<Long, InvitationIdentity> result = new LinkedHashMap<>();
        for (Map<String, Object> row : invitationReads.list("""
            SELECT a.id AS account_id, COALESCE(NULLIF(p.legal_name,''),a.display_name) AS label,
                   CASE WHEN p.mobile ~ '^1[3-9][0-9]{9}$' THEN RIGHT(p.mobile,4) ELSE NULL END AS mobile_tail
            FROM asp_account a LEFT JOIN asp_person p ON p.id=a.person_id
            WHERE a.status='active' AND EXISTS (
                SELECT 1 FROM asp_registration r LEFT JOIN asp_registration_member m ON m.registration_id=r.id
                WHERE r.tenant_id=? AND r.id=?
                  AND (a.id=r.submitter_account_id OR a.id=r.manager_account_id OR a.id=m.account_id))
            """, registration.getTenantId(), registration.getId())) {
            if (!(row.get("account_id") instanceof Number account)) continue;
            String name = row.get("label") == null ? null : String.valueOf(row.get("label"));
            String tail = row.get("mobile_tail") == null ? null : String.valueOf(row.get("mobile_tail"));
            result.put(account.longValue(), new InvitationIdentity(name, tail != null && tail.matches("[0-9]{4}") ? tail : null));
        }
        return result;
    }

    private record InvitationIdentity(String name, String mobileTail) { }

    private void rememberLimitChange(SportsCapacityPool pool, int previous, int limit) {
        SportsAuditEvent event = new SportsAuditEvent();
        event.setActorAccountId(organizerAccountId());
        event.setAction("adjust-limit");
        event.setObjectType("capacity_pool");
        event.setObjectId(pool.getId());
        event.setRequestId(UUID.randomUUID().toString());
        event.setOccurredAt(now());
        event.setSummary("{\"from\":" + previous + ",\"to\":" + limit + "}");
        event.setVersion(0);
        auditEventMapper.insert(event);
    }

    private boolean canManage(SportsRegistration registration) {
        RegistrationProfile profile = platformAccountApi.currentRegistrationProfile().orElse(null);
        if (profile == null || registration == null) {
            return false;
        }
        if (registration.getManagerAccountId() != null) return profile.accountId().equals(registration.getManagerAccountId());
        if (registration.getTeamId() == null) {
            return profile.accountId().equals(registration.getSubmitterAccountId());
        }
        return teamMembershipApi.isActiveCaptain(registration.getTeamId(), profile.personId());
    }

    private String teamDisplay(SportsRegistration registration) {
        if (registration.getTeamId() == null) {
            return null;
        }
        if ("submitted".equals(registration.getStatus()) || "approved".equals(registration.getStatus())) {
            return registration.getTeamNameSnapshot();
        }
        return teamMembershipApi.findActive(registration.getTeamId()).map(TeamMembershipApi.ActiveTeam::name).orElse("队伍已解散");
    }

    private TransactionTemplate transaction() {
        TransactionTemplate template = new TransactionTemplate(transactionManager);
        template.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRED);
        return template;
    }

    /**
     * 代表队伍先取 {@code team:{teamId}}，再取 {@code capacity:{tenantId}:{unitId}}，顺序与提交一致。
     * 名额调整使用同一把容量锁。
     */
    private <T> T withEntryLock(SportsRegistration located, java.util.function.Supplier<T> action) {
        java.util.function.Supplier<T> capacity = () -> mutualLock.execute(
            capacityKey(located.getTenantId(), located.getUnitId()), WAIT_MILLIS, LEASE_MILLIS, action);
        if (located.getTeamId() == null) {
            return capacity.get();
        }
        return mutualLock.execute("team:" + located.getTeamId(), WAIT_MILLIS, LEASE_MILLIS, capacity);
    }

    private <T> T inTenant(String tenantId, java.util.function.Supplier<T> action) {
        return transaction().execute(status -> TenantHelper.dynamic(tenantId, action));
    }

    private SportsRegistration registrationForLock(Long registrationId) {
        SportsRegistration registration = TenantHelper.ignore(() -> registrationMapper.selectById(registrationId));
        if (registration == null) {
            throw new ServiceException("报名不存在");
        }
        return registration;
    }

    private boolean consumedHere(SportsRegistration registration, String requestKey) {
        SportsRegistrationSubmitKey row = findSubmitKey(registration.getSubmitterAccountId(), requestKey);
        if (row == null) {
            return false;
        }
        if (!registration.getId().equals(row.getRegistrationId())) {
            throw new ServiceException("这个请求已经用于另一条报名");
        }
        return true;
    }

    private boolean currentKeyConsumed(SportsRegistration registration) {
        if (registration.getTenantId() == null || registration.getRequestKey() == null) {
            return false;
        }
        return Boolean.TRUE.equals(TenantHelper.dynamic(registration.getTenantId(), () -> {
            SportsRegistrationSubmitKey row = findSubmitKey(registration.getSubmitterAccountId(), registration.getRequestKey());
            return row != null && registration.getId().equals(row.getRegistrationId());
        }));
    }

    private SportsRegistrationSubmitKey findSubmitKey(Long submitterAccountId, String requestKey) {
        return submitKeyMapper.selectOne(Wrappers.<SportsRegistrationSubmitKey>lambdaQuery()
            .eq(SportsRegistrationSubmitKey::getSubmitterAccountId, submitterAccountId)
            .eq(SportsRegistrationSubmitKey::getRequestKey, requestKey));
    }

    private void rememberSubmitKey(SportsRegistration registration) {
        SportsRegistrationSubmitKey row = new SportsRegistrationSubmitKey();
        row.setTenantId(registration.getTenantId());
        row.setRegistrationId(registration.getId());
        row.setSubmitterAccountId(registration.getSubmitterAccountId());
        row.setRequestKey(registration.getRequestKey());
        row.setRosterRevision(registration.getRosterRevision());
        row.setVersion(0);
        submitKeyMapper.insert(row);
    }

    private String capacityKey(String tenantId, Long unitId) {
        return "capacity:" + tenantId + ":" + unitId;
    }

    private String newToken() {
        return UUID.randomUUID().toString().replace("-", "");
    }

    private OffsetDateTime now() {
        return OffsetDateTime.now(SHANGHAI);
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

    public StoredObjectApi.ImageBody paymentQr(Long registrationId) {
        SportsRegistration registration = requireManageable(requireProfile(), registrationId);
        Long fileId = feeApi.paymentInstructions(registration.getTenantId(), registrationId).channels().stream()
            .map(org.dromara.sports.api.FeeApi.PaymentChannel::qrFileId).filter(java.util.Objects::nonNull).findFirst().orElse(null);
        if (fileId == null) {
            throw new ServiceException("这场没有收款码");
        }
        return storedObjectApi.readOwned(fileId, registration.getTenantId());
    }

    /** 声明只按报名绑定读取；有效本人邀请也可阅读，不凭文件编号扩大访问范围。 */
    public StoredObjectApi.ImageBody declarationImage(Long registrationId) {
        Long accountId = requireParticipant();
        return TenantHelper.ignore(() -> {
            SportsRegistration registration = registrationMapper.selectById(registrationId);
            if (registration == null) throw new ServiceException("报名不存在或不能查看声明");
            SportsRegistrationMember member = memberMapper.selectOne(Wrappers.<SportsRegistrationMember>lambdaQuery()
                .eq(SportsRegistrationMember::getRegistrationId, registrationId)
                .eq(SportsRegistrationMember::getAccountId, accountId));
            boolean validMember = member != null && accountId.equals(member.getAccountId())
                && registrationId.equals(member.getRegistrationId())
                && ("confirmed".equals(member.getStatus()) || ("pending_confirmation".equals(member.getStatus())
                    && ("draft".equals(registration.getStatus()) || "rejected".equals(registration.getStatus()))));
            if (!accountId.equals(registration.getManagerAccountId()) && !validMember)
                throw new ServiceException("报名不存在或不能查看声明");
            SportsCompetitionUnit unit = unitMapper.selectById(registration.getUnitId());
            DeclarationNotice notice = noticeOf(unit == null ? null : unit.getEventId());
            if (notice.fileId() == null) throw new ServiceException("这场赛事没有图片声明");
            // 同时核验组织及用途，组织里其它私有图片不会被当作声明返回。
            storedObjectApi.requireImage(notice.fileId(), StoredObjectApi.EVENT_DECLARATION, registration.getTenantId());
            return storedObjectApi.readOwned(notice.fileId(), registration.getTenantId());
        });
    }

    public org.dromara.sports.api.FeeApi.PaymentSettings paymentInstructions(Long registrationId) {
        SportsRegistration registration = requireManageable(requireProfile(), registrationId);
        return feeApi.paymentInstructions(registration.getTenantId(), registrationId);
    }

    public StoredObjectApi.ImageBody paymentChannelQr(Long registrationId, String channelType) {
        SportsRegistration registration = requireManageable(requireProfile(), registrationId);
        Long fileId = feeApi.paymentInstructions(registration.getTenantId(), registrationId).channels().stream()
            .filter(channel -> channel.type().equals(channelType)).map(org.dromara.sports.api.FeeApi.PaymentChannel::qrFileId)
            .filter(java.util.Objects::nonNull).findFirst().orElseThrow(() -> new ServiceException("这个收款渠道没有二维码"));
        return storedObjectApi.readOwned(fileId, registration.getTenantId());
    }

    /** 凭证沿用报名管理人及容量/队伍锁，防止撤回重提交后挂到另一付款义务。 */
    public <T> T withParticipantProof(Long registrationId, java.util.function.Function<ProofContext, T> action) {
        RegistrationProfile profile = requireProfile();
        SportsRegistration owned = requireManageable(profile, registrationId);
        return withEntryLock(owned, () -> inTenant(owned.getTenantId(), () -> {
            SportsRegistration current = requireManageableInTenant(profile, registrationId);
            return action.apply(proofContext(current, profile.accountId()));
        }));
    }

    /** 只向本组织有 payment 动作的人开放财务材料，通用办赛权限不足以读取凭证。 */
    public <T> T withOrganizerProof(Long registrationId, java.util.function.Function<ProofContext, T> action) {
        if (org.dromara.sports.platform.core.BusinessIdentity.getUserType() == org.dromara.common.core.enums.UserType.PLATFORM_USER) {
            throw new ServiceException("请先进入办赛组织");
        }
        var organization = sessionApi.managedOrganization(org.dromara.sports.platform.core.BusinessIdentity.getUserId())
            .orElseThrow(() -> new ServiceException("当前账号不能查看付款凭证"));
        if (!organization.tenantId().equals(org.dromara.sports.platform.core.BusinessIdentity.getTenantId()) || !qualificationApi.hasStaffAction(
            organization.tenantId(), organization.organizationId(), organization.accountId(), "payment")) {
            throw new ServiceException("当前账号不能查看付款凭证");
        }
        return inTenant(organization.tenantId(), () -> {
            SportsRegistration row = registrationMapper.selectById(registrationId);
            if (row == null) throw new ServiceException("报名不存在");
            SportsCompetitionUnit unit = unitMapper.selectById(row.getUnitId());
            if (unit == null || eventRegistrationApi.managedGate(unit.getEventId()).isEmpty()) {
                throw new ServiceException("报名不存在");
            }
            return action.apply(proofContext(row, organization.accountId()));
        });
    }

    private ProofContext proofContext(SportsRegistration row, Long accountId) {
        var obligation = feeApi.current(row.getTenantId(), row.getId()).orElse(null);
        return new ProofContext(row.getTenantId(), row.getId(), accountId, row.getStatus(), obligation,
            eventRegistrationApi.publicGate(unitMapper.selectById(row.getUnitId()).getEventId())
                .map(EventRegistrationGate::holdingStatus).orElse("unavailable"));
    }

    public record ProofContext(String tenantId, Long registrationId, Long accountId, String registrationStatus,
                               ObligationView obligation, String holdingStatus) { }

    public record UnitDraft(Long eventId, String name, String entryType, Integer minMembers, Integer maxMembers, Integer limitCount,
                            String requestKey, Boolean charged, BigDecimal amount, String paymentMode, String payInstruction, Long qrFileId) {
    }

    private record PricedFee(BigDecimal amount, String mode, String instruction, Long qrFileId) {
    }

    public record UnitCard(Long id, Long eventId, String name, String entryType, int minMembers, int maxMembers,
                           int limitCount, int usedCount) {
    }

    public record MemberCard(Long id, Long accountId, String status, boolean selfMember, String legalName, String inviteToken, InvitationNoticeApi.Status notice,
                             String invitationName, String mobileTail) {
    }

    public record SubmittedField(String label, String value) { }
    public record SubmittedMember(Long id, String legalName, String gender, String birthDate, String mobile,
                                  boolean fieldsCaptured, List<SubmittedField> fields) { }

    /** Only the event's authorized organizer can read submitted contact/qualification data. Never project it into teammate/public cards. */
    public List<SubmittedMember> submittedRoster(Long registrationId) {
        SportsRegistration registration = registrationMapper.selectById(registrationId);
        SportsCompetitionUnit unit = registration == null ? null : unitMapper.selectById(registration.getUnitId());
        if (unit == null || eventRegistrationApi.managedGate(unit.getEventId()).isEmpty()) throw new ServiceException("报名不存在");
        if (registration.getRosterRevision() == null || registration.getRosterRevision() < 1) throw new ServiceException("报名尚未正式提交");
        SportsRosterVersion version = rosterVersionMapper.selectOne(Wrappers.<SportsRosterVersion>lambdaQuery()
            .eq(SportsRosterVersion::getRegistrationId, registrationId).eq(SportsRosterVersion::getRevision, registration.getRosterRevision()));
        if (version == null) throw new ServiceException("提交名单快照缺失，请联系承办方核对");
        return rosterMemberMapper.selectList(Wrappers.<SportsRosterMember>lambdaQuery()
            .eq(SportsRosterMember::getRosterVersionId, version.getId()).orderByAsc(SportsRosterMember::getPosition))
            .stream().map(member -> {
                try {
                    JsonNode data = objectMapper.readTree(member.getPersonSnapshot());
                    List<SubmittedField> fields = new ArrayList<>();
                    if (data.path("fields").isArray()) for (JsonNode field : data.path("fields"))
                        fields.add(new SubmittedField(field.path("label").asText("采集项"), field.path("value").asText("")));
                    return new SubmittedMember(member.getId(), data.path("legalName").asText(""), data.path("gender").asText(""),
                        data.path("birthDate").asText(""), data.path("mobile").asText(""), data.path("fields").isArray(), fields);
                } catch (JsonProcessingException invalid) { throw new ServiceException("提交名单快照无法读取，请联系承办方核对"); }
            }).toList();
    }

    public record EntryCard(Long id, Long eventId, Long unitId, String unitName, String entryType, String status,
                            String requestKey, int rosterRevision, boolean requestKeyConsumed, OffsetDateTime submittedAt, List<MemberCard> members, Long teamId,
                            String teamName, boolean canManage, BigDecimal feeAmount, String paymentMode,
                            String obligationStatus, String payInstruction, Long obligationId, boolean paymentDeclared,
                            Long pendingActionId, String eventHolding, String eventPublication, int maxMembers,
                            boolean declarationConfirmRequired, String declarationText, boolean declarationImageAvailable, boolean declarationAcknowledged, boolean fundsPending) {
    }

    private InviteView toInviteView(SportsRegistrationMember member, SportsRegistration registration, SportsCompetitionUnit unit) {
        return toInviteView(member, registration, unit, false);
    }

    /** 仅本人收到的邀请列表附重新打开链接；令牌不是授权，详情仍每次核验登录人。 */
    private InviteView toInviteView(SportsRegistrationMember member, SportsRegistration registration, SportsCompetitionUnit unit, boolean ownListLink) {
        Long eventId = unit == null ? null : unit.getEventId();
        String eventName = "赛事";
        if (eventId != null) {
            eventName = eventRegistrationApi.findEvent(eventId).map(EventRegistrationGate::name).orElse(eventName);
        }
        String registrationStatus = registration == null ? "" : registration.getStatus();
        boolean waitingSubmit = "draft".equals(registrationStatus) || "rejected".equals(registrationStatus);
        boolean canRespond = waitingSubmit && member != null && "pending_confirmation".equals(member.getStatus());
        DeclarationNotice notice = noticeOf(eventId);
        boolean acked = member != null && DeclarationAckRules.digest(notice.text(), notice.fileId()).equals(ackDigest(member.getId()));
        Map<Long, InvitationIdentity> labels = invitationIdentities(registration);
        InvitationIdentity receiver = member == null ? null : labels.get(member.getAccountId());
        InvitationIdentity sender = registration == null ? null : labels.get(registration.getSubmitterAccountId());
        return new InviteView(registration == null ? null : registration.getId(), eventId, eventName,
            unit == null ? "" : unit.getName(), unit == null ? "" : unit.getEntryType(), registrationStatus,
            member == null ? "" : member.getStatus(), canRespond,
            member != null && "confirmed".equals(member.getStatus()) && registration != null ? membersOf(registration.getId()).stream().filter(m -> !"declined".equals(m.getStatus())).map(m -> new InviteMember(legalName(m.getPersonSnapshot()), m.getStatus(), member.getAccountId().equals(m.getAccountId()))).toList() : List.of(),
            DeclarationAckRules.required(notice.confirmRequired(), notice.text(), notice.fileId()), notice.text(), notice.fileId() != null, acked,
            ownListLink && member != null && member.getInviteToken() != null && !member.getInviteToken().isBlank() ? member.getInviteToken() : null,
            receiver == null ? null : receiver.name(), receiver == null ? null : receiver.mobileTail(), sender == null ? null : sender.name());
    }

    public record InviteMember(String legalName, String status, boolean selfMember) { }

    public record InviteView(Long registrationId, Long eventId, String eventName, String unitName, String entryType,
                             String registrationStatus, String memberStatus, boolean canRespond, List<InviteMember> members,
                             boolean declarationConfirmRequired, String declarationText, boolean declarationImageAvailable, boolean declarationAcknowledged,
                             String inviteToken, String inviteeName, String inviteeMobileTail, String initiatorName) {
    }
}
