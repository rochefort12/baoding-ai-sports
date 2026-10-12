package org.dromara.sports.team.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.core.lock.MutualLock;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.PlatformAccountApi;
import org.dromara.sports.api.InvitationNoticeApi;
import org.dromara.sports.api.PlatformAccountApi.InviteCandidate;
import org.dromara.sports.api.PlatformAccountApi.MemberLabel;
import org.dromara.sports.api.PlatformAccountApi.RegistrationProfile;
import org.dromara.sports.api.TeamMembershipApi.ActiveTeam;
import org.dromara.sports.team.TeamRules;
import org.dromara.sports.team.TeamShareRules;
import org.dromara.sports.team.domain.TeamSportCatalog;
import org.dromara.sports.team.domain.SportsTeam;
import org.dromara.sports.team.domain.SportsTeamHistory;
import org.dromara.sports.team.domain.SportsTeamInvitation;
import org.dromara.sports.team.domain.SportsTeamJoinRequest;
import org.dromara.sports.team.domain.SportsTeamMember;
import org.dromara.sports.team.mapper.TeamSportCatalogMapper;
import org.dromara.sports.team.mapper.SportsTeamHistoryMapper;
import org.dromara.sports.team.mapper.SportsTeamInvitationMapper;
import org.dromara.sports.team.mapper.SportsTeamJoinRequestMapper;
import org.dromara.sports.team.mapper.SportsTeamMapper;
import org.dromara.sports.team.mapper.SportsTeamMemberMapper;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * 长期队伍写在平台共享表。每次查询都先落到当前账号的成员、申请或邀请，不列出全部队伍。
 * 解散、退队和转让都不修改报名。
 */
@Service
@RequiredArgsConstructor
public class TeamService {
    private final org.dromara.sports.api.RegistrationResponsibilityApi responsibilities;

    private static final ZoneOffset SHANGHAI = ZoneOffset.ofHours(8);
    private static final long WAIT_MILLIS = 3000;
    private static final long LEASE_MILLIS = 30000;

    private final SportsTeamMapper teamMapper;
    private final SportsTeamMemberMapper memberMapper;
    private final SportsTeamJoinRequestMapper requestMapper;
    private final SportsTeamInvitationMapper invitationMapper;
    private final SportsTeamHistoryMapper historyMapper;
    private final TeamSportCatalogMapper sportMapper;
    private final PlatformAccountApi platformAccountApi;
    private final InvitationNoticeApi invitationNoticeApi;
    private final MutualLock mutualLock;
    private final ObjectMapper objectMapper;
    private final PlatformTransactionManager transactionManager;

    public TeamHome home() {
        return platformAccountApi.currentRegistrationProfile()
            .map(profile -> TenantHelper.ignore(() -> homeOf(profile.personId())))
            .orElseGet(() -> new TeamHome(List.of(), List.of(), List.of(), List.of()));
    }

    public PreviewCard preview(Long teamId) {
        profile();
        return TenantHelper.ignore(() -> {
            SportsTeam team = teamMapper.selectById(teamId);
            if (team == null) {
                throw new ServiceException("队伍不存在");
            }
            return new PreviewCard(team.getId(), team.getName(), team.getStatus());
        });
    }

    public TeamDetail detail(Long teamId) {
        RegistrationProfile profile = profile();
        return TenantHelper.ignore(() -> detailOf(teamId, profile.personId()));
    }

    public List<CandidateCard> candidates(Long teamId) {
        RegistrationProfile profile = profile();
        return TenantHelper.ignore(() -> {
            SportsTeam team = requireTeam(teamId);
            if (!captain(team, profile.personId())) {
                throw new ServiceException("只有队长可以办理");
            }
            return candidateCards(activeMembers(teamId));
        });
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.team.teamservice.create",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public TeamDetail create(String name) {
        RegistrationProfile profile = profile();
        String teamName = required(name, 200, "队名");
        return TenantHelper.ignore(() -> transaction().execute(status -> {
            SportsTeam team = new SportsTeam();
            team.setName(teamName);
            team.setSportId(badmintonId());
            team.setCaptainPersonId(profile.personId());
            team.setCreatorAccountId(profile.accountId());
            team.setJoinPolicy("open");
            team.setVisibility("members");
            team.setStatus("active");
            team.setVersion(0);
            teamMapper.insert(team);
            memberMapper.insert(newMember(team.getId(), profile.personId(), "captain", "create"));
            return detailOf(team.getId(), profile.personId());
        }));
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.team.teamservice.rename",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public TeamDetail rename(Long teamId, String name) {
        RegistrationProfile profile = profile();
        String teamName = required(name, 200, "队名");
        return locked(teamId, () -> {
            SportsTeam team = requireTeam(teamId);
            TeamRules.requireActive("active".equals(team.getStatus()));
            TeamRules.requireCaptain(captain(team, profile.personId()));
            if (teamName.equals(team.getName())) {
                return detailOf(teamId, profile.personId());
            }
            String beforeName = team.getName();
            team.setName(teamName);
            saved(teamMapper.updateById(team), "队伍已被更新，请再试一次");
            history(team.getId(), "rename", "修改队名", beforeName, team.getStatus(), team.getCaptainPersonId(),
                teamName, team.getStatus(), team.getCaptainPersonId());
            return detailOf(teamId, profile.personId());
        });
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.team.teamservice.apply",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public TeamHome apply(Long teamId) {
        RegistrationProfile profile = profile();
        return locked(teamId, () -> {
            SportsTeam team = requireTeam(teamId);
            boolean member = activeMember(teamId, profile.personId()) != null;
            TeamRules.requireCanApply("active".equals(team.getStatus()), member, pending(teamId, profile.personId()));
            SportsTeamJoinRequest request = new SportsTeamJoinRequest();
            request.setTeamId(teamId);
            request.setPersonId(profile.personId());
            request.setStatus("pending");
            request.setVersion(0);
            try {
                requestMapper.insert(request);
            } catch (DataIntegrityViolationException exception) {
                throw new ServiceException("已经有一条待处理的入队申请或邀请");
            }
            return homeOf(profile.personId());
        });
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.team.teamservice.cancel",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public TeamHome cancel(Long requestId) {
        RegistrationProfile profile = profile();
        SportsTeamJoinRequest located = TenantHelper.ignore(() -> requestMapper.selectById(requestId));
        if (located == null || !profile.personId().equals(located.getPersonId())) {
            throw new ServiceException("申请不存在");
        }
        return locked(located.getTeamId(), () -> {
            SportsTeamJoinRequest request = requestMapper.selectById(requestId);
            SportsTeam team = requireTeam(request.getTeamId());
            TeamRules.requireActive("active".equals(team.getStatus()));
            if (!"pending".equals(request.getStatus()) || !profile.personId().equals(request.getPersonId())) {
                throw new ServiceException("申请不存在");
            }
            request.setStatus("cancelled");
            saved(requestMapper.updateById(request), "申请已被更新，请再试一次");
            return homeOf(profile.personId());
        });
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.team.teamservice.approve",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public TeamDetail approve(Long requestId) {
        return decideRequest(requestId, "approved", null);
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.team.teamservice.reject",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public TeamDetail reject(Long requestId, String reason) {
        return decideRequest(requestId, "rejected", blankToNull(reason));
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.team.teamservice.invite",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public TeamDetail invite(Long teamId, String phone) { return invite(teamId, phone, false); }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.team.teamservice.invite",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public TeamDetail invite(Long teamId, String phone, boolean requestSms) {
        RegistrationProfile profile = profile();
        InviteCandidate candidate = platformAccountApi.findInviteCandidate(phone)
            .orElseThrow(() -> new ServiceException("这个手机号还没有注册"));
        if (candidate.personId() == null) {
            throw new ServiceException("对方档案未齐");
        }
        return locked(teamId, () -> {
            SportsTeam team = requireTeam(teamId);
            boolean self = profile.personId().equals(candidate.personId());
            boolean member = activeMember(teamId, candidate.personId()) != null;
            TeamRules.requireCanInvite("active".equals(team.getStatus()), captain(team, profile.personId()), member,
                pending(teamId, candidate.personId()), self);
            SportsTeamInvitation invitation = new SportsTeamInvitation();
            invitation.setTeamId(teamId);
            invitation.setInviterAccountId(profile.accountId());
            invitation.setInvitationKind("direct");
            invitation.setTargetPersonId(candidate.personId());
            invitation.setStatus("pending");
            invitation.setVersion(0);
            try {
                invitationMapper.insert(invitation);
            } catch (DataIntegrityViolationException exception) {
                throw new ServiceException("已经有一条待处理的入队申请或邀请");
            }
            invitationNoticeApi.created("team-invite", invitation.getId(), 0, candidate.accountId(), "收到入队邀请",
                "邀请你加入“" + team.getName() + "”，请本人查看并选择接受或拒绝。", "/portal/teams/invitations/" + invitation.getId(), requestSms);
            return detailOf(teamId, profile.personId());
        });
    }

    /** 深链只向指定受邀本人返回队名与邀请状态，不开放队内名单。 */
    public InvitationCard invitation(Long id) {
        RegistrationProfile viewer = profile();
        return TenantHelper.ignore(() -> {
            SportsTeamInvitation row = invitationMapper.selectById(id);
            if (row == null || !viewer.personId().equals(row.getTargetPersonId())) throw new ServiceException("邀请不存在或不是发给你的");
            SportsTeam team = requireTeam(row.getTeamId());
            return invitationCards(List.of(row), Map.of(team.getId(), team)).get(0);
        });
    }

    /** 队长可复制目前有效的分享授权，不能由普通队员读取凭据。 */
    public ShareLinkCard shareLink(Long teamId) {
        RegistrationProfile viewer = profile();
        return TenantHelper.ignore(() -> {
            SportsTeam team = requireTeam(teamId);
            TeamRules.requireActive("active".equals(team.getStatus()));
            TeamRules.requireCaptain(captain(team, viewer.personId()));
            SportsTeamInvitation row = currentShare(teamId);
            return row != null && "pending".equals(shareStatus(row, team)) ? shareLinkCard(row) : null;
        });
    }

    @org.dromara.sports.platform.core.SportsAction(value="team.share.create", title="生成队伍分享邀请", reads={"asp_account","asp_person","asp_team","asp_team_member","asp_team_invitation"}, writes={"asp_team_invitation"})
    public ShareLinkCard createShareLink(Long teamId, boolean replace) {
        RegistrationProfile viewer = profile();
        return locked(teamId, () -> {
            SportsTeam team = requireTeam(teamId);
            TeamRules.requireActive("active".equals(team.getStatus()));
            TeamRules.requireCaptain(captain(team, viewer.personId()));
            SportsTeamInvitation current = currentShare(teamId);
            if (!replace && current != null && "pending".equals(shareStatus(current, team))) return shareLinkCard(current);
            invalidateShareLinks(teamId);
            SportsTeamInvitation row = new SportsTeamInvitation();
            row.setTeamId(teamId); row.setInviterAccountId(viewer.accountId()); row.setInviterPersonId(viewer.personId());
            row.setInvitationKind("share"); row.setInviteToken(TeamShareRules.newToken()); row.setExpiresAt(now().plusDays(7));
            row.setStatus("pending"); row.setVersion(0);
            invitationMapper.insert(row);
            return shareLinkCard(row);
        });
    }

    @org.dromara.sports.platform.core.SportsAction(value="team.share.revoke", title="撤销队伍分享邀请", reads={"asp_account","asp_person","asp_team","asp_team_member","asp_team_invitation"}, writes={"asp_team_invitation"})
    public void revokeShareLink(Long teamId) {
        RegistrationProfile viewer = profile();
        locked(teamId, () -> {
            SportsTeam team = requireTeam(teamId);
            TeamRules.requireActive("active".equals(team.getStatus()));
            TeamRules.requireCaptain(captain(team, viewer.personId()));
            invalidateShareLinks(teamId);
            return null;
        });
    }

    /** 持有随机分享链接只能预览队名、有效性和期限，不返回现名单或任一成员资料。 */
    public SharePreviewCard previewShare(String token) {
        return TenantHelper.ignore(() -> {
            SportsTeamInvitation row = locateShare(token);
            SportsTeam team = requireTeam(row.getTeamId());
            return new SharePreviewCard(team.getId(), team.getName(), shareStatus(row, team), row.getExpiresAt());
        });
    }

    /** 登录后只补本人是否已加入/使用过，不扩大匿名预览或队内名单权限。 */
    public ShareConfirmationCard shareConfirmation(String token) {
        RegistrationProfile viewer = profile();
        return TenantHelper.ignore(() -> {
            SportsTeamInvitation row = locateShare(token);
            SportsTeam team = requireTeam(row.getTeamId());
            boolean member = activeMember(team.getId(), viewer.personId()) != null;
            Long used = invitationMapper.selectCount(Wrappers.<SportsTeamInvitation>lambdaQuery()
                .eq(SportsTeamInvitation::getShareInvitationId, row.getId()).eq(SportsTeamInvitation::getTargetPersonId, viewer.personId()));
            return new ShareConfirmationCard(team.getId(), team.getName(), shareStatus(row, team), row.getExpiresAt(), member, used != null && used > 0);
        });
    }

    /** 只有本人资料齐备且明确确认才加入。唯一接受记录使超时重试安全，也阻止离队后旧链复活。 */
    @org.dromara.sports.platform.core.SportsAction(value="team.share.accept", title="本人确认分享邀请入队", confirmation=true,
        reads={"asp_account","asp_person","asp_team","asp_team_member","asp_team_invitation","asp_team_join_request","asp_notification","asp_notification_delivery"},
        writes={"asp_team_invitation","asp_team_member","asp_team_join_request","asp_notification","asp_notification_delivery"})
    public ShareJoinCard acceptShare(String token, boolean confirmed) {
        RegistrationProfile viewer = profile();
        SportsTeamInvitation located = TenantHelper.ignore(() -> locateShare(token));
        return locked(located.getTeamId(), () -> {
            SportsTeamInvitation source = locateShare(token);
            SportsTeam team = requireTeam(source.getTeamId());
            SportsTeamMember current = activeMember(team.getId(), viewer.personId());
            Long used = invitationMapper.selectCount(Wrappers.<SportsTeamInvitation>lambdaQuery()
                .eq(SportsTeamInvitation::getShareInvitationId, source.getId())
                .eq(SportsTeamInvitation::getTargetPersonId, viewer.personId()));
            TeamShareRules.requireAccept(shareStatus(source, team), used != null && used > 0, current != null, confirmed);
            if (current != null) return new ShareJoinCard(team.getId(), team.getName(), true);
            SportsTeamInvitation accepted = new SportsTeamInvitation();
            accepted.setTeamId(team.getId()); accepted.setInviterAccountId(source.getInviterAccountId());
            accepted.setInviterPersonId(source.getInviterPersonId()); accepted.setTargetPersonId(viewer.personId());
            accepted.setInvitationKind("direct"); accepted.setShareInvitationId(source.getId()); accepted.setStatus("accepted"); accepted.setVersion(0);
            invitationMapper.insert(accepted);
            insertMember(team.getId(), viewer.personId(), "member", "invitation");
            invalidatePersonPending(team.getId(), viewer.personId(), null, accepted.getId());
            invitationNoticeApi.created("team-joined", accepted.getId(), 0, source.getInviterAccountId(), "新队员已加入",
                viewer.legalName() + "已确认加入“" + team.getName() + "”。", "/portal/teams/" + team.getId(), false);
            return new ShareJoinCard(team.getId(), team.getName(), false);
        });
    }

    private SportsTeamInvitation currentShare(Long teamId) {
        return invitationMapper.selectOne(Wrappers.<SportsTeamInvitation>lambdaQuery()
            .eq(SportsTeamInvitation::getTeamId, teamId).eq(SportsTeamInvitation::getInvitationKind, "share")
            .eq(SportsTeamInvitation::getStatus, "pending"));
    }

    private SportsTeamInvitation locateShare(String token) {
        SportsTeamInvitation row = invitationMapper.selectOne(Wrappers.<SportsTeamInvitation>lambdaQuery()
            .eq(SportsTeamInvitation::getInvitationKind, "share").eq(SportsTeamInvitation::getInviteToken, TeamShareRules.token(token)));
        if (row == null) throw new ServiceException("邀请链接无效，请向队长获取新的链接");
        return row;
    }

    private String shareStatus(SportsTeamInvitation row, SportsTeam team) {
        boolean inviterActive = row.getInviterPersonId() != null && row.getInviterPersonId().equals(team.getCaptainPersonId())
            && captain(team, row.getInviterPersonId())
            && platformAccountApi.memberLabels(List.of(row.getInviterPersonId())).stream()
                .anyMatch(label -> row.getInviterAccountId().equals(label.accountId()) && label.selectable());
        return TeamShareRules.status(row.getStatus(), "active".equals(team.getStatus()), inviterActive, row.getExpiresAt(), now());
    }

    private ShareLinkCard shareLinkCard(SportsTeamInvitation row) {
        return new ShareLinkCard(row.getId(), "/portal/teams/join/" + row.getInviteToken(), row.getExpiresAt());
    }

    private void invalidateShareLinks(Long teamId) {
        for (SportsTeamInvitation row : invitationMapper.selectList(Wrappers.<SportsTeamInvitation>lambdaQuery()
            .eq(SportsTeamInvitation::getTeamId, teamId).eq(SportsTeamInvitation::getInvitationKind, "share")
            .eq(SportsTeamInvitation::getStatus, "pending"))) {
            row.setStatus("revoked");
            saved(invitationMapper.updateById(row), "邀请已被更新，请再试一次");
        }
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.team.teamservice.accept",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public TeamHome accept(Long invitationId) {
        return answerInvitation(invitationId, "accepted");
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.team.teamservice.decline",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public TeamHome decline(Long invitationId) {
        return answerInvitation(invitationId, "declined");
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.team.teamservice.revoke",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public TeamDetail revoke(Long invitationId) {
        RegistrationProfile profile = profile();
        SportsTeamInvitation located = TenantHelper.ignore(() -> invitationMapper.selectById(invitationId));
        if (located == null) {
            throw new ServiceException("邀请不存在");
        }
        return locked(located.getTeamId(), () -> {
            SportsTeamInvitation invitation = invitationMapper.selectById(invitationId);
            SportsTeam team = requireTeam(invitation.getTeamId());
            TeamRules.requireActive("active".equals(team.getStatus()));
            TeamRules.requireCaptain(captain(team, profile.personId()));
            if (!"pending".equals(invitation.getStatus())) {
                throw new ServiceException("邀请不存在");
            }
            invitation.setStatus("revoked");
            saved(invitationMapper.updateById(invitation), "邀请已被更新，请再试一次");
            return detailOf(team.getId(), profile.personId());
        });
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.team.teamservice.leave",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public TeamHome leave(Long teamId) {
        RegistrationProfile profile = profile();
        return locked(teamId, () -> {
            SportsTeam team = requireTeam(teamId);
            SportsTeamMember member = activeMember(teamId, profile.personId());
            TeamRules.requireLeave("active".equals(team.getStatus()), member == null ? "" : member.getRole());
            responsibilities.requireTeamChange(teamId, profile.personId(), false);
            endMember(member, "member_left");
            return homeOf(profile.personId());
        });
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.team.teamservice.remove",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public TeamDetail remove(Long teamId, Long memberId) {
        RegistrationProfile profile = profile();
        return locked(teamId, () -> {
            SportsTeam team = requireTeam(teamId);
            SportsTeamMember target = memberMapper.selectById(memberId);
            if (target == null || !teamId.equals(target.getTeamId()) || !"active".equals(target.getStatus())) {
                throw new ServiceException("队员不存在");
            }
            TeamRules.requireRemove("active".equals(team.getStatus()), captain(team, profile.personId()), target.getRole());
            endMember(target, "captain_removed");
            // 通知使用已授权队员对应的本人账号，不包含其他队员或正式报名的敏感信息。
            for (MemberLabel label : platformAccountApi.memberLabels(List.of(target.getPersonId()))) {
                if (label.accountId() != null) invitationNoticeApi.created("team-member-removed", target.getId(), target.getVersion(),
                    label.accountId(), "队伍成员变更", "队长已将你移出“" + team.getName() + "”。此前正式报名名单不随退队自动改变。",
                    "/portal/teams", false);
            }
            return detailOf(teamId, profile.personId());
        });
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.team.teamservice.transfer",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public TeamDetail transfer(Long teamId, Long memberId) {
        RegistrationProfile profile = profile();
        return locked(teamId, () -> {
            SportsTeam team = requireTeam(teamId);
            SportsTeamMember target = memberMapper.selectById(memberId);
            boolean targetActive = target != null && teamId.equals(target.getTeamId()) && "active".equals(target.getStatus());
            boolean targetCaptain = targetActive && "captain".equals(target.getRole());
            TeamRules.requireTransfer("active".equals(team.getStatus()), captain(team, profile.personId()), targetActive, targetCaptain);
            responsibilities.requireTeamChange(teamId, profile.personId(), false);
            SportsTeamMember actor = activeMember(teamId, profile.personId());
            Long previousCaptain = team.getCaptainPersonId();
            actor.setRole("member");
            saved(memberMapper.updateById(actor), "队伍已被更新，请再试一次");
            target.setRole("captain");
            saved(memberMapper.updateById(target), "队伍已被更新，请再试一次");
            team.setCaptainPersonId(target.getPersonId());
            saved(teamMapper.updateById(team), "队伍已被更新，请再试一次");
            invalidateShareLinks(teamId);
            history(teamId, "transfer", "转让队长", team.getName(), team.getStatus(), previousCaptain,
                team.getName(), team.getStatus(), target.getPersonId());
            return detailOf(teamId, profile.personId());
        });
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.team.teamservice.disband",title="兼容业务办理",reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_history","asp_team_invitation","asp_team_join_request","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public TeamHome disband(Long teamId) {
        RegistrationProfile profile = profile();
        return locked(teamId, () -> {
            SportsTeam team = requireTeam(teamId);
            TeamRules.requireActive("active".equals(team.getStatus()));
            TeamRules.requireCaptain(captain(team, profile.personId()));
            responsibilities.requireTeamChange(teamId, profile.personId(), true);
            for (SportsTeamMember member : activeMembers(teamId)) {
                endMember(member, "team_disbanded");
            }
            invalidatePending(teamId);
            String previous = team.getStatus();
            team.setStatus("disbanded");
            saved(teamMapper.updateById(team), "队伍已被更新，请再试一次");
            history(teamId, "disband", "解散队伍", team.getName(), previous, team.getCaptainPersonId(),
                team.getName(), "disbanded", team.getCaptainPersonId());
            return homeOf(profile.personId());
        });
    }

    public Optional<ActiveTeam> findActive(Long teamId) {
        return TenantHelper.ignore(() -> {
            SportsTeam team = teamMapper.selectById(teamId);
            if (team == null || !"active".equals(team.getStatus())) {
                return Optional.empty();
            }
            return Optional.of(new ActiveTeam(team.getId(), team.getName(), team.getCaptainPersonId()));
        });
    }

    public boolean isActiveCaptain(Long teamId, Long personId) {
        return TenantHelper.ignore(() -> captain(teamMapper.selectById(teamId), personId));
    }

    public boolean containsActiveMembers(Long teamId, List<Long> personIds) {
        if (personIds == null || personIds.isEmpty()) {
            return true;
        }
        return TenantHelper.ignore(() -> {
            for (Long personId : personIds) {
                if (activeMember(teamId, personId) == null) {
                    return false;
                }
            }
            return true;
        });
    }

    public boolean containsActiveAccounts(Long teamId, List<Long> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return true;
        }
        return TenantHelper.ignore(() -> {
            Map<Long, MemberLabel> byAccount = new HashMap<>();
            for (MemberLabel label : labels(activeMembers(teamId))) {
                if (label.accountId() != null) {
                    byAccount.put(label.accountId(), label);
                }
            }
            for (Long accountId : accountIds) {
                MemberLabel label = byAccount.get(accountId);
                if (label == null || !label.selectable()) {
                    return false;
                }
            }
            return true;
        });
    }

    public List<Long> activeCaptainTeamIds(Long personId) {
        if (personId == null) {
            return List.of();
        }
        return TenantHelper.ignore(() -> {
            List<SportsTeamMember> captains = memberMapper.selectList(Wrappers.<SportsTeamMember>lambdaQuery()
                .eq(SportsTeamMember::getPersonId, personId)
                .eq(SportsTeamMember::getRole, "captain")
                .eq(SportsTeamMember::getStatus, "active"));
            if (captains.isEmpty()) {
                return List.of();
            }
            List<Long> teamIds = captains.stream().map(SportsTeamMember::getTeamId).toList();
            return teamMapper.selectList(Wrappers.<SportsTeam>lambdaQuery()
                    .in(SportsTeam::getId, teamIds)
                    .eq(SportsTeam::getStatus, "active"))
                .stream().map(SportsTeam::getId).toList();
        });
    }

    public void requireSubmittable(Long teamId, Long captainPersonId, List<Long> personIds) {
        TeamRules.requireTeamSubmit(findActive(teamId).isPresent(), isActiveCaptain(teamId, captainPersonId),
            containsActiveMembers(teamId, personIds));
    }

    private TeamDetail decideRequest(Long requestId, String decision, String reason) {
        RegistrationProfile profile = profile();
        SportsTeamJoinRequest located = TenantHelper.ignore(() -> requestMapper.selectById(requestId));
        if (located == null) {
            throw new ServiceException("申请不存在");
        }
        boolean[] invalidated = {false};
        TeamDetail detail = locked(located.getTeamId(), () -> {
            SportsTeamJoinRequest request = requestMapper.selectById(requestId);
            SportsTeam team = requireTeam(request.getTeamId());
            TeamRules.requireActive("active".equals(team.getStatus()));
            TeamRules.requireCaptain(captain(team, profile.personId()));
            if (!"pending".equals(request.getStatus())) {
                throw new ServiceException("申请不存在");
            }
            if (activeMember(team.getId(), request.getPersonId()) != null) {
                request.setStatus("invalidated");
                saved(requestMapper.updateById(request), "申请已被更新，请再试一次");
                invalidated[0] = true;
                return detailOf(team.getId(), profile.personId());
            }
            if ("approved".equals(decision)) {
                insertMember(team.getId(), request.getPersonId(), "member", "application");
                invalidatePersonPending(team.getId(), request.getPersonId(), request.getId(), null);
            }
            request.setStatus(decision);
            request.setReviewerAccountId(profile.accountId());
            request.setReason(reason);
            saved(requestMapper.updateById(request), "申请已被更新，请再试一次");
            return detailOf(team.getId(), profile.personId());
        });
        if (invalidated[0]) {
            throw new ServiceException("对方已经在队伍里");
        }
        return detail;
    }

    private TeamHome answerInvitation(Long invitationId, String decision) {
        RegistrationProfile profile = profile();
        SportsTeamInvitation located = TenantHelper.ignore(() -> invitationMapper.selectById(invitationId));
        if (located == null || !profile.personId().equals(located.getTargetPersonId())) {
            throw new ServiceException("邀请不存在");
        }
        boolean[] invalidated = {false};
        TeamHome home = locked(located.getTeamId(), () -> {
            SportsTeamInvitation invitation = invitationMapper.selectById(invitationId);
            SportsTeam team = requireTeam(invitation.getTeamId());
            TeamRules.requireActive("active".equals(team.getStatus()));
            if (!"pending".equals(invitation.getStatus()) || !profile.personId().equals(invitation.getTargetPersonId())) {
                throw new ServiceException("邀请不存在");
            }
            if ("accepted".equals(decision) && activeMember(team.getId(), profile.personId()) != null) {
                invitation.setStatus("invalidated");
                saved(invitationMapper.updateById(invitation), "邀请已被更新，请再试一次");
                invalidated[0] = true;
                return homeOf(profile.personId());
            }
            if ("accepted".equals(decision)) {
                insertMember(team.getId(), profile.personId(), "member", "invitation");
                invalidatePersonPending(team.getId(), profile.personId(), null, invitation.getId());
            }
            invitation.setStatus(decision);
            saved(invitationMapper.updateById(invitation), "邀请已被更新，请再试一次");
            return homeOf(profile.personId());
        });
        if (invalidated[0]) {
            throw new ServiceException("你已经在队伍里");
        }
        return home;
    }

    private TeamHome homeOf(Long personId) {
        List<SportsTeamMember> memberships = memberMapper.selectList(Wrappers.<SportsTeamMember>lambdaQuery()
            .eq(SportsTeamMember::getPersonId, personId)
            .orderByDesc(SportsTeamMember::getId));
        List<SportsTeamJoinRequest> mine = requestMapper.selectList(Wrappers.<SportsTeamJoinRequest>lambdaQuery()
            .eq(SportsTeamJoinRequest::getPersonId, personId)
            .eq(SportsTeamJoinRequest::getStatus, "pending"));
        List<SportsTeamInvitation> invitations = invitationMapper.selectList(Wrappers.<SportsTeamInvitation>lambdaQuery()
            .eq(SportsTeamInvitation::getTargetPersonId, personId)
            .eq(SportsTeamInvitation::getStatus, "pending"));
        List<Long> captainTeams = activeCaptainTeamIdsInside(personId);
        List<SportsTeamJoinRequest> incoming = captainTeams.isEmpty() ? List.of() : requestMapper.selectList(Wrappers.<SportsTeamJoinRequest>lambdaQuery()
            .in(SportsTeamJoinRequest::getTeamId, captainTeams)
            .eq(SportsTeamJoinRequest::getStatus, "pending"));
        Map<Long, SportsTeam> teams = loadTeams(idsOf(memberships, mine, invitations, incoming));
        return new TeamHome(membershipCards(memberships, teams), applicationCards(mine, teams),
            invitationCards(invitations, teams), applicationCards(incoming, teams));
    }

    private List<Long> activeCaptainTeamIdsInside(Long personId) {
        List<SportsTeamMember> captains = memberMapper.selectList(Wrappers.<SportsTeamMember>lambdaQuery()
            .eq(SportsTeamMember::getPersonId, personId)
            .eq(SportsTeamMember::getRole, "captain")
            .eq(SportsTeamMember::getStatus, "active"));
        if (captains.isEmpty()) {
            return List.of();
        }
        List<Long> teamIds = captains.stream().map(SportsTeamMember::getTeamId).toList();
        return teamMapper.selectList(Wrappers.<SportsTeam>lambdaQuery()
                .in(SportsTeam::getId, teamIds)
                .eq(SportsTeam::getStatus, "active"))
            .stream().map(SportsTeam::getId).toList();
    }

    private TeamDetail detailOf(Long teamId, Long personId) {
        SportsTeam team = requireTeam(teamId);
        List<SportsTeamMember> mine = memberMapper.selectList(Wrappers.<SportsTeamMember>lambdaQuery()
            .eq(SportsTeamMember::getTeamId, teamId)
            .eq(SportsTeamMember::getPersonId, personId));
        if (mine.isEmpty()) {
            throw new ServiceException("队伍不存在");
        }
        SportsTeamMember self = mine.stream().filter(member -> "active".equals(member.getStatus())).findFirst()
            .orElse(null);
        if (self == null) {
            throw new ServiceException("你已经不在这支队伍里");
        }
        boolean isCaptain = captain(team, personId);
        List<SportsTeamMember> members = memberMapper.selectList(Wrappers.<SportsTeamMember>lambdaQuery()
            .eq(SportsTeamMember::getTeamId, teamId));
        members.sort(Comparator.comparing((SportsTeamMember member) -> !"active".equals(member.getStatus()))
            .thenComparing(SportsTeamMember::getId));
        Map<Long, MemberLabel> labels = labelByPerson(members);
        List<MemberCard> cards = new ArrayList<>();
        for (SportsTeamMember member : members) {
            MemberLabel label = labels.get(member.getPersonId());
            cards.add(new MemberCard(member.getId(), member.getPersonId(), label == null ? null : label.accountId(),
                label == null ? "队员" : label.legalName(), member.getRole(), member.getStatus(), member.getEndReason(),
                label != null && label.selectable()));
        }
        List<ApplicationCard> applications = List.of();
        List<InvitationCard> invitations = List.of();
        if (isCaptain) {
            Map<Long, SportsTeam> teams = Map.of(team.getId(), team);
            applications = applicationCards(requestMapper.selectList(Wrappers.<SportsTeamJoinRequest>lambdaQuery()
                .eq(SportsTeamJoinRequest::getTeamId, teamId)
                .eq(SportsTeamJoinRequest::getStatus, "pending")), teams);
            invitations = invitationCards(invitationMapper.selectList(Wrappers.<SportsTeamInvitation>lambdaQuery()
                .eq(SportsTeamInvitation::getTeamId, teamId)
                .eq(SportsTeamInvitation::getInvitationKind, "direct")
                .eq(SportsTeamInvitation::getStatus, "pending")), teams);
        }
        return new TeamDetail(team.getId(), team.getName(), team.getStatus(), self.getRole(), self.getStatus(),
            self.getEndReason(), isCaptain, "active".equals(self.getStatus()) && "member".equals(self.getRole()), cards,
            applications, invitations);
    }

    private List<CandidateCard> candidateCards(List<SportsTeamMember> members) {
        Map<Long, MemberLabel> labels = labelByPerson(members);
        List<CandidateCard> cards = new ArrayList<>();
        for (SportsTeamMember member : members) {
            MemberLabel label = labels.get(member.getPersonId());
            if (label == null || label.accountId() == null) {
                continue;
            }
            cards.add(new CandidateCard(member.getPersonId(), label.accountId(), label.legalName(), member.getRole(), label.selectable()));
        }
        return cards;
    }

    private void insertMember(Long teamId, Long personId, String role, String source) {
        try {
            memberMapper.insert(newMember(teamId, personId, role, source));
        } catch (DataIntegrityViolationException exception) {
            throw new ServiceException("对方已经在队伍里");
        }
    }

    private SportsTeamMember newMember(Long teamId, Long personId, String role, String source) {
        SportsTeamMember member = new SportsTeamMember();
        member.setTeamId(teamId);
        member.setPersonId(personId);
        member.setRole(role);
        member.setStatus("active");
        member.setJoinSource(source);
        member.setJoinedAt(now());
        member.setVersion(0);
        return member;
    }

    private void endMember(SportsTeamMember member, String reason) {
        member.setStatus("ended");
        member.setEndReason(reason);
        member.setLeftAt(now());
        saved(memberMapper.updateById(member), "队伍已被更新，请再试一次");
    }

    private void invalidatePending(Long teamId) {
        for (SportsTeamJoinRequest request : requestMapper.selectList(Wrappers.<SportsTeamJoinRequest>lambdaQuery()
            .eq(SportsTeamJoinRequest::getTeamId, teamId)
            .eq(SportsTeamJoinRequest::getStatus, "pending"))) {
            request.setStatus("invalidated");
            saved(requestMapper.updateById(request), "申请已被更新，请再试一次");
        }
        for (SportsTeamInvitation invitation : invitationMapper.selectList(Wrappers.<SportsTeamInvitation>lambdaQuery()
            .eq(SportsTeamInvitation::getTeamId, teamId)
            .eq(SportsTeamInvitation::getStatus, "pending"))) {
            invitation.setStatus("invalidated");
            saved(invitationMapper.updateById(invitation), "邀请已被更新，请再试一次");
        }
    }

    private void invalidatePersonPending(Long teamId, Long personId, Long keepRequestId, Long keepInvitationId) {
        for (SportsTeamJoinRequest request : requestMapper.selectList(Wrappers.<SportsTeamJoinRequest>lambdaQuery()
            .eq(SportsTeamJoinRequest::getTeamId, teamId)
            .eq(SportsTeamJoinRequest::getPersonId, personId)
            .eq(SportsTeamJoinRequest::getStatus, "pending"))) {
            if (request.getId().equals(keepRequestId)) {
                continue;
            }
            request.setStatus("invalidated");
            saved(requestMapper.updateById(request), "申请已被更新，请再试一次");
        }
        for (SportsTeamInvitation invitation : invitationMapper.selectList(Wrappers.<SportsTeamInvitation>lambdaQuery()
            .eq(SportsTeamInvitation::getTeamId, teamId)
            .eq(SportsTeamInvitation::getTargetPersonId, personId)
            .eq(SportsTeamInvitation::getStatus, "pending"))) {
            if (invitation.getId().equals(keepInvitationId)) {
                continue;
            }
            invitation.setStatus("invalidated");
            saved(invitationMapper.updateById(invitation), "邀请已被更新，请再试一次");
        }
    }

    private void history(Long teamId, String action, String reason, String beforeName, String beforeStatus, Long beforeCaptain,
                         String afterName, String afterStatus, Long afterCaptain) {
        SportsTeamHistory history = new SportsTeamHistory();
        history.setTeamId(teamId);
        history.setAction(action);
        history.setBeforeSnapshot(snapshot(beforeName, beforeStatus, beforeCaptain));
        history.setAfterSnapshot(snapshot(afterName, afterStatus, afterCaptain));
        history.setReason(reason);
        history.setEffectiveAt(now());
        history.setVersion(0);
        historyMapper.insert(history);
    }

    private String snapshot(String name, String status, Long captainPersonId) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("name", name);
        body.put("status", status);
        body.put("captainPersonId", captainPersonId);
        try {
            return objectMapper.writeValueAsString(body);
        } catch (JsonProcessingException exception) {
            throw new ServiceException("队伍变更无法保存");
        }
    }

    private boolean pending(Long teamId, Long personId) {
        Long requests = requestMapper.selectCount(Wrappers.<SportsTeamJoinRequest>lambdaQuery()
            .eq(SportsTeamJoinRequest::getTeamId, teamId)
            .eq(SportsTeamJoinRequest::getPersonId, personId)
            .eq(SportsTeamJoinRequest::getStatus, "pending"));
        Long invitations = invitationMapper.selectCount(Wrappers.<SportsTeamInvitation>lambdaQuery()
            .eq(SportsTeamInvitation::getTeamId, teamId)
            .eq(SportsTeamInvitation::getTargetPersonId, personId)
            .eq(SportsTeamInvitation::getStatus, "pending"));
        return (requests != null && requests > 0) || (invitations != null && invitations > 0);
    }

    private boolean captain(SportsTeam team, Long personId) {
        if (team == null || personId == null || !"active".equals(team.getStatus()) || !personId.equals(team.getCaptainPersonId())) {
            return false;
        }
        SportsTeamMember member = activeMember(team.getId(), personId);
        return member != null && "captain".equals(member.getRole());
    }

    private SportsTeamMember activeMember(Long teamId, Long personId) {
        if (teamId == null || personId == null) {
            return null;
        }
        return memberMapper.selectOne(Wrappers.<SportsTeamMember>lambdaQuery()
            .eq(SportsTeamMember::getTeamId, teamId)
            .eq(SportsTeamMember::getPersonId, personId)
            .eq(SportsTeamMember::getStatus, "active"));
    }

    private List<SportsTeamMember> activeMembers(Long teamId) {
        return memberMapper.selectList(Wrappers.<SportsTeamMember>lambdaQuery()
            .eq(SportsTeamMember::getTeamId, teamId)
            .eq(SportsTeamMember::getStatus, "active")
            .orderByAsc(SportsTeamMember::getId));
    }

    private List<MemberLabel> labels(List<SportsTeamMember> members) {
        return platformAccountApi.memberLabels(members.stream().map(SportsTeamMember::getPersonId).distinct().toList());
    }

    private Map<Long, MemberLabel> labelByPerson(List<SportsTeamMember> members) {
        Map<Long, MemberLabel> labels = new HashMap<>();
        for (MemberLabel label : labels(members)) {
            labels.put(label.personId(), label);
        }
        return labels;
    }

    private SportsTeam requireTeam(Long teamId) {
        SportsTeam team = teamMapper.selectById(teamId);
        if (team == null) {
            throw new ServiceException("队伍不存在");
        }
        return team;
    }

    private Long badmintonId() {
        TeamSportCatalog sport = sportMapper.selectOne(Wrappers.<TeamSportCatalog>lambdaQuery()
            .eq(TeamSportCatalog::getCode, "badminton")
            .eq(TeamSportCatalog::getStatus, "active"));
        if (sport == null) {
            throw new ServiceException("羽毛球目录未初始化");
        }
        return sport.getId();
    }

    private Map<Long, SportsTeam> loadTeams(List<Long> ids) {
        if (ids.isEmpty()) {
            return Map.of();
        }
        Map<Long, SportsTeam> teams = new HashMap<>();
        for (SportsTeam team : teamMapper.selectList(Wrappers.<SportsTeam>lambdaQuery().in(SportsTeam::getId, ids))) {
            teams.put(team.getId(), team);
        }
        return teams;
    }

    private List<Long> idsOf(List<SportsTeamMember> memberships, List<SportsTeamJoinRequest> mine,
                             List<SportsTeamInvitation> invitations, List<SportsTeamJoinRequest> incoming) {
        List<Long> ids = new ArrayList<>();
        memberships.forEach(row -> ids.add(row.getTeamId()));
        mine.forEach(row -> ids.add(row.getTeamId()));
        invitations.forEach(row -> ids.add(row.getTeamId()));
        incoming.forEach(row -> ids.add(row.getTeamId()));
        return ids.stream().distinct().toList();
    }

    private List<MembershipCard> membershipCards(List<SportsTeamMember> memberships, Map<Long, SportsTeam> teams) {
        List<MembershipCard> cards = new ArrayList<>();
        for (SportsTeamMember member : memberships) {
            SportsTeam team = teams.get(member.getTeamId());
            if (team == null) {
                continue;
            }
            cards.add(new MembershipCard(team.getId(), team.getName(), team.getStatus(), member.getRole(), member.getStatus(), member.getEndReason()));
        }
        return cards;
    }

    private List<ApplicationCard> applicationCards(List<SportsTeamJoinRequest> requests, Map<Long, SportsTeam> teams) {
        List<ApplicationCard> cards = new ArrayList<>();
        Map<Long, MemberLabel> labels = labelByPersonIds(requests.stream().map(SportsTeamJoinRequest::getPersonId).toList());
        for (SportsTeamJoinRequest request : requests) {
            SportsTeam team = teams.get(request.getTeamId());
            MemberLabel label = labels.get(request.getPersonId());
            cards.add(new ApplicationCard(request.getId(), request.getTeamId(), team == null ? "" : team.getName(),
                request.getStatus(), label == null ? "申请人" : label.legalName()));
        }
        return cards;
    }

    private List<InvitationCard> invitationCards(List<SportsTeamInvitation> invitations, Map<Long, SportsTeam> teams) {
        List<InvitationCard> cards = new ArrayList<>();
        Map<Long, MemberLabel> labels = labelByPersonIds(invitations.stream().map(SportsTeamInvitation::getTargetPersonId).toList());
        for (SportsTeamInvitation invitation : invitations) {
            SportsTeam team = teams.get(invitation.getTeamId());
            MemberLabel label = labels.get(invitation.getTargetPersonId());
            cards.add(new InvitationCard(invitation.getId(), invitation.getTeamId(), team == null ? "" : team.getName(),
                invitation.getStatus(), label == null ? "受邀人" : label.legalName(), label == null || label.accountId() == null ? null : invitationNoticeApi.delivery("team-invite", invitation.getId(), label.accountId())));
        }
        return cards;
    }

    private Map<Long, MemberLabel> labelByPersonIds(List<Long> personIds) {
        Map<Long, MemberLabel> labels = new HashMap<>();
        for (MemberLabel label : platformAccountApi.memberLabels(personIds)) {
            labels.put(label.personId(), label);
        }
        return labels;
    }

    private <T> T locked(Long teamId, java.util.function.Supplier<T> action) {
        return TenantHelper.ignore(() -> mutualLock.execute("team:" + teamId, WAIT_MILLIS, LEASE_MILLIS,
            () -> transaction().execute(status -> {
                if (teamMapper.lockTeam(teamId) == null) throw new ServiceException("队伍不存在");
                return action.get();
            })));
    }

    private void saved(int updated, String message) {
        if (updated != 1) {
            throw new ServiceException(message);
        }
    }

    private RegistrationProfile profile() {
        return platformAccountApi.currentRegistrationProfile().orElseThrow(() -> new ServiceException("请先完善本人档案"));
    }

    private TransactionTemplate transaction() {
        TransactionTemplate template = new TransactionTemplate(transactionManager);
        template.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRED);
        return template;
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

    private String blankToNull(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        String trimmed = value.trim();
        if (trimmed.length() > 500) {
            throw new ServiceException("处理依据不超过500字");
        }
        return trimmed;
    }

    public record MembershipCard(Long teamId, String name, String teamStatus, String role, String membershipStatus, String endReason) {
    }

    public record ApplicationCard(Long id, Long teamId, String teamName, String status, String personName) {
    }

    public record InvitationCard(Long id, Long teamId, String teamName, String status, String personName, InvitationNoticeApi.Status notice) {
    }

    public record TeamHome(List<MembershipCard> memberships, List<ApplicationCard> myApplications,
                           List<InvitationCard> myInvitations, List<ApplicationCard> incomingApplications) {
    }

    public record MemberCard(Long id, Long personId, Long accountId, String legalName, String role, String status,
                             String endReason, boolean selectable) {
    }

    public record TeamDetail(Long id, String name, String status, String myRole, String myMembershipStatus, String myEndReason,
                             boolean captain, boolean canLeave, List<MemberCard> members, List<ApplicationCard> applications,
                             List<InvitationCard> invitations) {
    }

    public record CandidateCard(Long personId, Long accountId, String legalName, String role, boolean selectable) {
    }

    public record PreviewCard(Long id, String name, String status) {
    }

    public record ShareLinkCard(Long id, String path, OffsetDateTime expiresAt) { }
    public record SharePreviewCard(Long teamId, String teamName, String status, OffsetDateTime expiresAt) { }
    public record ShareJoinCard(Long teamId, String teamName, boolean alreadyMember) { }
    public record ShareConfirmationCard(Long teamId, String teamName, String status, OffsetDateTime expiresAt, boolean currentMember, boolean previouslyUsed) { }
}
