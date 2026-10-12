package org.dromara.sports.competition.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.core.lock.MutualLock;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.OrganizationQualificationApi;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.api.OrganizationSessionApi.ManagedOrganization;
import org.dromara.sports.api.PlatformAccountApi;
import org.dromara.sports.api.PlatformAccountApi.MemberLabel;
import org.dromara.sports.api.PlatformAccountApi.RegistrationProfile;
import org.dromara.sports.api.RegistrationRosterApi;
import org.dromara.sports.api.RegistrationRosterApi.RosterPerson;
import org.dromara.sports.api.RegistrationRosterApi.RosterView;
import org.dromara.sports.competition.CompetitionRules;
import org.dromara.sports.competition.domain.CompetitionCheckin;
import org.dromara.sports.competition.domain.CompetitionEvent;
import org.dromara.sports.competition.domain.CompetitionHonor;
import org.dromara.sports.competition.domain.CompetitionMatch;
import org.dromara.sports.competition.domain.CompetitionMatchEntry;
import org.dromara.sports.competition.domain.CompetitionResult;
import org.dromara.sports.competition.domain.CompetitionResultItem;
import org.dromara.sports.competition.domain.CompetitionStage;
import org.dromara.sports.competition.domain.CompetitionUnit;
import org.dromara.sports.competition.domain.ExecutionCommand;
import org.dromara.sports.competition.mapper.CompetitionCheckinMapper;
import org.dromara.sports.competition.mapper.CompetitionEventMapper;
import org.dromara.sports.competition.mapper.CompetitionHonorMapper;
import org.dromara.sports.competition.mapper.CompetitionMatchEntryMapper;
import org.dromara.sports.competition.mapper.CompetitionMatchMapper;
import org.dromara.sports.competition.mapper.CompetitionResultItemMapper;
import org.dromara.sports.competition.mapper.CompetitionResultMapper;
import org.dromara.sports.competition.mapper.CompetitionStageMapper;
import org.dromara.sports.competition.mapper.CompetitionUnitMapper;
import org.dromara.sports.competition.mapper.ExecutionCommandMapper;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Supplier;

/**
 * 报到、手工场次、录分和获奖证明。新增报到与场次同时核对当前资金资格，不抽签。
 */
@Service
@RequiredArgsConstructor
public class CompetitionService {

    static final String SYSTEM_STAGE = "SYSTEM_MANUAL";
    private static final ZoneOffset SHANGHAI = ZoneOffset.ofHours(8);
    private static final DateTimeFormatter CLOCK = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");
    private static final long WAIT_MILLIS = 3000;
    private static final long LEASE_MILLIS = 30000;

    private final CompetitionEventMapper eventMapper;
    private final CompetitionUnitMapper unitMapper;
    private final CompetitionStageMapper stageMapper;
    private final CompetitionMatchMapper matchMapper;
    private final CompetitionMatchEntryMapper matchEntryMapper;
    private final CompetitionCheckinMapper checkinMapper;
    private final CompetitionResultMapper resultMapper;
    private final CompetitionResultItemMapper resultItemMapper;
    private final CompetitionHonorMapper honorMapper;
    private final ExecutionCommandMapper commandMapper;
    private final RegistrationRosterApi rosterApi;
    private final org.dromara.sports.api.FeeApi feeApi;
    private final PlatformAccountApi accountApi;
    private final OrganizationSessionApi sessionApi;
    private final OrganizationQualificationApi qualificationApi;
    private final MutualLock mutualLock;
    private final ObjectMapper objectMapper;
    private final PlatformTransactionManager transactionManager;
    private final org.dromara.sports.api.GrowthFactApi growthFacts;
    private final org.dromara.sports.platform.core.ScopedJdbc db;

    public List<EventChoice> events() {
        ManagedOrganization organization = requireOrganizer();
        return TenantHelper.dynamic(organization.tenantId(), () -> eventMapper.selectList(Wrappers.<CompetitionEvent>lambdaQuery()
                .eq(CompetitionEvent::getOrganizationId, organization.organizationId())
                .orderByDesc(CompetitionEvent::getId))
            .stream().map(event -> new EventChoice(event.getId(), event.getName())).toList());
    }

    public List<UnitChoice> units(Long eventId) {
        ManagedOrganization organization = requireOrganizer();
        return TenantHelper.dynamic(organization.tenantId(), () -> {
            requireEvent(organization, eventId);
            return unitMapper.selectList(Wrappers.<CompetitionUnit>lambdaQuery().eq(CompetitionUnit::getEventId, eventId)
                    .orderByAsc(CompetitionUnit::getId))
                .stream().map(unit -> new UnitChoice(unit.getId(), unit.getName())).toList();
        });
    }

    public List<EligiblePerson> eligible(Long eventId) {
        ManagedOrganization organization = requireOrganizer();
        return TenantHelper.dynamic(organization.tenantId(), () -> {
            requireEvent(organization, eventId);
            List<CompetitionCheckin> checked = confirmedCheckins(eventId);
            List<EligiblePerson> people = new ArrayList<>();
            for (RosterView roster : rosterApi.approvedRosters(organization.tenantId(), eventId)) {
                var obligation = feeApi.current(organization.tenantId(), roster.registrationId()).orElse(null);
                if (obligation == null || !("not_required".equals(obligation.status()) || "settled".equals(obligation.status()))) continue;
                for (RosterPerson person : roster.people()) {
                    people.add(new EligiblePerson(person.personId(), person.legalName(), roster.unitName(),
                        roster.registrationId(), checked.stream().anyMatch(c -> person.personId().equals(c.getPersonId()) && roster.unitId().equals(c.getUnitId())),
                        roster.unitId(), checked.stream().anyMatch(c -> person.personId().equals(c.getPersonId()) && c.getUnitId() == null)));
                }
            }
            return people;
        });
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.competition.competitionservice.checkin",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public CheckInCard checkIn(Long eventId, Long personId, String requestKey) {
        return checkIn(eventId, null, personId, requestKey);
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.competition.competitionservice.checkin",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public CheckInCard checkIn(Long eventId, Long unitId, Long personId, String requestKey) {
        ManagedOrganization organization = requireOrganizer();
        String key = required(requestKey, 128, "请求键");
        return TenantHelper.dynamic(organization.tenantId(), () -> {
            requireRunnable(organization, eventId);
            requireNotEnded(eventId);
            Long selectedUnit = attendanceUnit(organization, eventId, unitId, personId);
            String payload = eventId + ":" + selectedUnit + ":" + personId;
            return locked("checkin:" + organization.tenantId() + ":" + eventId + ":" + selectedUnit + ":" + personId, () -> {
                requireRunnable(organization, eventId);
                requireNotEnded(eventId);
                Long prior = replay("checkin", key, payload);
                if (prior != null) return checkInCard(loadCheckin(prior));
                requireAttendanceFunds(organization.tenantId(), eventId, selectedUnit, personId);
                CompetitionCheckin existing = confirmedCheckin(eventId, selectedUnit, personId);
                if (existing == null) {
                    existing = new CompetitionCheckin();
                    existing.setEventId(eventId);
                    existing.setUnitId(selectedUnit);
                    existing.setPersonId(personId);
                    existing.setCheckType("unit");
                    existing.setStatus("confirmed");
                    existing.setVerification("{\"personId\":" + personId + ",\"unitId\":" + selectedUnit + "}");
                    existing.setOccurredAt(now());
                    existing.setRequestKey(key);
                    existing.setVersion(0);
                    checkinMapper.insert(existing);
                }
                store("checkin", key, payload, "checkin", existing.getId());
                growthFacts.reconcileEvent(eventId);
                return checkInCard(existing);
            });
        });
    }

    public List<EntryChoice> entries(Long unitId) {
        ManagedOrganization organization = requireOrganizer();
        CompetitionUnit unit = requireUnit(organization, unitId);
        return rosterApi.approvedRostersForUnit(organization.tenantId(), unit.getId()).stream()
            .map(roster -> new EntryChoice(roster.registrationId(), label(roster))).toList();
    }

    public List<MatchCard> matches(Long unitId) {
        ManagedOrganization organization = requireOrganizer();
        return TenantHelper.dynamic(organization.tenantId(), () -> {
            requireUnit(organization, unitId);
            CompetitionStage stage = systemStage(unitId);
            if (stage == null) {
                return List.of();
            }
            return matchMapper.selectList(Wrappers.<CompetitionMatch>lambdaQuery()
                    .eq(CompetitionMatch::getStageId, stage.getId())
                    .orderByAsc(CompetitionMatch::getId))
                .stream().map(this::matchCard).toList();
        });
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.competition.competitionservice.creatematch",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public MatchCard createMatch(Long unitId, String code, Long registrationA, Long registrationB, String requestKey) {
        ManagedOrganization organization = requireOrganizer();
        String matchCode = required(code, 100, "场次编号");
        String key = required(requestKey, 128, "请求键");
        if (registrationA == null || registrationB == null || registrationA.equals(registrationB)) {
            throw new ServiceException("请选择两侧不同的报名");
        }
        String payload = unitId + "\n" + matchCode + "\n" + registrationA + "\n" + registrationB;
        return TenantHelper.dynamic(organization.tenantId(), () -> locked("match-create:" + organization.tenantId() + ":" + unitId + ":" + matchCode, () -> {
            CompetitionUnit creating = requireUnit(organization, unitId);
            requireRunnable(organization, creating.getEventId());
            requireNotEnded(creating.getEventId());
            Long prior = replay("match", key, payload);
            if (prior != null) {
                return matchCard(loadMatch(prior));
            }
            // Always acquire two payment locks in one order; opponents may be entered in either order.
            java.util.stream.Stream.of(registrationA, registrationB).sorted()
                .forEach(id -> feeApi.requireParticipationReady(organization.tenantId(), id));
            RosterView sideA = requireEntry(organization.tenantId(), unitId, registrationA);
            RosterView sideB = requireEntry(organization.tenantId(), unitId, registrationB);
            CompetitionStage stage = ensureStage(unitId);
            CompetitionMatch duplicated = matchMapper.selectOne(Wrappers.<CompetitionMatch>lambdaQuery()
                .eq(CompetitionMatch::getStageId, stage.getId())
                .eq(CompetitionMatch::getCode, matchCode));
            if (duplicated != null) {
                throw new ServiceException("场次编号已存在");
            }
            CompetitionMatch match = new CompetitionMatch();
            match.setStageId(stage.getId());
            match.setCode(matchCode);
            match.setRoundNumber(1);
            match.setStatus("published");
            match.setVersion(0);
            matchMapper.insert(match);
            insertSide(match.getId(), "A", sideA);
            insertSide(match.getId(), "B", sideB);
            store("match", key, payload, "match", match.getId());
            return matchCard(match);
        }));
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.competition.competitionservice.saveresult",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public ResultCard saveResult(Long matchId, String summary, String games, String outcomeA, String outcomeB, String requestKey) {
        ManagedOrganization organization = requireOrganizer();
        String key = required(requestKey, 128, "请求键");
        CompetitionRules.requireComplementary(outcomeA, outcomeB);
        String canonical = canonical(summary, games, outcome(outcomeA), outcome(outcomeB));
        String payload = matchId + "\n" + canonical;
        return TenantHelper.dynamic(organization.tenantId(), () -> locked("result:" + matchId, () -> {
            CompetitionMatch match = requireMatch(organization, matchId);
            requireMatchRunnable(organization, match);
            Long prior = replay("result", key, payload);
            if (prior != null) {
                return replayedResult(prior, match);
            }
            CompetitionResult result = writeResult(match, canonical, summary, games, outcome(outcomeA), outcome(outcomeB), false);
            store("result", key, payload, "result", result.getId());
            return resultCard(result, match);
        }));
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.competition.competitionservice.finalizeresult",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public ResultCard finalizeResult(Long matchId, String requestKey) {
        ManagedOrganization organization = requireOrganizer();
        String key = required(requestKey, 128, "请求键");
        String payload = "finalize:" + matchId;
        return TenantHelper.dynamic(organization.tenantId(), () -> locked("result:" + matchId, () -> {
            CompetitionMatch match = requireMatch(organization, matchId);
            CompetitionStage phase = stageMapper.selectById(match.getStageId());
            CompetitionUnit project = unitMapper.selectById(phase.getUnitId());
            db.lock("event-fixtures:" + project.getEventId());
            requireMatchRunnable(organization, match);
            Long prior = replay("result_finalize", key, payload);
            if (prior != null) {
                return replayedResult(prior, match);
            }
            CompetitionResult result = resultOf(matchId);
            if (result == null) {
                throw new ServiceException("还没有比赛结果");
            }
            if (!CompetitionRules.isFinal(result.getStatus())) {
                // Pre-event drafts and fixture planning do not establish a completed match.
                // Existing confirmations/replays retain their historical facts.
                requireFirstResultStarted(match);
                result.setStatus("confirmed");
                result.setConfirmerId(org.dromara.sports.platform.core.BusinessIdentity.getUserId());
                result.setConfirmedAt(now());
                saved(resultMapper.updateById(result), "比赛结果已被更新，请再试一次");
                suspendNewResultPlacings(project, result);
            }
            store("result_finalize", key, payload, "result", result.getId());
            CompetitionStage stage = stageMapper.selectById(match.getStageId());
            CompetitionUnit unit = unitMapper.selectById(stage.getUnitId());
            growthFacts.reconcileEvent(unit.getEventId());
            return resultCard(result, match);
        }));
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.competition.competitionservice.importresults",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public ImportCard importResults(Long eventId, Long unitId, String text, String requestKey) {
        ManagedOrganization organization = requireOrganizer();
        String body = required(text, 20000, "导入内容");
        String key = required(requestKey, 128, "请求键");
        if (unitId == null) {
            throw new ServiceException("请选择竞赛项目");
        }
        CompetitionUnit located = requireUnit(organization, unitId);
        if (!eventId.equals(located.getEventId())) {
            throw new ServiceException("竞赛项目不属于这场赛事");
        }
        // 项目编号属于这次导入的内容。同一请求键换到另一个项目要拒绝，不能把旧文件重放到新项目。
        String payload = eventId + "\n" + unitId + "\n" + body;
        return TenantHelper.dynamic(organization.tenantId(), () -> locked("result-import:" + organization.tenantId() + ":" + unitId, () -> {
            CompetitionUnit unit = requireUnit(organization, unitId);
            if (!eventId.equals(unit.getEventId())) {
                throw new ServiceException("竞赛项目不属于这场赛事");
            }
            requireRunnable(organization, unit.getEventId());
            Long prior = replay("result_import", key, payload);
            if (prior != null) {
                return new ImportCard(prior, "已按原来的文件处理");
            }
            int count = applyImport(unit.getId(), body);
            store("result_import", key, payload, "unit", unit.getId());
            return new ImportCard(unit.getId(), "已写入 " + count + " 场草稿");
        }));
    }

    public List<AwardCard> awards(Long unitId) {
        ManagedOrganization organization = requireOrganizer();
        CompetitionUnit unit = requireUnit(organization, unitId);
        return TenantHelper.dynamic(organization.tenantId(), () -> currentHonors(honorsOf(unit)).stream()
            .filter(h -> "verified".equals(h.getStatus()))
            .collect(java.util.stream.Collectors.groupingBy(CompetitionHonor::getAwardKey, LinkedHashMap::new, java.util.stream.Collectors.toList()))
            .values().stream().map(rows -> awardCard(rows, unit.getName())).toList());
    }

    public AwardCard grant(Long registrationId, String title, String basis, String requestKey) {
        return grant(registrationId, title, basis, requestKey, null, null);
    }

    @org.dromara.sports.platform.core.SportsAction(value="competition.award.grant",title="核对正式依据并签发赛事奖项",reads={"asp_honor","asp_registration","asp_roster_version","asp_roster_member","asp_event","asp_competition_unit","asp_stage","asp_match","asp_match_entry","asp_result_version","asp_execution_command"},writes={"asp_honor","asp_execution_command"})
    public AwardCard grant(Long registrationId, String title, String basis, String requestKey, String awardKind, List<Long> basisMatchIds) {
        ManagedOrganization organization = requireOrganizer();
        String awardTitle = required(title, 200, "称号");
        String awardBasis = required(basis, 500, "获奖依据");
        if (awardTitle.contains("运动员等级") || awardTitle.contains("官方认证")) {
            throw new ServiceException("称号只写这场赛事里的名次或奖项");
        }
        String key = required(requestKey, 128, "请求键");
        String kind = awardKind == null || awardKind.isBlank()
            ? org.dromara.sports.platform.core.EventAwardLineage.kind(awardTitle, objectMapper.createObjectNode()) : awardKind;
        if (!List.of("placing", "special").contains(kind)) throw new ServiceException("请选择最终名次或专项奖");
        String payload = registrationId + "\n" + awardTitle + "\n" + awardBasis
            + (awardKind == null && basisMatchIds == null ? "" : "\n" + kind + "\n" + basisMatchIds);
        RosterView roster = rosterApi.approvedRoster(organization.tenantId(), registrationId)
            .orElseThrow(() -> new ServiceException("只有已通过审核的报名可以获奖"));
        if (roster.people().isEmpty()) {
            throw new ServiceException("获奖名单是空的");
        }
        return TenantHelper.dynamic(organization.tenantId(), () -> locked("award:" + registrationId + ":" + awardTitle, () -> {
            db.lock("event-fixtures:" + roster.eventId());
            requireRunnable(organization, roster.eventId());
            Long prior = replay("award", key, payload);
            if (prior != null) {
                return awardCard(honorsByKey(textOfHonor(prior, "awardKey")), roster.unitName());
            }
            List<CompetitionHonor> history = honorMapper.selectList(Wrappers.<CompetitionHonor>lambdaQuery()
                .eq(CompetitionHonor::getRegistrationId, registrationId).eq(CompetitionHonor::getCategory, "event"));
            List<CompetitionHonor> existing = new ArrayList<>(currentHonors(history).stream()
                .filter(h -> awardTitle.equals(h.getTitle()) && (h.getStatus() == null || "verified".equals(h.getStatus()))
                    && kind.equals(org.dromara.sports.platform.core.EventAwardLineage.kind(awardClaim(h), history.stream().map(this::awardClaim).toList()))).toList());
            if (existing.isEmpty()) {
                requireEventStarted(roster.eventId());
                if (kind.equals("placing") && currentHonors(history).stream().anyMatch(h ->
                    !"revoked".equals(h.getStatus()) && "placing".equals(org.dromara.sports.platform.core.EventAwardLineage.kind(awardClaim(h), history.stream().map(this::awardClaim).toList()))))
                    throw new ServiceException("该报名已有最终名次，请在赛后收尾中核实并更正原证明", 409);
                if (kind.equals("special") && currentHonors(history).stream().anyMatch(h -> awardTitle.equals(h.getTitle())
                    && List.of("pending", "suspended", "revised").contains(h.getStatus())))
                    throw new ServiceException("该专项奖正在复核，请核实原证明后重新签发", 409);
                var evidence = awardBasis(roster, kind, basisMatchIds);
                String awardKey = UUID.randomUUID().toString().replace("-", "");
                for (RosterPerson person : roster.people()) {
                    CompetitionHonor honor = new CompetitionHonor();
                    honor.setEventId(roster.eventId());
                    honor.setRegistrationId(registrationId);
                    honor.setPersonId(person.personId());
                    honor.setAwardKey(awardKey);
                    honor.setCategory("event");
                    honor.setTitle(awardTitle);
                    JsonNode source;
                    try { source = objectMapper.readTree(source(awardKey, roster, awardBasis)); }
                    catch (JsonProcessingException e) { throw new ServiceException("获奖依据无法保存"); }
                    ((com.fasterxml.jackson.databind.node.ObjectNode) source).put("awardRootKey", awardKey).put("awardKind", kind)
                        .put("basisScope", kind.equals("placing") ? "unit" : "matches");
                    ((com.fasterxml.jackson.databind.node.ObjectNode) source).set("basisResults", evidence.deepCopy());
                    honor.setSource(source.toString());
                    honor.setStatus("verified");
                    honor.setAwardedAt(now());
                    honor.setVersion(0);
                    honorMapper.insert(honor);
                    existing.add(honor);
                }
            }
            store("award", key, payload, "honor", existing.get(0).getId());
            return awardCard(existing, roster.unitName());
        }));
    }

    public List<ProofCard> myProofs() {
        return myProofs(false);
    }
    public List<ProofCard> myProofs(boolean history) {
        RegistrationProfile profile = accountApi.currentRegistrationProfile()
            .orElseThrow(() -> new ServiceException("请先完成本人档案"));
        List<CompetitionHonor> honors = TenantHelper.ignore(() -> honorMapper.selectList(Wrappers.<CompetitionHonor>lambdaQuery()
            .eq(CompetitionHonor::getPersonId, profile.personId())
            .eq(CompetitionHonor::getCategory, "event")
            .orderByDesc(CompetitionHonor::getId)));
        List<ProofCard> cards = new ArrayList<>();
        var current = currentHonors(honors);
        for (CompetitionHonor honor : honors) {
            boolean latest = current.stream().anyMatch(h -> h.getId().equals(honor.getId()));
            if (history || latest && "verified".equals(honor.getStatus())) {
                cards.add(proofCard(honor, profile.personId(), latest));
            }
        }
        return cards;
    }

    public List<OwnResultCard> myResults() {
        RegistrationProfile profile = accountApi.currentRegistrationProfile()
            .orElseThrow(() -> new ServiceException("请先完成本人档案"));
        List<Long> registrationIds = rosterApi.registrationIdsForPerson(profile.personId());
        if (registrationIds.isEmpty()) {
            return List.of();
        }
        return TenantHelper.ignore(() -> {
            List<OwnResultCard> cards = new ArrayList<>();
            List<CompetitionMatchEntry> sides = matchEntryMapper.selectList(Wrappers.<CompetitionMatchEntry>lambdaQuery()
                .in(CompetitionMatchEntry::getRegistrationId, registrationIds)
                .ne(CompetitionMatchEntry::getStatus, "withdrawn"));
            for (CompetitionMatchEntry side : sides) {
                CompetitionResult result = resultMapper.selectOne(Wrappers.<CompetitionResult>lambdaQuery()
                    .eq(CompetitionResult::getMatchId, side.getMatchId())
                    .eq(CompetitionResult::getStatus, "confirmed")
                    .orderByDesc(CompetitionResult::getId)
                    .last("limit 1"));
                if (result == null) {
                    continue;
                }
                CompetitionMatch match = matchMapper.selectById(side.getMatchId());
                if (match == null) {
                    continue;
                }
                CompetitionStage stage = stageMapper.selectById(match.getStageId());
                CompetitionUnit unit = stage == null ? null : unitMapper.selectById(stage.getUnitId());
                CompetitionEvent event = unit == null ? null : eventMapper.selectById(unit.getEventId());
                List<CompetitionMatchEntry> opponents = sides(match.getId());
                cards.add(new OwnResultCard(match.getCode(), unit == null ? "" : unit.getName(),
                    event == null ? "" : event.getName(), event != null && "cancelled".equals(event.getHoldingStatus()),
                    text(result.getRawPerformance(), "summary"), text(result.getRawPerformance(), "outcomeA"),
                    text(result.getRawPerformance(), "outcomeB"), text(result.getRawPerformance(), "games"), entryLabel(side(opponents, "A")), entryLabel(side(opponents, "B"))));
            }
            return cards;
        });
    }

    public ProofCard proof(Long honorId) {
        CompetitionHonor honor = TenantHelper.ignore(() -> honorMapper.selectById(honorId));
        if (honor == null || !"event".equals(honor.getCategory()) || !"verified".equals(honor.getStatus())) {
            throw new ServiceException("证明不存在");
        }
        RegistrationProfile profile = accountApi.currentRegistrationProfile().orElse(null);
        boolean owner = profile != null && profile.personId().equals(honor.getPersonId());
        boolean organizer = false;
        if (!owner) {
            ManagedOrganization organization = sessionApi.managedOrganization(org.dromara.sports.platform.core.BusinessIdentity.getUserId()).orElse(null);
            organizer = organization != null && organization.tenantId().equals(honor.getTenantId())
                && qualificationApi.hasStaffAction(organization.tenantId(), organization.organizationId(), organization.accountId(), "organize");
        }
        if (!owner && !organizer) {
            throw new ServiceException("证明不存在");
        }
        List<CompetitionHonor> history = TenantHelper.ignore(() -> honorMapper.selectList(Wrappers.<CompetitionHonor>lambdaQuery()
            .eq(CompetitionHonor::getRegistrationId, honor.getRegistrationId()).eq(CompetitionHonor::getCategory, "event")));
        if (currentHonors(history).stream().noneMatch(h -> h.getId().equals(honor.getId()))) throw new ServiceException("该证明已被替换，请查看当前有效证明", 409);
        return proofCard(honor, honor.getPersonId(), true);
    }

    private int applyImport(Long unitId, String body) {
        var rows = org.dromara.sports.competition.ResultImportParser.parse(body);
        for (var row : rows) {
            CompetitionMatch match = findMatch(unitId, row.code());
            String canonical = canonical(row.summary(), row.games(), row.outcomeA(), row.outcomeB());
            writeResult(match, canonical, row.summary(), row.games(), row.outcomeA(), row.outcomeB(), true);
        }
        return rows.size();
    }

    private CompetitionResult writeResult(CompetitionMatch match, String canonical, String summary, String games,
                                          String outcomeA, String outcomeB, boolean fromImport) {
        CompetitionRules.requireComplementary(outcomeA, outcomeB);
        CompetitionResult result = resultOf(match.getId());
        String stored = result == null ? null : text(result.getRawPerformance(), "canonical");
        if (result != null) {
            CompetitionRules.rejectChangedFinal(result.getStatus(), stored, canonical);
            if (CompetitionRules.isFinal(result.getStatus())) {
                return result;
            }
        }
        String raw = raw(canonical, summary, games, outcomeA, outcomeB);
        if (result == null) {
            result = new CompetitionResult();
            result.setMatchId(match.getId());
            result.setRevision(1);
            result.setStatus("draft");
            result.setRawPerformance(raw);
            result.setDecision("{}");
            result.setVersion(0);
            resultMapper.insert(result);
        } else {
            result.setRawPerformance(raw);
            saved(resultMapper.updateById(result), "比赛结果已被更新，请再试一次");
            resultItemMapper.delete(Wrappers.<CompetitionResultItem>lambdaQuery()
                .eq(CompetitionResultItem::getResultVersionId, result.getId()));
        }
        List<CompetitionMatchEntry> sides = sides(match.getId());
        insertItem(result.getId(), side(sides, "A"), outcomeA);
        insertItem(result.getId(), side(sides, "B"), outcomeB);
        if (fromImport && CompetitionRules.isFinal(result.getStatus())) {
            return result;
        }
        return result;
    }

    /**
     * 只在当前竞赛项目的手工阶段里按编号查找。别的项目可以有相同编号，不能拿来代写。
     */
    private CompetitionMatch findMatch(Long unitId, String code) {
        CompetitionStage stage = systemStage(unitId);
        CompetitionMatch match = stage == null ? null : matchMapper.selectOne(Wrappers.<CompetitionMatch>lambdaQuery()
            .eq(CompetitionMatch::getStageId, stage.getId())
            .eq(CompetitionMatch::getCode, code));
        if (match == null) {
            throw new ServiceException("这个项目里找不到场次 " + code);
        }
        return match;
    }

    private void insertItem(Long resultId, CompetitionMatchEntry entry, String outcome) {
        CompetitionResultItem item = new CompetitionResultItem();
        item.setResultVersionId(resultId);
        item.setMatchEntryId(entry.getId());
        item.setPerformanceStatus("valid");
        item.setUnit("point");
        item.setComponents("{\"outcome\":\"" + outcome + "\"}");
        item.setVersion(0);
        resultItemMapper.insert(item);
    }

    private void insertSide(Long matchId, String slot, RosterView roster) {
        CompetitionMatchEntry entry = new CompetitionMatchEntry();
        entry.setMatchId(matchId);
        entry.setRegistrationId(roster.registrationId());
        entry.setRosterVersionId(roster.rosterVersionId());
        entry.setSlot(slot);
        entry.setQualificationSource("{\"source\":\"approved\"}");
        entry.setStatus("confirmed");
        entry.setVersion(0);
        matchEntryMapper.insert(entry);
    }

    private CompetitionStage ensureStage(Long unitId) {
        CompetitionStage stage = systemStage(unitId);
        if (stage != null) {
            return stage;
        }
        Integer max = stageMapper.selectList(Wrappers.<CompetitionStage>lambdaQuery().eq(CompetitionStage::getUnitId, unitId))
            .stream().map(CompetitionStage::getSequence).max(Integer::compareTo).orElse(0);
        stage = new CompetitionStage();
        stage.setUnitId(unitId);
        stage.setName("手工场次");
        stage.setFormat(SYSTEM_STAGE);
        stage.setSequence(max + 1);
        stage.setStatus("ready");
        stage.setVersion(0);
        stageMapper.insert(stage);
        return stage;
    }

    private CompetitionStage systemStage(Long unitId) {
        return stageMapper.selectOne(Wrappers.<CompetitionStage>lambdaQuery()
            .eq(CompetitionStage::getUnitId, unitId)
            .eq(CompetitionStage::getFormat, SYSTEM_STAGE));
    }

    /** Older single-project callers remain usable; a multi-project participant must choose a project. */
    private Long attendanceUnit(ManagedOrganization organization, Long eventId, Long requestedUnit, Long personId) {
        Long selected = requestedUnit;
        if (selected == null) {
            var eligibleUnits = rosterApi.approvedRosters(organization.tenantId(), eventId).stream()
                .filter(r -> r.people().stream().anyMatch(p -> personId.equals(p.personId())))
                .map(RosterView::unitId).distinct().toList();
            if (eligibleUnits.size() != 1) throw new ServiceException("请明确选择本次报到的赛事项目");
            selected = eligibleUnits.get(0);
        }
        CompetitionUnit unit = requireUnit(organization, selected);
        if (!eventId.equals(unit.getEventId())) throw new ServiceException("报到项目不属于这场赛事");
        return selected;
    }

    private void requireAttendanceFunds(String tenantId, Long eventId, Long unitId, Long personId) {
        var rosters = rosterApi.approvedRosters(tenantId, eventId).stream()
            .filter(roster -> unitId.equals(roster.unitId()) && roster.people().stream().anyMatch(person -> personId.equals(person.personId())))
            .sorted(java.util.Comparator.comparing(RosterView::registrationId)).toList();
        if (rosters.isEmpty()) throw new ServiceException("只能为本项目已通过审核的参赛名单成员报到");
        for (RosterView roster : rosters) {
            var obligation = feeApi.current(tenantId, roster.registrationId()).orElse(null);
            if (obligation != null && ("not_required".equals(obligation.status()) || "settled".equals(obligation.status()))) {
                feeApi.requireParticipationReady(tenantId, roster.registrationId());
                return;
            }
        }
        throw new ServiceException("本项目报名的有效收款不足，请核对收款后再办理报到");
    }

    private RosterView requireEntry(String tenantId, Long unitId, Long registrationId) {
        return rosterApi.approvedRostersForUnit(tenantId, unitId).stream()
            .filter(roster -> registrationId.equals(roster.registrationId()))
            .findFirst()
            .orElseThrow(() -> new ServiceException("场次只能使用本项目已通过审核的报名"));
    }

    private CompetitionCheckin confirmedCheckin(Long eventId, Long unitId, Long personId) {
        return checkinMapper.selectOne(Wrappers.<CompetitionCheckin>lambdaQuery()
            .eq(CompetitionCheckin::getEventId, eventId)
            .eq(CompetitionCheckin::getUnitId, unitId)
            .eq(CompetitionCheckin::getPersonId, personId)
            .isNull(CompetitionCheckin::getMatchId)
            .eq(CompetitionCheckin::getStatus, "confirmed"));
    }

    private List<CompetitionCheckin> confirmedCheckins(Long eventId) {
        return checkinMapper.selectList(Wrappers.<CompetitionCheckin>lambdaQuery()
                .eq(CompetitionCheckin::getEventId, eventId)
                .isNull(CompetitionCheckin::getMatchId)
                .eq(CompetitionCheckin::getStatus, "confirmed"));
    }

    private CompetitionResult resultOf(Long matchId) {
        return resultMapper.selectOne(Wrappers.<CompetitionResult>lambdaQuery()
            .eq(CompetitionResult::getMatchId, matchId)
            .in(CompetitionResult::getStatus, "draft", "confirmed")
            .orderByDesc(CompetitionResult::getRevision).last("limit 1"));
    }

    private List<CompetitionMatchEntry> sides(Long matchId) {
        return matchEntryMapper.selectList(Wrappers.<CompetitionMatchEntry>lambdaQuery()
            .eq(CompetitionMatchEntry::getMatchId, matchId)
            .orderByAsc(CompetitionMatchEntry::getSlot));
    }

    private CompetitionMatchEntry side(List<CompetitionMatchEntry> sides, String slot) {
        return sides.stream().filter(entry -> slot.equals(entry.getSlot())).findFirst()
            .orElseThrow(() -> new ServiceException("场次两侧不完整"));
    }

    private List<CompetitionHonor> honorsOf(CompetitionUnit unit) {
        List<Long> registrationIds = rosterApi.approvedRostersForUnit(unit.getTenantId(), unit.getId()).stream()
            .map(RosterView::registrationId).toList();
        if (registrationIds.isEmpty()) {
            return List.of();
        }
        return honorMapper.selectList(Wrappers.<CompetitionHonor>lambdaQuery()
            .in(CompetitionHonor::getRegistrationId, registrationIds)
            .isNotNull(CompetitionHonor::getAwardKey)
            .orderByAsc(CompetitionHonor::getId));
    }

    private List<CompetitionHonor> honorsFor(Long registrationId, String title) {
        return honorMapper.selectList(Wrappers.<CompetitionHonor>lambdaQuery()
            .eq(CompetitionHonor::getRegistrationId, registrationId)
            .eq(CompetitionHonor::getTitle, title)
            .eq(CompetitionHonor::getStatus, "verified")
            .orderByAsc(CompetitionHonor::getId));
    }

    private List<CompetitionHonor> honorsByKey(String awardKey) {
        return honorMapper.selectList(Wrappers.<CompetitionHonor>lambdaQuery()
            .eq(CompetitionHonor::getAwardKey, awardKey)
            .orderByAsc(CompetitionHonor::getId));
    }

    private Long replay(String action, String requestKey, String payload) {
        ExecutionCommand command = commandMapper.selectOne(Wrappers.<ExecutionCommand>lambdaQuery()
            .eq(ExecutionCommand::getAction, action)
            .eq(ExecutionCommand::getRequestKey, requestKey));
        if (command == null) {
            return null;
        }
        if (!command.getPayloadHash().equals(CompetitionRules.sha256(payload))) {
            throw new ServiceException("这个请求已经用于不同内容");
        }
        return command.getSubjectId();
    }

    private void store(String action, String requestKey, String payload, String subjectType, Long subjectId) {
        ExecutionCommand command = new ExecutionCommand();
        command.setAction(action);
        command.setRequestKey(requestKey);
        command.setPayloadHash(CompetitionRules.sha256(payload));
        command.setSubjectType(subjectType);
        command.setSubjectId(subjectId);
        command.setVersion(0);
        try {
            commandMapper.insert(command);
        } catch (DataIntegrityViolationException exception) {
            Long prior = replay(action, requestKey, payload);
            if (prior == null) {
                throw new ServiceException("这个请求已经用于不同内容");
            }
        }
    }

    private CheckInCard checkInCard(CompetitionCheckin checkin) {
        String name = accountApi.memberLabels(List.of(checkin.getPersonId())).stream().findFirst().map(MemberLabel::legalName).orElse("");
        return new CheckInCard(checkin.getId(), checkin.getPersonId(), name,
            checkin.getOccurredAt().withOffsetSameInstant(SHANGHAI).format(CLOCK), checkin.getUnitId());
    }

    private ResultCard replayedResult(Long resultId, CompetitionMatch match) {
        CompetitionResult stored = loadResult(resultId);
        if (!match.getId().equals(stored.getMatchId())) {
            throw new ServiceException("这个请求已经用于不同内容");
        }
        return resultCard(stored, match);
    }

    private MatchCard matchCard(CompetitionMatch match) {
        List<CompetitionMatchEntry> sides = sides(match.getId());
        CompetitionResult result = resultOf(match.getId());
        String raw = result == null ? null : result.getRawPerformance();
        return new MatchCard(match.getId(), match.getCode(), entryLabel(side(sides, "A")), entryLabel(side(sides, "B")),
            result == null ? null : result.getStatus(), text(raw, "summary"), text(raw, "games"),
            text(raw, "outcomeA"), text(raw, "outcomeB"));
    }

    private ResultCard resultCard(CompetitionResult result, CompetitionMatch match) {
        return new ResultCard(result.getId(), match.getId(), result.getStatus(), text(result.getRawPerformance(), "summary"),
            text(result.getRawPerformance(), "games"), text(result.getRawPerformance(), "outcomeA"), text(result.getRawPerformance(), "outcomeB"));
    }

    private AwardCard awardCard(List<CompetitionHonor> rows, String unitName) {
        CompetitionHonor first = rows.get(0);
        RosterView roster = rosterApi.approvedRoster(first.getTenantId(), first.getRegistrationId()).orElse(null);
        String names = roster == null ? rows.stream().map(row -> String.valueOf(row.getPersonId())).reduce((left, right) -> left + "、" + right).orElse("")
            : roster.people().stream().map(RosterPerson::legalName).reduce((left, right) -> left + "、" + right).orElse("");
        return new AwardCard(first.getAwardKey(), first.getRegistrationId(), unitName, first.getTitle(), names, rows.size());
    }

    private ProofCard proofCard(CompetitionHonor honor, Long viewerPersonId, boolean current) {
        var source = awardClaim(honor).source();
        var members = db.list("SELECT rm.person_snapshot->>'legalName' AS name FROM asp_roster_member rm JOIN asp_roster_version rv ON rv.id=rm.roster_version_id WHERE rv.id=? AND rv.registration_id=? ORDER BY rm.position", source.path("rosterVersionId").asLong(), honor.getRegistrationId());
        String names = String.join("、", members.stream().map(m -> java.util.Objects.toString(m.get("name"), "")).toList());
        String eventName = TenantHelper.dynamic(honor.getTenantId(), () -> {
            CompetitionEvent event = eventMapper.selectById(honor.getEventId());
            return event == null ? "" : event.getName();
        });
        var unit = TenantHelper.dynamic(honor.getTenantId(), () -> unitMapper.selectById(source.path("unitId").asLong()));
        String unitName = unit == null ? "" : unit.getName();
        return new ProofCard(honor.getId(), honor.getAwardKey(), eventName, unitName, honor.getTitle(), names,
            honor.getAwardedAt().withOffsetSameInstant(SHANGHAI).format(CLOCK), viewerPersonId.equals(honor.getPersonId()),
            current ? honor.getStatus() : "replaced", current && "verified".equals(honor.getStatus()),
            text(honor.getSource(), "revocationReason") == null ? text(honor.getSource(), "correctionReason") : text(honor.getSource(), "revocationReason"));
    }

    private org.dromara.sports.platform.core.EventAwardLineage.Claim awardClaim(CompetitionHonor h) {
        JsonNode source;
        try { source = objectMapper.readTree(h.getSource() == null ? "{}" : h.getSource()); }
        catch (JsonProcessingException e) { throw new ServiceException("获奖依据无法读取，请联系主办方核对", 409); }
        return new org.dromara.sports.platform.core.EventAwardLineage.Claim(h.getId(), h.getRegistrationId(), h.getPersonId(), h.getAwardKey(), h.getTitle(), source, h.getStatus());
    }
    private List<CompetitionHonor> currentHonors(List<CompetitionHonor> rows) {
        var latest = org.dromara.sports.platform.core.EventAwardLineage.latest(rows.stream().map(this::awardClaim).toList());
        return rows.stream().filter(h -> latest.stream().anyMatch(c -> c.id() == h.getId())).toList();
    }
    /** A later official match changes a project's ranking evidence, even without a correction. */
    private void suspendNewResultPlacings(CompetitionUnit unit, CompetitionResult result) {
        var honors = honorMapper.selectList(Wrappers.<CompetitionHonor>lambdaQuery().eq(CompetitionHonor::getEventId, unit.getEventId())
            .eq(CompetitionHonor::getCategory, "event").isNotNull(CompetitionHonor::getAwardKey));
        for (var h : currentHonors(honors)) {
            var claim = awardClaim(h);
            if (!"verified".equals(h.getStatus()) || claim.source().path("unitId").asLong() != unit.getId()
                || !"placing".equals(org.dromara.sports.platform.core.EventAwardLineage.kind(claim, honors.stream().map(this::awardClaim).toList()))) continue;
            boolean bound = false;
            for (JsonNode basis : claim.source().path("basisResults")) if (basis.path("resultId").asText().equals(String.valueOf(result.getId()))) bound = true;
            if (!bound) {
                var source = (com.fasterxml.jackson.databind.node.ObjectNode) claim.source().deepCopy();
                source.put("reviewMatchId", String.valueOf(result.getMatchId())).put("reviewResultId", String.valueOf(result.getId()));
                db.update("UPDATE asp_honor SET status='suspended',source=?::jsonb,version=version+1,update_time=CURRENT_TIMESTAMP WHERE id=? AND status='verified'", source.toString(), h.getId());
            }
        }
    }
    /** Freeze explicit dependencies, never accept 'some other match is confirmed' as evidence. */
    private com.fasterxml.jackson.databind.node.ArrayNode awardBasis(RosterView roster, String kind, List<Long> requested) {
        if (requested != null && (requested.size() > 500 || requested.stream().anyMatch(java.util.Objects::isNull))) throw new ServiceException("获奖依据场次不合法");
        var rows = db.list("SELECT m.id AS match_id,v.id AS result_id,v.revision,v.status FROM asp_match m JOIN asp_stage s ON s.id=m.stage_id LEFT JOIN LATERAL(SELECT id,revision,status FROM asp_result_version WHERE match_id=m.id AND status IN('confirmed','void') ORDER BY revision DESC LIMIT 1) v ON true WHERE s.unit_id=? AND m.status<>'cancelled' AND (? OR EXISTS(SELECT 1 FROM asp_match_entry me WHERE me.match_id=m.id AND me.registration_id=?)) ORDER BY m.id", roster.unitId(), kind.equals("placing"), roster.registrationId());
        var evidence = objectMapper.createArrayNode();
        for (var row : rows) {
            long match = ((Number) row.get("match_id")).longValue();
            if (kind.equals("special") && requested != null && !requested.isEmpty() && !requested.contains(match)) continue;
            if (!"confirmed".equals(row.get("status"))) throw new ServiceException("请先确认获奖依据中各场的正式结果", 409);
            evidence.addObject().put("matchId", String.valueOf(match)).put("resultId", row.get("result_id").toString())
                .put("revision", ((Number) row.get("revision")).longValue()).put("status", "confirmed");
        }
        if (evidence.isEmpty() || kind.equals("special") && requested != null && !requested.isEmpty() && evidence.size() != requested.stream().distinct().count())
            throw new ServiceException("请选择本报名项目内的有效正式赛果作为获奖依据", 409);
        return evidence;
    }

    private String entryLabel(CompetitionMatchEntry entry) {
        return rosterApi.approvedRoster(entry.getTenantId(), entry.getRegistrationId())
            .map(this::label).orElse("报名 " + entry.getRegistrationId());
    }

    private String label(RosterView roster) {
        return roster.people().stream().map(RosterPerson::legalName).filter(name -> name != null && !name.isBlank())
            .reduce((left, right) -> left + "、" + right).orElse("报名 " + roster.registrationId());
    }

    private String source(String awardKey, RosterView roster, String basis) {
        Map<String, String> body = new LinkedHashMap<>();
        body.put("awardKey", awardKey);
        body.put("registrationId", String.valueOf(roster.registrationId()));
        body.put("rosterVersionId", String.valueOf(roster.rosterVersionId()));
        body.put("unitId", String.valueOf(roster.unitId()));
        body.put("basis", basis);
        try {
            return objectMapper.writeValueAsString(body);
        } catch (JsonProcessingException exception) {
            throw new ServiceException("获奖事实无法保存");
        }
    }

    private String raw(String canonical, String summary, String games, String outcomeA, String outcomeB) {
        Map<String, String> body = new LinkedHashMap<>();
        body.put("canonical", canonical);
        body.put("summary", summary == null ? "" : summary.trim());
        body.put("games", games == null ? "" : games.trim());
        body.put("outcomeA", outcomeA);
        body.put("outcomeB", outcomeB);
        try {
            return objectMapper.writeValueAsString(body);
        } catch (JsonProcessingException exception) {
            throw new ServiceException("比赛结果无法保存");
        }
    }

    private String textOfHonor(Long honorId, String field) {
        CompetitionHonor honor = honorMapper.selectById(honorId);
        if (honor == null) {
            throw new ServiceException("证明不存在");
        }
        String value = text(honor.getSource(), field);
        if (value == null) {
            throw new ServiceException("证明不存在");
        }
        return value;
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

    private String canonical(String summary, String games, String outcomeA, String outcomeB) {
        return blank(summary) + "\n" + blank(games) + "\nA=" + outcomeA + "\nB=" + outcomeB;
    }

    private String outcome(String value) {
        String outcome = value == null ? "" : value.trim();
        if (!"win".equals(outcome) && !"loss".equals(outcome) && !"draw".equals(outcome)) {
            throw new ServiceException("胜负只能是胜、负或平");
        }
        return outcome;
    }

    private CompetitionCheckin loadCheckin(Long id) {
        CompetitionCheckin checkin = checkinMapper.selectById(id);
        if (checkin == null) {
            throw new ServiceException("报到不存在");
        }
        return checkin;
    }

    private CompetitionMatch loadMatch(Long id) {
        CompetitionMatch match = matchMapper.selectById(id);
        if (match == null) {
            throw new ServiceException("场次不存在");
        }
        return match;
    }

    private CompetitionResult loadResult(Long id) {
        CompetitionResult result = resultMapper.selectById(id);
        if (result == null) {
            throw new ServiceException("比赛结果不存在");
        }
        return result;
    }

    private CompetitionMatch requireMatch(ManagedOrganization organization, Long matchId) {
        CompetitionMatch match = loadMatch(matchId);
        CompetitionStage stage = stageMapper.selectById(match.getStageId());
        if (stage == null || !SYSTEM_STAGE.equals(stage.getFormat())) {
            throw new ServiceException("场次不存在");
        }
        requireUnit(organization, stage.getUnitId());
        return match;
    }

    private CompetitionUnit requireUnit(ManagedOrganization organization, Long unitId) {
        return TenantHelper.dynamic(organization.tenantId(), () -> {
            CompetitionUnit unit = unitMapper.selectById(unitId);
            if (unit == null) {
                throw new ServiceException("竞赛项目不存在");
            }
            requireEvent(organization, unit.getEventId());
            return unit;
        });
    }

    private void requireEvent(ManagedOrganization organization, Long eventId) {
        CompetitionEvent event = eventMapper.selectById(eventId);
        if (event == null || !organization.organizationId().equals(event.getOrganizationId())) {
            throw new ServiceException("赛事不存在");
        }
    }

    private void requireMatchRunnable(ManagedOrganization organization, CompetitionMatch match) {
        CompetitionStage stage = stageMapper.selectById(match.getStageId());
        if (stage == null) {
            throw new ServiceException("场次不存在");
        }
        CompetitionUnit unit = unitMapper.selectById(stage.getUnitId());
        if (unit == null) {
            throw new ServiceException("竞赛项目不存在");
        }
        requireRunnable(organization, unit.getEventId());
    }

    private void requireRunnable(ManagedOrganization organization, Long eventId) {
        CompetitionEvent event = eventMapper.selectById(eventId);
        if (event == null || !organization.organizationId().equals(event.getOrganizationId())) {
            throw new ServiceException("赛事不存在");
        }
        if (!"normal".equals(event.getHoldingStatus())) {
            throw new ServiceException("赛事已取消，不能继续报到、建场、录分或发证");
        }
    }

    /** Do not turn future fixtures into official outcomes; later corrections use their own history path. */
    private void requireFirstResultStarted(CompetitionMatch match) {
        CompetitionStage stage = stageMapper.selectById(match.getStageId());
        CompetitionUnit unit = stage == null ? null : unitMapper.selectById(stage.getUnitId());
        CompetitionEvent event = unit == null ? null : eventMapper.selectById(unit.getEventId());
        requireStartWindow(event == null ? null : event.getStartsAt(), match.getScheduledStart(), now());
    }

    private void requireEventStarted(Long eventId) {
        CompetitionEvent event = eventMapper.selectById(eventId);
        requireStartWindow(event == null ? null : event.getStartsAt(), null, now());
    }

    /** Compare instants, allowing the exact start and results before the event's planned end. */
    static void requireStartWindow(OffsetDateTime eventStart, OffsetDateTime matchStart, OffsetDateTime current) {
        if (eventStart == null || current == null) {
            throw new ServiceException("赛事缺少开始时间，请先核对赛事安排", 409);
        }
        if (current.isBefore(eventStart)) {
            throw new ServiceException("赛事尚未开赛，不能确认正式赛果或新增赛事荣誉", 409);
        }
        if (matchStart != null && current.isBefore(matchStart)) {
            throw new ServiceException("尚未到本场安排的开始时间，不能确认正式赛果", 409);
        }
    }

    /** 结束后不新增执行；已有场次录分、结果确认及有依据的证明不使用此门禁。 */
    private void requireNotEnded(Long eventId) {
        CompetitionEvent event = eventMapper.selectById(eventId);
        if (event == null || (event.getEndsAt() != null && !OffsetDateTime.now(SHANGHAI).isBefore(event.getEndsAt()))) {
            throw new ServiceException("赛事已结束，不能新增报到或场次");
        }
    }

    private ManagedOrganization requireOrganizer() {
        ManagedOrganization organization = sessionApi.managedOrganization(org.dromara.sports.platform.core.BusinessIdentity.getUserId())
            .orElseThrow(() -> new ServiceException("当前账号不能管理这场赛事"));
        if (!qualificationApi.hasStaffAction(organization.tenantId(), organization.organizationId(), organization.accountId(), "organize")) {
            throw new ServiceException("当前账号不能管理这场赛事");
        }
        return organization;
    }

    private <T> T locked(String key, Supplier<T> action) {
        return mutualLock.execute(key, WAIT_MILLIS, LEASE_MILLIS, () -> transaction().execute(status -> action.get()));
    }

    private TransactionTemplate transaction() {
        TransactionTemplate template = new TransactionTemplate(transactionManager);
        template.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRED);
        return template;
    }

    private void saved(int updated, String message) {
        if (updated != 1) {
            throw new ServiceException(message);
        }
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

    private String blank(String value) {
        return value == null ? "" : value.trim();
    }

    public record EventChoice(Long eventId, String name) {
    }

    public record UnitChoice(Long unitId, String name) {
    }

    public record EligiblePerson(Long personId, String legalName, String unitName, Long registrationId, boolean checkedIn, Long unitId, boolean legacyEventCheckin) {
    }

    public record CheckInCard(Long checkInId, Long personId, String legalName, String occurredAt, Long unitId) {
    }

    public record EntryChoice(Long registrationId, String label) {
    }

    public record MatchCard(Long matchId, String code, String sideA, String sideB, String resultStatus, String summary, String games,
                            String outcomeA, String outcomeB) {
    }

    public record ResultCard(Long resultId, Long matchId, String status, String summary, String games, String outcomeA, String outcomeB) {
    }

    public record ImportCard(Long eventId, String message) {
    }

    public record AwardCard(String awardKey, Long registrationId, String unitName, String title, String names, int people) {
    }

    public record OwnResultCard(String matchCode, String unitName, String eventName, boolean eventCancelled,
                                String summary, String outcomeA, String outcomeB, String games, String sideA, String sideB) {
    }

    public record ProofCard(Long honorId, String awardKey, String eventName, String unitName, String title, String names,
                            String awardedAt, boolean self, String status, boolean current, String reason) {
    }
}


