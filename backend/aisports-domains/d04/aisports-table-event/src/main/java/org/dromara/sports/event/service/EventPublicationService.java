package org.dromara.sports.event.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import lombok.RequiredArgsConstructor;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.CompetitionSetupApi;
import org.dromara.sports.api.FeeApi;
import org.dromara.sports.api.FeeApi.PublicUnitPrice;
import org.dromara.sports.api.OrganizationQualificationApi;
import org.dromara.sports.api.OrganizationQualificationApi.OrganizerContact;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.api.StoredObjectApi;
import org.dromara.sports.api.OrganizationSessionApi.ManagedOrganization;
import org.dromara.sports.event.EventPhaseCalculator;
import org.dromara.sports.event.domain.SportsAiTask;
import org.dromara.sports.event.domain.SportsEvent;
import org.dromara.sports.event.domain.SportsEventCommand;
import org.dromara.sports.event.domain.SportsEventPoster;
import org.dromara.sports.event.mapper.SportsAiTaskMapper;
import org.dromara.sports.event.mapper.SportsEventCommandMapper;
import org.dromara.sports.event.mapper.SportsEventMapper;
import org.dromara.sports.event.mapper.SportsEventPosterMapper;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;

/**
 * 羽毛球赛事公开。组织内读写停在当前租户；公开列表显式跨租户后再按准入过滤。
 */
@Service
@RequiredArgsConstructor
public class EventPublicationService {

    public static final String PUBLISH = "publish";
    public static final String REFUND_NOTE = "退款由承办方人工登记，系统不自动退款。赛事取消后，未到账的报名不再应付；已到账的款项由承办方办理退款或确认无需退款。";
    private static final ZoneOffset SHANGHAI = ZoneOffset.ofHours(8);
    private static final DateTimeFormatter LOCAL_TIME = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private final ObjectMapper objectMapper;
    private final SportsEventMapper eventMapper;
    private final SportsEventCommandMapper commandMapper;
    private final OrganizationSessionApi sessionApi;
    private final OrganizationQualificationApi qualificationApi;
    private final EventCancellationNoticeService cancellationNoticeService;
    private final FeeApi feeApi;
    private final StoredObjectApi storedObjectApi;
    private final CompetitionSetupApi competitionSetupApi;
    private final SportsEventPosterMapper posterMapper;
    private final SportsAiTaskMapper aiTaskMapper;

    /** 删除从未发布、且没有报名、占用或资金历史的办赛草稿；未使用的收费配置随草稿清理。 */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.event.event_publication_service.delete_draft", title="EventPublicationService.deleteDraft", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional(rollbackFor = Exception.class)
    public void deleteDraft(Long eventId) {
        ManagedOrganization organization = requireOrganizer();
        // 与收费配置、正式提交及外键引用串行；取得锁后重新核对归属和草稿状态。
        SportsEvent event = eventMapper.selectOne(Wrappers.<SportsEvent>lambdaQuery()
            .eq(SportsEvent::getId, eventId).last("FOR UPDATE"));
        if (event == null || !organization.organizationId().equals(event.getOrganizationId())
            || !organization.tenantId().equals(event.getTenantId())) {
            throw new ServiceException("赛事不存在或不在当前组织范围内");
        }
        if (!"draft".equals(event.getPublicationStatus()) || !"normal".equals(event.getHoldingStatus())) {
            throw new ServiceException("只有未发布的办赛草稿可以删除");
        }
        Long commands = commandMapper.selectCount(Wrappers.<SportsEventCommand>lambdaQuery()
            .eq(SportsEventCommand::getEventId, eventId));
        if (commands != null && commands > 0) {
            throw new ServiceException("已经办理过发布，不能按草稿删除");
        }
        competitionSetupApi.discardEmptyDraftUnits(eventId);
        posterMapper.delete(Wrappers.<SportsEventPoster>lambdaQuery().eq(SportsEventPoster::getEventId, eventId));
        List<SportsAiTask> tasks = aiTaskMapper.selectList(Wrappers.<SportsAiTask>lambdaQuery()
            .eq(SportsAiTask::getResultObjectId, eventId));
        if (tasks != null) {
            for (SportsAiTask task : tasks) {
                task.setStatus("ABANDONED");
                task.setResultObjectId(null);
                task.setExtraction(null);
                task.setProposal(null);
                if (aiTaskMapper.updateById(task) != 1) {
                    throw new ServiceException("办赛草稿刚被更新，请刷新后再删除");
                }
            }
        }
        if (eventMapper.deleteById(eventId) != 1) {
            throw new ServiceException("办赛草稿刚被更新，请刷新后再删除");
        }
    }

    public List<EventCard> listManaged() {
        ManagedOrganization organization = requireOrganizer();
        List<SportsEvent> events = eventMapper.selectList(Wrappers.<SportsEvent>lambdaQuery()
            .eq(SportsEvent::getOrganizationId, organization.organizationId())
            .orderByDesc(SportsEvent::getCreateTime)
            .orderByDesc(SportsEvent::getId));
        return events.stream().map(event -> toCard(event, true)).toList();
    }

    public EventCard managed(Long eventId) {
        return toCard(requireOwned(requireOrganizer(), eventId), true);
    }

    /** Current owned state for the assistant card; reading this never makes a draft editable. */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.event.ai_created_draft_state",title="读取当前赛事草稿状态",reads={"asp_event","asp_event_command","asp_organization","asp_staff_grant","asp_account_tenant_principal","asp_account","asp_registration","asp_capacity_pool","asp_competition_unit","asp_competition_type","asp_sport","asp_fee_obligation","asp_fee_policy","asp_checkin","asp_stage"},writes={})
    @Transactional(rollbackFor=Exception.class)
    public AiDraftState aiDraftState(Long eventId) {
        var organization=requireOrganizer();SportsEvent event=eventMapper.selectOne(Wrappers.<SportsEvent>lambdaQuery().eq(SportsEvent::getId,eventId).last("FOR UPDATE"));
        if(event==null||!organization.organizationId().equals(event.getOrganizationId())||!organization.tenantId().equals(event.getTenantId()))throw new ServiceException("赛事不存在");
        boolean editable="draft".equals(event.getPublicationStatus())&&"normal".equals(event.getHoldingStatus())&&Integer.valueOf(0).equals(event.getPublishedRevision())&&!Boolean.TRUE.equals(event.getRegistrationReviewLocked())&&!hasPublishHistory(eventId);
        if(editable){try{competitionSetupApi.currentDraftUnits(eventId);}catch(ServiceException used){editable=false;}}
        return new AiDraftState(toCard(event,true),event.getVersion(),editable);
    }

    /** UI-only existing-draft transaction. Event first, then the task, to match deletion's lock order. */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.event.ai_created_draft_update",title="保存同一赛事的聊天草稿",reads={"asp_event","asp_event_command","asp_ai_task","asp_ai_task_file","asp_ai_invocation","asp_file","asp_organization","asp_staff_grant","asp_account_tenant_principal","asp_account","asp_registration","asp_capacity_pool","asp_competition_unit","asp_competition_type","asp_sport","asp_fee_obligation","asp_fee_policy","asp_event_payment_config","asp_checkin","asp_stage"},writes={"asp_event","asp_ai_task","asp_competition_unit","asp_capacity_pool","asp_fee_policy","asp_file"})
    @Transactional(rollbackFor=Exception.class)
    public <T> T withUnusedAiDraft(Long eventId,java.util.function.Function<AiDraftState,T> write) {
        ManagedOrganization organization=requireOrganizer();
        SportsEvent event=eventMapper.selectOne(Wrappers.<SportsEvent>lambdaQuery().eq(SportsEvent::getId,eventId).last("FOR UPDATE"));
        if(event==null||!organization.organizationId().equals(event.getOrganizationId())||!organization.tenantId().equals(event.getTenantId()))throw new ServiceException("赛事不存在或不在当前组织范围内",403);
        Long history=commandMapper.selectCount(Wrappers.<SportsEventCommand>lambdaQuery().eq(SportsEventCommand::getEventId,eventId));
        if(!"draft".equals(event.getPublicationStatus())||!"normal".equals(event.getHoldingStatus())||!Integer.valueOf(0).equals(event.getPublishedRevision())||Boolean.TRUE.equals(event.getRegistrationReviewLocked())||history!=null&&history>0)throw new ServiceException("只有从未发布、没有正式报名的同一赛事草稿可以继续在聊天中修改",409);
        // This contract independently rejects any registration, occupancy or execution history.
        competitionSetupApi.currentDraftUnits(eventId);
        return write.apply(new AiDraftState(toCard(event,true),event.getVersion(),true));
    }

    public record AiDraftState(EventCard event,Integer version,boolean draftEditable) {
        public AiDraftState(EventCard event,Integer version){this(event,version,event!=null&&"draft".equals(event.publicationStatus())&&"normal".equals(event.holdingStatus()));}
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.event.event_publication_service.create",capability="event.create", title="EventPublicationService.create", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional(rollbackFor = Exception.class)
    public EventCard create(EventDraft draft) {
        ManagedOrganization organization = requireOrganizer();
        // 暂停只限制新增办赛；历史查询、取消、资金和投诉仍沿用原岗位授权。
        if (!qualificationApi.isCertified(organization.tenantId(), organization.organizationId())) {
            throw new ServiceException("办赛资格已暂停，不能新建赛事；已有赛事请继续办理收尾");
        }
        SportsEvent event = newEvent(organization);
        applyDraft(event, draft);
        applyMaterials(event, draft, organization, true);
        applyReview(event, draft == null ? null : draft.registrationReview(), true);
        eventMapper.insert(event);
        return toCard(event, true);
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.event.event_publication_service.update",capability="event.update", title="EventPublicationService.update", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional(rollbackFor = Exception.class)
    public EventCard update(Long eventId, EventDraft draft) {
        ManagedOrganization organization = requireOrganizer();
        SportsEvent event = requireOwned(organization, eventId);
        if ("published".equals(event.getPublicationStatus())) {
            throw new ServiceException("已发布的赛事不能直接修改，请先下架");
        }
        if (!"normal".equals(event.getHoldingStatus())) {
            throw new ServiceException("已取消的赛事不能修改");
        }
        if (!"draft".equals(event.getPublicationStatus()) && !"offline".equals(event.getPublicationStatus())) {
            throw new ServiceException("当前赛事不能修改");
        }
        applyDraft(event, draft);
        applyMaterials(event, draft, organization, false);
        if (eventMapper.updateById(event) != 1) {
            throw new ServiceException("赛事已被更新，请刷新后再保存");
        }
        return toCard(event, true);
    }

    /**
     * 已发布的赛事仍可改审核方式，直到出现第一笔正式提交。
     */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.event.event_publication_service.change_review", title="EventPublicationService.changeReview", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional(rollbackFor = Exception.class)
    public EventCard changeReview(Long eventId, String registrationReview) {
        SportsEvent event = requireOwned(requireOrganizer(), eventId);
        if (!"normal".equals(event.getHoldingStatus())) {
            throw new ServiceException("已取消的赛事不能修改审核方式");
        }
        applyReview(event, registrationReview, false);
        if (eventMapper.updateById(event) != 1) {
            throw new ServiceException("赛事已被更新，请刷新后再保存");
        }
        return toCard(event, true);
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.event.event_publication_service.publish",capability="event.publish", title="EventPublicationService.publish", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional(rollbackFor = Exception.class)
    public EventCard publish(Long eventId, String requestKey, boolean contactConfirmed, String contactName, String contactMethod) {
        return publish(eventId,requestKey,contactConfirmed,contactName,contactMethod,null,null);
    }

    /** The chat's explicit publication confirmation is bound to the actual event and project-price preview. */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.event.publication_preview_confirm",capability="event.publish",title="发布已核对赛事",reads={"asp_event","asp_event_command","asp_organization","asp_organization_application","asp_staff_grant","asp_account_tenant_principal","asp_account","asp_competition_unit","asp_capacity_pool","asp_competition_type","asp_sport","asp_fee_policy","asp_event_payment_config","asp_file"},writes={"asp_event","asp_event_command"})
    @Transactional(rollbackFor=Exception.class)
    public EventCard publish(Long eventId,String requestKey,boolean contactConfirmed,String contactName,String contactMethod,Integer expectedVersion,String expectedPreviewHash){
        ManagedOrganization organization = requireOrganizer();
        String key = requiredKey(requestKey);
        SportsEventCommand existing = commandMapper.selectOne(Wrappers.<SportsEventCommand>lambdaQuery()
            .eq(SportsEventCommand::getAction, PUBLISH)
            .eq(SportsEventCommand::getRequestKey, key));
        if (existing != null) {
            if (!eventId.equals(existing.getEventId())) {
                throw new ServiceException("这个请求已经发布过另一场赛事");
            }
            return toCard(requireOwned(organization, eventId), true);
        }
        SportsEvent event=eventMapper.selectOne(Wrappers.<SportsEvent>lambdaQuery().eq(SportsEvent::getId,eventId).last("FOR UPDATE"));
        if(event==null||!organization.organizationId().equals(event.getOrganizationId())||!organization.tenantId().equals(event.getTenantId()))throw new ServiceException("赛事不存在");
        if(expectedVersion!=null&&!java.util.Objects.equals(expectedVersion,event.getVersion()))throw new ServiceException("赛事已在核对后更新，请重新查看发布信息并确认",409);
        OrganizerContact publicationDefaults=qualificationApi.publicContact(event.getTenantId(),event.getOrganizationId());
        if(expectedPreviewHash!=null&&!expectedPreviewHash.equals(publicationPreviewHash(event,feeApi.publicUnitPrices(event.getTenantId(),eventId),publicationDefaults)))throw new ServiceException("项目、费用或公开信息已在核对后更新，请重新查看发布信息并确认",409);
        List<String> errors = publishErrors(organization, event);
        if (!errors.isEmpty()) {
            throw new ServiceException(String.join("；", errors));
        }
        if (!contactConfirmed) throw new ServiceException("发布前请确认同意公开赛事联系信息");
        OrganizerContact frozen = frozenContact(event);
        if (frozen != null && (!frozen.contactName().equals(optional(contactName, 100, "公开联系人"))
            || !frozen.contactMethod().equals(optional(contactMethod, 240, "公开联系方式")))) {
            throw new ServiceException("已发布的联系信息已冻结，恢复公开请沿用原联系信息");
        }
        if (frozen == null) {
            OrganizerContact defaults = publicationDefaults;
            String name = optional(contactName, 100, "公开联系人");
            String method = optional(contactMethod, 240, "公开联系方式");
            if (defaults == null || blank(defaults.organizationName()) || name == null || method == null) {
                throw new ServiceException("请确认承办组织、公开联系人及联系方式");
            }
            try {
                event.setContactSnapshot(objectMapper.writeValueAsString(Map.of("organizationId", event.getOrganizationId(),
                    "organizationName", defaults.organizationName(), "contactName", name, "contactMethod", method,
                    "state", "confirmed", "refundTerms", EventPublicationTerms.refund(objectMapper,event.getContactSnapshot(),REFUND_NOTE),
                    "confirmedAt", OffsetDateTime.now(SHANGHAI).toString())));
            } catch (java.io.IOException exception) { throw new ServiceException("联系信息无法保存，赛事未发布"); }
        }
        event.setPublicationStatus("published");
        if (eventMapper.updateById(event) != 1) {
            throw new ServiceException("赛事已被更新，请刷新后再发布");
        }
        SportsEventCommand command = new SportsEventCommand();
        command.setTenantId(organization.tenantId());
        command.setEventId(event.getId());
        command.setAction(PUBLISH);
        command.setRequestKey(key);
        command.setVersion(0);
        try {
            commandMapper.insert(command);
        } catch (DuplicateKeyException exception) {
            throw new ServiceException("发布请求正在处理，请再提交一次");
        }
        return toCard(event, true);
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.event.event_publication_service.offline", title="EventPublicationService.offline", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional(rollbackFor = Exception.class)
    public EventCard offline(Long eventId) {
        ManagedOrganization organization = requireOrganizer();
        SportsEvent event = requireOwned(organization, eventId);
        if (!"published".equals(event.getPublicationStatus()) || !"normal".equals(event.getHoldingStatus())) {
            throw new ServiceException("只有已发布且未取消的赛事可以下架");
        }
        String phase = currentPhase(event);
        if (!EventPhaseCalculator.PUBLISHABLE.contains(phase)) {
            throw new ServiceException("比赛已经开始或结束，不能下架");
        }
        event.setPublicationStatus("offline");
        if (eventMapper.updateById(event) != 1) {
            throw new ServiceException("赛事已被更新，请刷新后再下架");
        }
        return toCard(event, true);
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.event.event_publication_service.cancel", title="EventPublicationService.cancel", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional(rollbackFor = Exception.class)
    public EventCard cancel(Long eventId, String reason) {
        ManagedOrganization organization = requireOrganizer();
        SportsEvent event = requireOwned(organization, eventId);
        boolean published = "published".equals(event.getPublicationStatus());
        boolean republishableOffline = "offline".equals(event.getPublicationStatus()) && hasPublishHistory(event.getId());
        if (!published && !republishableOffline) {
            throw new ServiceException("只有已发布或曾发布后下架的赛事可以取消");
        }
        if (!"normal".equals(event.getHoldingStatus())) {
            throw new ServiceException("赛事已经取消");
        }
        if (EventPhaseCalculator.FINISHED.equals(currentPhase(event))) {
            throw new ServiceException("比赛已经结束，不能取消");
        }
        event.setHoldingStatus("cancelled");
        event.setCancelReason(optional(reason, 1000, "取消原因"));
        if (eventMapper.updateById(event) != 1) {
            throw new ServiceException("赛事已被更新，请刷新后再取消");
        }
        feeApi.settleCancellation(event.getTenantId(), event.getId());
        cancellationNoticeService.notifyCancelled(event);
        return toCard(event, true);
    }

    /**
     * 专用公开查询。显式忽略调用方租户，再只留下已发布且组织仍准入的赛事。
     */
    public List<EventCard> listPublic() {
        List<SportsEvent> published = TenantHelper.ignore(() -> eventMapper.selectList(Wrappers.<SportsEvent>lambdaQuery()
            .eq(SportsEvent::getPublicationStatus, "published")
            .orderByAsc(SportsEvent::getStartsAt)
            .orderByAsc(SportsEvent::getId)));
        List<EventCard> visible = new ArrayList<>();
        for (SportsEvent event : published) {
            if (qualificationApi.isCertified(event.getTenantId(), event.getOrganizationId())) {
                visible.add(toCard(event, false));
            }
        }
        return visible;
    }

    public PublicEventSearch.Page searchPublic(PublicEventSearch.Query query) {
        return PublicEventSearch.search(listPublic(), query);
    }

    public EventCard findPublic(Long eventId) {
        SportsEvent event = TenantHelper.ignore(() -> eventMapper.selectById(eventId));
        if (event == null || !"published".equals(event.getPublicationStatus())
            || !qualificationApi.isCertified(event.getTenantId(), event.getOrganizationId())) {
            throw new ServiceException("赛事不存在或未公开");
        }
        return toCard(event, false);
    }

    /**
     * 公开页读取宣传图或说明图片。只认这场赛事上记下的文件，不接受任意文件编号。
     */
    /** 仅组织管理用途预览；未公开赛事也可核对同源价格，但不开放匿名访问。 */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.event.publication_preview",title="核对赛事发布信息",reads={"asp_event","asp_organization","asp_organization_application","asp_staff_grant","asp_account_tenant_principal","asp_account","asp_competition_unit","asp_capacity_pool","asp_competition_type","asp_sport","asp_fee_policy","asp_event_payment_config","asp_file"},writes={})
    @Transactional(rollbackFor=Exception.class)
    public PublicFeeView previewFees(Long eventId) {
        var organization=requireOrganizer();
        SportsEvent event=eventMapper.selectOne(Wrappers.<SportsEvent>lambdaQuery().eq(SportsEvent::getId,eventId).last("FOR UPDATE"));
        if(event==null||!organization.organizationId().equals(event.getOrganizationId())||!organization.tenantId().equals(event.getTenantId()))throw new ServiceException("赛事不存在");
        OrganizerContact contact = frozenContact(event);
        OrganizerContact publicationDefaults=qualificationApi.publicContact(event.getTenantId(),event.getOrganizationId());
        boolean frozen = contact != null;
        if (contact == null) {
            OrganizerContact defaults = publicationDefaults;
            var candidate = EventPublicationTerms.read(objectMapper,event.getContactSnapshot());
            contact = new OrganizerContact(defaults == null ? null : defaults.organizationName(),
                EventPublicationTerms.text(candidate,"contactName") == null ? (defaults == null ? null : defaults.contactName()) : EventPublicationTerms.text(candidate,"contactName"),
                EventPublicationTerms.text(candidate,"contactMethod") == null ? (defaults == null ? null : defaults.contactMethod()) : EventPublicationTerms.text(candidate,"contactMethod"));
        }
        var units=feeApi.publicUnitPrices(event.getTenantId(),eventId);
        return new PublicFeeView(contact.organizationName(), contact.contactName(), contact.contactMethod(), EventPublicationTerms.refund(objectMapper,event.getContactSnapshot(),REFUND_NOTE), units, frozen,event.getVersion(),publicationPreviewHash(event,units,publicationDefaults));
    }

    /** Includes stable business values only. Row locking in publish protects this comparison from concurrent draft writes. */
    private String publicationPreviewHash(SportsEvent event,List<PublicUnitPrice> units){return publicationPreviewHash(event,units,qualificationApi.publicContact(event.getTenantId(),event.getOrganizationId()));}
    private String publicationPreviewHash(SportsEvent event,List<PublicUnitPrice> units,OrganizerContact defaults){
        var node=objectMapper.createObjectNode();
        node.put("eventId",Long.toString(event.getId()));node.put("version",event.getVersion());
        node.put("name",event.getName());node.put("location",event.getLocation());node.put("projectName",event.getProjectName());node.put("feeDescription",event.getFeeDescription());
        node.put("publicationStatus",event.getPublicationStatus());node.put("holdingStatus",event.getHoldingStatus());node.put("registrationReview",event.getRegistrationReview());
        node.put("registrationOpensAt",event.getRegistrationOpensAt()==null?null:event.getRegistrationOpensAt().toInstant().toString());node.put("registrationClosesAt",event.getRegistrationClosesAt()==null?null:event.getRegistrationClosesAt().toInstant().toString());node.put("startsAt",event.getStartsAt()==null?null:event.getStartsAt().toInstant().toString());node.put("endsAt",event.getEndsAt()==null?null:event.getEndsAt().toInstant().toString());
        node.put("contactSnapshot",event.getContactSnapshot());node.put("rulesText",event.getRulesText());node.put("noticeText",event.getNoticeText());node.put("declarationText",event.getDeclarationText());node.put("routeText",event.getRouteText());node.put("declarationAckRequired",Boolean.TRUE.equals(event.getDeclarationAckRequired()));
        node.put("bannerFileId",event.getBannerFileId());node.put("rulesFileId",event.getRulesFileId());node.put("noticeFileId",event.getNoticeFileId());node.put("declarationFileId",event.getDeclarationFileId());node.put("routeFileId",event.getRouteFileId());
        if(defaults!=null)node.set("organizationPublicContact",objectMapper.valueToTree(defaults));
        node.put("eventPaymentReady",feeApi.eventPaymentReady(event.getTenantId(),event.getId()));
        node.put("eventPaymentRevision",feeApi.eventPaymentRevision(event.getTenantId(),event.getId()));
        node.set("projectDirectory",objectMapper.valueToTree(competitionSetupApi.publicationUnits(event.getId())));
        var prices=node.putArray("units");units.stream().sorted(java.util.Comparator.comparing(PublicUnitPrice::unitId)).forEach(price->{var row=prices.addObject().put("unitId",Long.toString(price.unitId())).put("name",price.unitName()).put("paymentMode",price.paymentMode()).put("instruction",price.payInstruction());if(price.amount()==null)row.putNull("amount");else row.put("amount",price.amount().stripTrailingZeros().toPlainString());});
        try{return java.util.HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(node.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8)));}catch(java.security.NoSuchAlgorithmException impossible){throw new IllegalStateException(impossible);}
    }
    public PublicFeeView publicFees(Long eventId) {
        SportsEvent event = TenantHelper.ignore(() -> eventMapper.selectById(eventId));
        if (event == null || !"published".equals(event.getPublicationStatus())
            || !qualificationApi.isCertified(event.getTenantId(), event.getOrganizationId())) {
            throw new ServiceException("赛事不存在或未公开");
        }
        // 历史公开赛事无已确认快照时展示待补，不能把组织当前资料伪装为旧发布依据。
        OrganizerContact contact = frozenContact(event);
        if (contact == null) contact = new OrganizerContact(null, null, null);
        List<PublicUnitPrice> units = feeApi.publicUnitPrices(event.getTenantId(), event.getId());
        return new PublicFeeView(contact.organizationName(), contact.contactName(), contact.contactMethod(),
            frozenContact(event) == null ? REFUND_NOTE : EventPublicationTerms.refund(objectMapper,event.getContactSnapshot(),REFUND_NOTE), units, frozenContact(event) != null);
    }

    private OrganizerContact frozenContact(SportsEvent event) {
        try {
            var json = objectMapper.readTree(event.getContactSnapshot() == null ? "{}" : event.getContactSnapshot());
            if (json == null || !json.isObject()) return null;
            if (EventPublicationTerms.isDraft(json)) return null;
            if (!event.getOrganizationId().toString().equals(json.path("organizationId").asText())
                || blank(json.path("organizationName").asText()) || blank(json.path("contactName").asText())
                || blank(json.path("contactMethod").asText())) return null;
            return new OrganizerContact(json.path("organizationName").asText(), json.path("contactName").asText(), json.path("contactMethod").asText());
        } catch (java.io.IOException exception) { return null; }
    }

    public StoredObjectApi.ImageBody publicMedia(Long eventId, String slot) {
        SportsEvent event = TenantHelper.ignore(() -> eventMapper.selectById(eventId));
        if (event == null || !"published".equals(event.getPublicationStatus())
            || !qualificationApi.isCertified(event.getTenantId(), event.getOrganizationId())) {
            return null;
        }
        Long fileId = mediaFileId(event, slot);
        if (fileId == null) {
            return null;
        }
        return storedObjectApi.read(fileId);
    }

    private boolean hasPublishHistory(Long eventId) {
        Long count = commandMapper.selectCount(Wrappers.<SportsEventCommand>lambdaQuery()
            .eq(SportsEventCommand::getEventId, eventId)
            .eq(SportsEventCommand::getAction, PUBLISH));
        return count != null && count > 0;
    }

    /** 助手只读预检复用正式发布规则，不替代事务内复验或公开联系信息同意。 */
    public ManagedReadiness readiness(Long eventId) {
        var organization = requireOrganizer();
        var event = requireOwned(organization, eventId);
        var issues = new ArrayList<>(publishErrors(organization, event));
        boolean published = "published".equals(event.getPublicationStatus());
        if (published) issues.remove("只有草稿或已下架的赛事可以发布");
        var units = feeApi.publicUnitPrices(event.getTenantId(), eventId);
        if (units.isEmpty()) issues.add("还没有竞赛项目，请在项目与费用中建立项目、报名名额和价格");
        if (frozenContact(event) == null) issues.add("首次发布还需明确同意公开赛事联系人和联系方式");
        String next = issues.isEmpty() ? (published ? "赛事已公开；请按当前报名、资格和资金待办继续办理" : "请到发布管理核对信息并明确确认发布") : issues.get(0);
        return new ManagedReadiness(published, issues.isEmpty(), List.copyOf(issues), units, next);
    }
    public record ManagedReadiness(boolean published, boolean readyForPublicationReview, List<String> issues, List<PublicUnitPrice> projectPrices, String nextStep) { }

    private List<String> publishErrors(ManagedOrganization organization, SportsEvent event) {
        List<String> errors = new ArrayList<>();
        if (!"draft".equals(event.getPublicationStatus()) && !"offline".equals(event.getPublicationStatus())) {
            errors.add("只有草稿或已下架的赛事可以发布");
        }
        if (!qualificationApi.isCertified(organization.tenantId(), organization.organizationId())) {
            errors.add("组织尚未开放办赛");
        }
        if (!"normal".equals(event.getHoldingStatus())) {
            errors.add("已取消的赛事不能发布");
        }
        if (!"badminton".equals(event.getSportCode())) {
            errors.add("本期只能发布羽毛球赛事");
        }
        if (blank(event.getName())) {
            errors.add("请填写赛事名称");
        }
        if (blank(event.getLocation())) {
            errors.add("请填写比赛地点");
        }
        if (blank(event.getProjectName())) {
            errors.add("请填写赛事项目");
        }
        if (blank(event.getFeeDescription())) {
            errors.add("请填写收费方式或收费说明");
        }
        if (event.getRegistrationOpensAt() == null || event.getRegistrationClosesAt() == null
            || event.getStartsAt() == null || event.getEndsAt() == null) {
            errors.add("请填写报名时间和比赛时间");
        } else if (!EventPhaseCalculator.ordered(event.getRegistrationOpensAt(), event.getRegistrationClosesAt(),
            event.getStartsAt(), event.getEndsAt())) {
            errors.add("时间必须是报名开始早于报名结束，报名结束不晚于开赛，开赛早于结束");
        } else {
            String phase = currentPhase(event);
            boolean restore = "offline".equals(event.getPublicationStatus()) && hasPublishHistory(event.getId());
            if (EventPhaseCalculator.FINISHED.equals(phase)) {
                errors.add("比赛已经结束，不能发布");
            } else if (!restore && !EventPhaseCalculator.PUBLISHABLE.contains(phase)) {
                errors.add("比赛已经开始或结束，不能发布");
            }
        }
        List<PublicUnitPrice> units = feeApi.publicUnitPrices(event.getTenantId(), event.getId());
        if (units.isEmpty()) {
            errors.add("请先设置至少一个比赛项目、参赛人数和报名名额，再发布赛事");
        }
        if (units.stream()
            .anyMatch(unit -> unit.amount() == null || unit.paymentMode() == null)) {
            errors.add("报名项目的费用尚未确认，请在项目与费用中明确免费或配置收费后发布");
        }
        if (units.stream().anyMatch(unit -> "event".equals(unit.paymentMode()))
            && !feeApi.eventPaymentReady(event.getTenantId(), event.getId())) {
            errors.add("收费项目尚无赛事收款渠道，请在赛事设置中配置微信、支付宝、银行或线下付款后发布");
        }
        return errors;
    }

    private SportsEvent newEvent(ManagedOrganization organization) {
        SportsEvent event = new SportsEvent();
        event.setTenantId(organization.tenantId());
        event.setOrganizationId(organization.organizationId());
        event.setSportCode("badminton");
        event.setPublicationStatus("draft");
        event.setHoldingStatus("normal");
        event.setStatus("draft");
        event.setRegistrationStatus("closed");
        event.setPaymentStatus("disabled");
        event.setVisibility("private");
        event.setPublishedRevision(0);
        event.setContactSnapshot("{}");
        event.setRegistrationReview("manual");
        event.setRegistrationReviewLocked(false);
        event.setVersion(0);
        return event;
    }

    private void applyDraft(SportsEvent event, EventDraft draft) {
        // 已提交者确认的是当时的时间、地点、组别和收费承诺，不能借下架绕过冻结。
        if (Boolean.TRUE.equals(event.getRegistrationReviewLocked())
            && (!java.util.Objects.equals(event.getLocation(), optional(draft == null ? null : draft.location(), 200, "比赛地点"))
                || !java.util.Objects.equals(event.getProjectName(), optional(draft == null ? null : draft.projectName(), 200, "赛事项目"))
                || !java.util.Objects.equals(event.getFeeDescription(), optional(draft == null ? null : draft.feeDescription(), 1000, "收费说明"))
                || !sameMoment(event.getRegistrationOpensAt(), parseTime(draft == null ? null : draft.registrationOpensAt()))
                || !sameMoment(event.getRegistrationClosesAt(), parseTime(draft == null ? null : draft.registrationClosesAt()))
                || !sameMoment(event.getStartsAt(), parseTime(draft == null ? null : draft.startsAt()))
                || !sameMoment(event.getEndsAt(), parseTime(draft == null ? null : draft.endsAt())))) {
            throw new ServiceException("已有正式报名，不能变更报名或比赛时间、实际地点、比赛项目和收费承诺；确需调整请取消原赛事另建");
        }
        event.setName(optional(draft == null ? null : draft.name(), 200, "赛事名称"));
        event.setLocation(optional(draft == null ? null : draft.location(), 200, "比赛地点"));
        event.setProjectName(optional(draft == null ? null : draft.projectName(), 200, "赛事项目"));
        event.setFeeDescription(optional(draft == null ? null : draft.feeDescription(), 1000, "收费说明"));
        event.setContactSnapshot(EventPublicationTerms.draft(objectMapper,event.getContactSnapshot(),event.getOrganizationId(),
            draft == null || draft.contactName() == null ? null : optional(draft.contactName(),100,"赛事联系人"),
            draft == null || draft.contactMethod() == null ? null : optional(draft.contactMethod(),240,"赛事联系方式"),
            draft == null || draft.refundTerms() == null ? null : optional(draft.refundTerms(),4000,"退改说明")));
        event.setRegistrationOpensAt(parseTime(draft == null ? null : draft.registrationOpensAt()));
        event.setRegistrationClosesAt(parseTime(draft == null ? null : draft.registrationClosesAt()));
        event.setStartsAt(parseTime(draft == null ? null : draft.startsAt()));
        event.setEndsAt(parseTime(draft == null ? null : draft.endsAt()));
        if (event.getRegistrationOpensAt() != null && event.getRegistrationClosesAt() != null
            && event.getStartsAt() != null && event.getEndsAt() != null
            && !EventPhaseCalculator.ordered(event.getRegistrationOpensAt(), event.getRegistrationClosesAt(),
            event.getStartsAt(), event.getEndsAt())) {
            throw new ServiceException("时间必须是报名开始早于报名结束，报名结束不晚于开赛，开赛早于结束");
        }
        applyReview(event, draft == null ? null : draft.registrationReview(), false);
    }

    private boolean sameMoment(OffsetDateTime current, OffsetDateTime next) {
        return current == null ? next == null : next != null && current.isEqual(next);
    }

    private SportsEvent requireOwned(ManagedOrganization organization, Long eventId) {
        SportsEvent event = eventMapper.selectById(eventId);
        if (event == null || !organization.organizationId().equals(event.getOrganizationId())
            || !organization.tenantId().equals(event.getTenantId())) {
            throw new ServiceException("赛事不存在");
        }
        return event;
    }

    private ManagedOrganization requireOrganizer() {
        if (!org.dromara.sports.platform.core.BusinessIdentity.isLogin() || org.dromara.sports.platform.core.BusinessIdentity.getUserType() != UserType.SYS_USER) {
            throw new ServiceException("请先进入组织");
        }
        ManagedOrganization organization = sessionApi.managedOrganization(org.dromara.sports.platform.core.BusinessIdentity.getUserId())
            .orElseThrow(() -> new ServiceException("当前账号不能管理这个组织的赛事"));
        if (!organization.tenantId().equals(org.dromara.sports.platform.core.BusinessIdentity.getTenantId())) {
            throw new ServiceException("请先进入该组织");
        }
        return organization;
    }

    private EventCard toCard(SportsEvent event, boolean managed) {
        String phase = currentPhase(event);
        boolean editable = managed && "normal".equals(event.getHoldingStatus())
            && ("draft".equals(event.getPublicationStatus()) || "offline".equals(event.getPublicationStatus()));
        return new EventCard(event.getId(), event.getName(), event.getLocation(), event.getProjectName(), event.getFeeDescription(),
            event.getRegistrationOpensAt(), event.getRegistrationClosesAt(), event.getStartsAt(), event.getEndsAt(),
            event.getPublicationStatus(), event.getHoldingStatus(), phase, event.getCancelReason(), editable,
            event.getRegistrationReview() == null ? "manual" : event.getRegistrationReview(),
            Boolean.TRUE.equals(event.getRegistrationReviewLocked()),
            event.getBannerFileId(), event.getRulesText(), event.getRulesFileId(), event.getNoticeText(), event.getNoticeFileId(),
            event.getDeclarationText(), event.getDeclarationFileId(), event.getRouteText(), event.getRouteFileId(),
            Boolean.TRUE.equals(event.getDeclarationAckRequired()),
            EventPublicationTerms.text(EventPublicationTerms.read(objectMapper,event.getContactSnapshot()),"contactName"),
            EventPublicationTerms.text(EventPublicationTerms.read(objectMapper,event.getContactSnapshot()),"contactMethod"),
            EventPublicationTerms.text(EventPublicationTerms.read(objectMapper,event.getContactSnapshot()),"refundTerms"),event.getVersion());
    }

    private void applyMaterials(SportsEvent event, EventDraft draft, ManagedOrganization organization, boolean creating) {
        boolean locked = !creating && Boolean.TRUE.equals(event.getRegistrationReviewLocked());
        String rules = optional(draft == null ? null : draft.rulesText(), 4000, "竞赛规程");
        String notice = optional(draft == null ? null : draft.noticeText(), 4000, "报名须知");
        String declaration = optional(draft == null ? null : draft.declarationText(), 4000, "参赛声明");
        String route = optional(draft == null ? null : draft.routeText(), 4000, "比赛路线");
        Long rulesFile = draft == null ? null : draft.rulesFileId();
        Long noticeFile = draft == null ? null : draft.noticeFileId();
        Long declarationFile = draft == null ? null : draft.declarationFileId();
        Long routeFile = draft == null ? null : draft.routeFileId();
        if (locked && (differs(event.getRulesText(), rules) || differs(event.getNoticeText(), notice)
            || differs(event.getDeclarationText(), declaration) || differs(event.getRouteText(), route)
            || !sameId(event.getRulesFileId(), rulesFile) || !sameId(event.getNoticeFileId(), noticeFile)
            || !sameId(event.getDeclarationFileId(), declarationFile) || !sameId(event.getRouteFileId(), routeFile)
            || (draft != null && draft.declarationAckRequired() != null
                && draft.declarationAckRequired() != Boolean.TRUE.equals(event.getDeclarationAckRequired())))) {
            throw new ServiceException("已有正式报名，不能再改规程、须知、声明或路线");
        }
        event.setBannerFileId(bind(organization, draft == null ? null : draft.bannerFileId(), StoredObjectApi.EVENT_BANNER));
        event.setRulesText(rules);
        event.setRulesFileId(bind(organization, rulesFile, StoredObjectApi.EVENT_RULES));
        event.setNoticeText(notice);
        event.setNoticeFileId(bind(organization, noticeFile, StoredObjectApi.EVENT_NOTICE));
        event.setDeclarationText(declaration);
        event.setDeclarationFileId(bind(organization, declarationFile, StoredObjectApi.EVENT_DECLARATION));
        if (draft != null && draft.declarationAckRequired() != null) {
            event.setDeclarationAckRequired(draft.declarationAckRequired());
        } else if (creating) {
            event.setDeclarationAckRequired(false);
        }
        event.setRouteText(route);
        event.setRouteFileId(bind(organization, routeFile, StoredObjectApi.EVENT_ROUTE));
    }

    private Long bind(ManagedOrganization organization, Long fileId, String purpose) {
        if (fileId == null) {
            return null;
        }
        storedObjectApi.requireImage(fileId, purpose, organization.tenantId());
        return fileId;
    }

    private Long mediaFileId(SportsEvent event, String slot) {
        if ("banner".equals(slot)) {
            return event.getBannerFileId();
        }
        if ("rules".equals(slot)) {
            return event.getRulesFileId();
        }
        if ("notice".equals(slot)) {
            return event.getNoticeFileId();
        }
        if ("declaration".equals(slot)) {
            return event.getDeclarationFileId();
        }
        if ("route".equals(slot)) {
            return event.getRouteFileId();
        }
        throw new ServiceException("图片用途无效");
    }

    private boolean differs(String current, String next) {
        String left = current == null ? "" : current;
        String right = next == null ? "" : next;
        return !left.equals(right);
    }

    private boolean sameId(Long current, Long next) {
        return current == null ? next == null : current.equals(next);
    }

    private void applyReview(SportsEvent event, String requested, boolean creating) {
        String mode = requested == null || requested.isBlank() ? "manual" : requested.trim();
        if (!"manual".equals(mode) && !"none".equals(mode)) {
            throw new ServiceException("审核方式无效");
        }
        if (!creating && Boolean.TRUE.equals(event.getRegistrationReviewLocked()) && !mode.equals(event.getRegistrationReview())) {
            throw new ServiceException("已有正式报名，不能再改审核方式");
        }
        if (creating || !Boolean.TRUE.equals(event.getRegistrationReviewLocked())) {
            event.setRegistrationReview(mode);
        }
    }

    private String currentPhase(SportsEvent event) {
        return EventPhaseCalculator.phase(event.getRegistrationOpensAt(), event.getRegistrationClosesAt(),
            event.getStartsAt(), event.getEndsAt(), OffsetDateTime.now(SHANGHAI));
    }

    private String requiredKey(String requestKey) {
        String key = optional(requestKey, 128, "幂等键");
        if (key == null) {
            throw new ServiceException("请提供发布请求键");
        }
        return key;
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

    private boolean blank(String value) {
        return value == null || value.isBlank();
    }

    private OffsetDateTime parseTime(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        String text = value.trim();
        try {
            if (text.length() == 19) {
                return LocalDateTime.parse(text, LOCAL_TIME).atOffset(SHANGHAI);
            }
            return OffsetDateTime.parse(text);
        } catch (DateTimeParseException exception) {
            throw new ServiceException("时间格式应为 yyyy-MM-dd HH:mm:ss");
        }
    }

    public record PublicFeeView(String organizationName, String contactName, String contactMethod, String refundNote,
                                List<PublicUnitPrice> units, boolean contactFrozen,Integer eventVersion,String previewHash) {
        public PublicFeeView(String organizationName,String contactName,String contactMethod,String refundNote,List<PublicUnitPrice> units,boolean contactFrozen){this(organizationName,contactName,contactMethod,refundNote,units,contactFrozen,null,null);}
        public PublicFeeView(String organizationName, String contactName, String contactMethod, String refundNote, List<PublicUnitPrice> units) {
            this(organizationName, contactName, contactMethod, refundNote, units, false,null,null);
        }
    }

    public record EventDraft(String name, String location, String projectName, String feeDescription,
                             String registrationOpensAt, String registrationClosesAt, String startsAt, String endsAt,
                             String registrationReview, Long bannerFileId, String rulesText, Long rulesFileId,
                             String noticeText, Long noticeFileId, String declarationText, Long declarationFileId,
                             String routeText, Long routeFileId, Boolean declarationAckRequired,
                             String contactName, String contactMethod, String refundTerms) {
        public EventDraft(String name, String location, String projectName, String feeDescription,
                          String registrationOpensAt, String registrationClosesAt, String startsAt, String endsAt,
                          String registrationReview, Long bannerFileId, String rulesText, Long rulesFileId,
                          String noticeText, Long noticeFileId, String declarationText, Long declarationFileId,
                          String routeText, Long routeFileId, Boolean declarationAckRequired) {
            this(name,location,projectName,feeDescription,registrationOpensAt,registrationClosesAt,startsAt,endsAt,
                registrationReview,bannerFileId,rulesText,rulesFileId,noticeText,noticeFileId,declarationText,
                declarationFileId,routeText,routeFileId,declarationAckRequired,null,null,null);
        }
    }

    public record EventCard(Long id, String name, String location, String projectName, String feeDescription,
                            OffsetDateTime registrationOpensAt, OffsetDateTime registrationClosesAt,
                            OffsetDateTime startsAt, OffsetDateTime endsAt, String publicationStatus,
                            String holdingStatus, String phase, String cancelReason, boolean editable,
                            String registrationReview, boolean registrationReviewLocked,
                            Long bannerFileId, String rulesText, Long rulesFileId, String noticeText, Long noticeFileId,
                            String declarationText, Long declarationFileId, String routeText, Long routeFileId,
                            boolean declarationAckRequired, String contactName, String contactMethod, String refundTerms,Integer version) {
    }
}
