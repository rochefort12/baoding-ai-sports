package org.dromara.sports.event.ai;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.AiSceneToolApi;
import org.dromara.sports.api.CompetitionSetupApi;
import org.dromara.sports.api.DocumentKinds;
import org.dromara.sports.api.FeeApi;
import org.dromara.sports.api.OrganizationQualificationApi;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.api.OrganizationSessionApi.ManagedOrganization;
import org.dromara.sports.api.StoredObjectApi;
import org.dromara.sports.event.ai.LocalDocumentExtractor.Block;
import org.dromara.sports.event.ai.LocalDocumentExtractor.Extracted;
import org.dromara.sports.event.ai.SportsEventCallAiGatewayClient.CallNote;
import org.dromara.sports.event.ai.SportsEventCallAiGatewayClient.DiscussReply;
import org.dromara.sports.event.ai.SportsEventCallAiGatewayClient.DiscussTurn;
import org.dromara.sports.event.ai.SportsEventCallAiGatewayClient.Reply;
import org.dromara.sports.event.domain.SportsAiInvocation;
import org.dromara.sports.event.domain.SportsAiTask;
import org.dromara.sports.event.domain.SportsAiTaskFile;
import org.dromara.sports.event.mapper.SportsAiInvocationMapper;
import org.dromara.sports.event.mapper.SportsAiTaskFileMapper;
import org.dromara.sports.event.mapper.SportsAiTaskMapper;
import org.dromara.sports.event.service.EventPublicationService;
import org.dromara.sports.event.service.EventPublicationService.EventCard;
import org.dromara.sports.event.service.EventPublicationService.EventDraft;
import org.dromara.sports.event.service.EventPublicationService.AiDraftState;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.multipart.MultipartFile;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.concurrent.*;

/**
 * 资料建赛任务。解析和模型调用发生在事务外；确认时才和赛事、待配置费用的项目一起提交。
 */
@Service
public class SportsEventRunAiTaskService implements AiSceneToolApi {

    private static final ZoneId SHANGHAI = ZoneId.of("Asia/Shanghai");
    private static final String[] EVENT_FIELDS = {
        "name", "location", "projectName", "feeDescription",
        "registrationOpensAt", "registrationClosesAt", "startsAt", "endsAt",
        "registrationReview", "rulesText", "contactName", "contactMethod", "refundTerms", "declarationText"
    };

    private final SportsAiTaskMapper taskMapper;
    private final SportsAiTaskFileMapper fileMapper;
    private final SportsAiInvocationMapper invocationMapper;
    private final StoredObjectApi storedObjectApi;
    private final EventPublicationService eventService;
    private final CompetitionSetupApi competitionSetupApi;
    private final FeeApi feeApi;
    private final OrganizationQualificationApi qualificationApi;
    private final OrganizationSessionApi sessionApi;
    private final SportsEventAiProperties properties;
    private final SportsEventCallAiGatewayClient gatewayClient;
    private final ObjectMapper objectMapper;
    private final TransactionTemplate transactionTemplate;
    private final TransactionTemplate sourceTransactionTemplate;
    private final ThreadPoolExecutor recognitionWorkers=new ThreadPoolExecutor(2,2,0,TimeUnit.SECONDS,new ArrayBlockingQueue<>(16),r->{var t=new Thread(r,"sports-source-recognition");t.setDaemon(true);return t;});
    @jakarta.annotation.PreDestroy void closeRecognition(){recognitionWorkers.shutdownNow();}

    public SportsEventRunAiTaskService(SportsAiTaskMapper taskMapper, SportsAiTaskFileMapper fileMapper,
                                       SportsAiInvocationMapper invocationMapper, StoredObjectApi storedObjectApi,
                                       EventPublicationService eventService, CompetitionSetupApi competitionSetupApi,
                                       OrganizationSessionApi sessionApi, SportsEventAiProperties properties,
                                       SportsEventCallAiGatewayClient gatewayClient, ObjectMapper objectMapper,
                                       PlatformTransactionManager transactionManager, FeeApi feeApi,
                                       OrganizationQualificationApi qualificationApi) {
        this.taskMapper = taskMapper;
        this.fileMapper = fileMapper;
        this.invocationMapper = invocationMapper;
        this.storedObjectApi = storedObjectApi;
        this.eventService = eventService;
        this.competitionSetupApi = competitionSetupApi;
        this.feeApi = feeApi;
        this.qualificationApi = qualificationApi;
        this.sessionApi = sessionApi;
        this.properties = properties;
        this.gatewayClient = gatewayClient;
        this.objectMapper = objectMapper;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
        this.sourceTransactionTemplate = new TransactionTemplate(transactionManager);
        // The gateway reads sources through another authenticated HTTP request.
        // Commit file metadata + task + links together before that read begins,
        // even when the compatible upload action has an enclosing transaction.
        this.sourceTransactionTemplate.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.event.sportseventrunaitaskservice.upload",title="兼容业务办理",reads={"asp_file","asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_file","asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public TaskCard upload(MultipartFile[] files, boolean consent) {
        AiTaskPolicy.requireConsent(consent);
        ManagedOrganization organization = organizer();
        List<Prepared> prepared = prepare(files);
        long id = sourceTransactionTemplate.execute(status -> insertTask(organization, prepared));
        recognize(id);
        return get(id);
    }

    public TaskCard get(long taskId) {
        return toCard(requireOwn(taskId), filesOf(taskId));
    }

    public TaskCard appendMaterials(long taskId,MultipartFile[] files,boolean consent,Integer expectedVersion){
        if(!consent)throw new ServiceException("请同意将材料交给已配置模型识别",400);
        var added=prepare(files);var organization=organizer();
        sourceTransactionTemplate.executeWithoutResult(status->{
            requireOwn(taskId);taskMapper.lockById(taskId);var task=requireOwn(taskId);
            if(!Set.of("PENDING_CONFIRMATION","FAILED").contains(task.getStatus())||expectedVersion==null||!Objects.equals(task.getVersion(),expectedVersion))throw new ServiceException("请先等识别完成并重新读取草稿",409);
            try{
                var extraction=(ObjectNode)objectMapper.readTree(task.getExtraction());var inventory=(ArrayNode)extraction.path("files");
                long size=added.stream().mapToLong(p->p.body().length).sum();var hashes=new java.util.HashSet<String>();
                for(var file:inventory){if(file.path("fileId").asLong()==0)continue;byte[] original=storedObjectApi.readOwnedDocument(file.path("fileId").asLong(),organization.tenantId()).body();size+=original.length;hashes.add(java.util.HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(original)));}
                if(inventory.size()+added.size()>15||size>40*1024*1024)throw new ServiceException("一份草稿最多15份资料、合计40MB",400);
                for(var item:added){
                    String hash=java.util.HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(item.body()));if(!hashes.add(hash))continue;
                    int index=inventory.size();long fileId=storedObjectApi.keepDocument(organization.accountId(),organization.tenantId(),StoredObjectApi.AI_SOURCE,item.body());
                    var row=new SportsAiTaskFile();row.setTenantId(task.getTenantId());row.setTaskId(taskId);row.setFileId(fileId);row.setSortOrder(index);row.setMediaKind(item.extracted().mediaKind());row.setOriginalName(item.originalName());row.setPageCount(item.extracted().pageCount());row.setVersion(0);fileMapper.insert(row);
                    var file=inventory.addObject().put("fileIndex",index).put("fileId",Long.toString(fileId)).put("mediaKind",item.extracted().mediaKind()).put("originalName",item.originalName()).put("sourceSha256",hash);
                    file.set("visuals",visualInventory(item.extracted(),item.body()));file.set("scanPages",objectMapper.valueToTree(item.extracted().scanPages()));var blocks=file.putArray("blocks");for(var block:item.extracted().blocks())blocks.addObject().put("kind",block.kind()).put("label",block.label()).put("text",block.text());
                }
                task.setExtraction(extraction.toString());if(taskMapper.updateById(task)!=1)throw new ServiceException("草稿已更新，请重新读取",409);
            }catch(java.io.IOException|java.security.NoSuchAlgorithmException e){throw new ServiceException("补充材料无法解析");}
        });recognize(taskId,true);return get(taskId);
    }

    /** 粘贴的规程就是资料来源，随后和上传文件一样识别、对话、确认。 */
    public TaskCard startText(boolean consent, String text) {
        AiTaskPolicy.requireConsent(consent);
        String source = text == null ? "" : text.trim();
        if (source.isEmpty() || source.length() > 20000) {
            throw new ServiceException("请把规程贴在这里，不超过20000字");
        }
        ManagedOrganization organization = organizer();
        long id = sourceTransactionTemplate.execute(status -> insertPasted(organization, source));
        recognize(id);
        return get(id);
    }

    private void requireCurrentProviderConsent(SportsAiTask task) {
        if (!Boolean.TRUE.equals(task.getProviderConsent()) || !"deepseek".equalsIgnoreCase(task.getProviderName())) {
            throw new ServiceException("原任务的授权不包含当前 DeepSeek 服务。请保留原记录，并重新提交资料、阅读新授权后继续", 409);
        }
    }

    public TaskCard retry(long taskId) {
        SportsAiTask task = requireOwn(taskId);
        requireCurrentProviderConsent(task);
        if("PROCESSING".equals(task.getStatus()))throw new ServiceException("资料正在识别，请读取当前进度；无需重复重试",409);
        if ("CREATED".equals(task.getStatus()) || "ABANDONED".equals(task.getStatus())) {
            throw new ServiceException("当前任务不用重试");
        }
        boolean refresh = "PENDING_CONFIRMATION".equals(task.getStatus());
        if (refresh && !AiSourceRefreshPolicy.canRefresh(task.getProposal(), objectMapper)) {
            throw new ServiceException("草稿已有人工补充，请继续对话修改；重新识别不会覆盖您的修改");
        }
        recognize(taskId, refresh);
        return get(taskId);
    }

    public TalkReply talk(long taskId, TalkRequest request) {
        SportsAiTask task = requireOwn(taskId);
        requireCurrentProviderConsent(task);
        boolean existingDraft="CREATED".equals(task.getStatus());
        if (!"PENDING_CONFIRMATION".equals(task.getStatus())&&!existingDraft) {
            throw new ServiceException("请先完成识别，再继续说");
        }
        if (request == null || request.message() == null || request.message().isBlank()) {
            throw new ServiceException("请说一句");
        }
        String message = request.message().trim();
        if (message.length() > 500) {
            throw new ServiceException("单次办赛补充不超过500字，请分段发送；完整规程请作为新资料提交");
        }
        java.time.OffsetDateTime now = java.time.OffsetDateTime.now(SHANGHAI);
        if(request.expectedVersion()==null||!Objects.equals(task.getVersion(),request.expectedVersion()))throw new ServiceException("草稿已更新，请重新读取后继续；本次没有覆盖",409);
        if(existingDraft){
            AiDraftState state=eventService.aiDraftState(task.getResultObjectId());
            if(!"draft".equals(state.event().publicationStatus())||!"normal".equals(state.event().holdingStatus()))throw new ServiceException("赛事已经发布或结束草稿办理，不能继续修改这份办赛草稿",409);
            if(request.expectedVersion()==null||!Objects.equals(task.getVersion(),request.expectedVersion()))throw new ServiceException("草稿已更新，请重新读取后继续；本次没有覆盖",409);
        }
        if(message.matches("(?:请|确认)?(?:重新读取赛事草稿|读取赛事当前内容|重新核对实际赛事)[。！!]?")){
            if(!existingDraft)throw new ServiceException("请先建立未发布赛事，再读取同一赛事的当前内容",409);
            refreshCreatedCandidate(taskId,request.expectedVersion(),message);
            var current=get(taskId);return new TalkReply("已按实际赛事重新核对当前表单。上一版候选和原始资料已保留，您可以继续修改并保存。",List.of(),"update",current.proposal(),task.getResultObjectId(),false);
        }
        if(publishIntent(message)){
            if(!existingDraft){
                TalkReply created=confirmSpoken(taskId,task,"创建赛事",now,request.expectedVersion(),request.declarationAckRequired());
                if(!created.created())return created;
                return new TalkReply("赛事草稿已建立。请核对实际项目价格、退改说明和公开联系人，再明确确认发布。",List.of(),"publish",created.proposal(),created.eventId(),true);
            }
            boolean dirty=readProposal(task.getProposal()).path("createdDirty").asBoolean(false);
            return new TalkReply(dirty?"请先保存本轮修改，再核对实际项目价格、退改说明和公开联系人后确认发布。":"请核对实际项目价格、退改说明和公开联系人，再明确确认发布。",List.of(),"publish",viewProposal(task.getProposal()),task.getResultObjectId(),false);
        }
        if(existingDraft&&!readProposal(task.getProposal()).has("createdEventVersion"))throw new ServiceException("这份历史草稿尚未核对实际赛事版本，请点击读取赛事当前内容；原候选和资料会保留，本次没有覆盖",409);
        if(existingDraft&&(EventCreationConsent.allowed(message)||message.matches("(?:请|确认|确认并)?(?:保存|更新)(?:本轮|这次|当前|这些)?(?:修改|更改|赛事草稿)[。！!]?"))){
            ObjectNode source=readProposal(task.getProposal());
            TaskCard saved=editCandidate(taskId,new CandidateEdit(request.expectedVersion(),plainEvent(source),null,plainUnits(source),request.declarationAckRequired()));
            return new TalkReply("本轮修改已保存到同一场未发布赛事，赛事和项目编号保持。您可以继续补充，或核对后发布。",List.of(),"update",saved.proposal(),task.getResultObjectId(),false);
        }
        if (EventCreationConsent.allowed(message)) {
            return confirmSpoken(taskId, task, message, now, request.expectedVersion(), request.declarationAckRequired());
        }
        if (DraftChoices.askedToSave(message)) {
            AiDraftReadiness.Ready ready = AiDraftReadiness.check(draftOf(task.getProposal()), now);
            String reply = ready.canSaveDraft() ? "" : ready.blockingIssues().get(0).message();
            return speakLocal(taskId, task, message, reply, now, true);
        }
        DraftChoices.Turn applied = DraftChoices.tryApply(objectMapper, task.getProposal(), message, now);
        if (applied != null) {
            saveProposal(taskId, task.getProposal(), applied.proposal());
            SportsAiTask current=existingDraft?requireOwn(taskId):null;
            return new TalkReply(existingDraft?applied.reply()+"\n修改已放入当前表单，保存后更新这场赛事。":applied.reply(), applied.suggestions(), "update", viewProposal(existingDraft?current.getProposal():applied.proposal()), existingDraft?task.getResultObjectId():null, false);
        }
        DiscussReply agent = gatewayClient.discuss(taskId, task.getProposal(), dialogueOf(task.getProposal()), message);
        if (!agent.ok() || agent.agentJson() == null || agent.agentJson().isBlank()) {
            return new TalkReply(technicalNotice(agent.errorCode()), List.of(), "ask", task.getProposal(), null, false);
        }
        JsonNode answer;
        try { answer = objectMapper.readTree(agent.agentJson()); }
        catch (java.io.IOException exception) { throw new ServiceException("助手返回格式不正确，请重试；没有保存赛事"); }
        if ("create".equals(answer.path("action").asText()) && answer instanceof ObjectNode node) {
            node.put("action", "ask");
        }
        DraftMerge.Merged merged = DraftMerge.absorb(objectMapper, task.getProposal(), answer.toString(), message, false);
        DraftChoices.Turn turned = DraftChoices.finish(objectMapper, merged.proposal(), merged.reply(), message, java.time.OffsetDateTime.now(SHANGHAI), false);
        saveProposal(taskId, task.getProposal(), turned.proposal());
        SportsAiTask current=existingDraft?requireOwn(taskId):null;
        return new TalkReply(existingDraft?turned.reply()+"\n修改已放入当前表单，保存后更新这场赛事。":turned.reply(), turned.suggestions(), existingDraft?"update":"ask", viewProposal(existingDraft?current.getProposal():turned.proposal()), existingDraft?task.getResultObjectId():null, false);
    }

    private boolean publishIntent(String message){return message!=null&&message.trim().matches("(?:请|现在|直接|确认|确认并)?(?:发布|公开)(?:本次|这场|这个|当前)?(?:赛事草稿|比赛草稿|赛事|比赛|草稿)?(?:吧|了|即可|就行)?[。！!]?" );}

    private ObjectNode readProposal(String raw){try{return (ObjectNode)objectMapper.readTree(raw==null?"{}":raw);}catch(java.io.IOException|ClassCastException e){throw new ServiceException("草稿暂时无法读取");}}
    private ObjectNode plainEvent(ObjectNode proposal){var event=objectMapper.createObjectNode();for(String field:EVENT_FIELDS)event.put(field,proposal.path("event").path(field).path("value").asText(""));return event;}
    private ArrayNode plainUnits(ObjectNode proposal){var units=objectMapper.createArrayNode();for(var unit:proposal.path("units")){var copy=units.addObject();for(String field:List.of("name","entryType","limitCount","minMembers","maxMembers","feeAmount","feeBasis"))copy.put(field,unit.path(field).path("value").asText(""));}return units;}

    /** 明确确认直接保存；草稿还对不上时给出可点的改法，不再要求把同一句确认语打出来。 */
    private TalkReply confirmSpoken(long taskId, SportsAiTask task, String message, java.time.OffsetDateTime now, Integer expectedVersion, Boolean declarationAckRequired) {
        try {
            ConfirmDraft draft = draftOf(task.getProposal()).withConsent(expectedVersion,declarationAckRequired);
            ConfirmResult created = confirm(taskId, draft);
            return new TalkReply(AiFeeProposalPlan.present(draft.units())
                ? "赛事草稿和您确认的各项目整单价格已保存。请完善收款渠道，再核对时间、公开联系人与退改条件；保存不等于发布，也没有登记收款。"
                : "赛事草稿已保存。请到项目与费用明确免费或收费，再核对时间和发布条件；保存不等于发布。",
                List.of(), "create", viewProposal(task.getProposal()), created.eventId(), true);
        } catch (ServiceException exception) {
            AiDraftReadiness.Ready ready = AiDraftReadiness.check(draftOf(task.getProposal()), now);
            return speakLocal(taskId, task, message, exception.getMessage(), now, !ready.canSaveDraft());
        }
    }

    private TalkReply speakLocal(long taskId, SportsAiTask task, String message, String reply, java.time.OffsetDateTime now, boolean askedToSave) {
        ObjectNode note = objectMapper.createObjectNode();
        note.put("reply", reply == null || reply.isBlank() ? "我按目前的草稿继续。" : reply);
        note.put("action", "ask");
        DraftMerge.Merged merged = DraftMerge.absorb(objectMapper, task.getProposal(), note.toString(), message, false);
        DraftChoices.Turn turned = DraftChoices.finish(objectMapper, merged.proposal(), merged.reply(), message, now, askedToSave);
        saveProposal(taskId, task.getProposal(), turned.proposal());
        return new TalkReply(turned.reply(), turned.suggestions(), "ask", viewProposal(turned.proposal()), null, false);
    }

    private String technicalNotice(String code) {
        if ("MODEL_TIMEOUT".equals(code)) {
            return "这一句处理超时了，草稿没有改。请再发一次。";
        }
        if ("GATEWAY_UNAVAILABLE".equals(code) || "KEY_ABSENT".equals(code) || "INTERNAL_TOKEN_MISSING".equals(code)) {
            return "助手暂时连不上，草稿没有改。请再发一次。";
        }
        return "这一句没有处理完，草稿没有改。请再发一次。";
    }

    private void saveProposal(long taskId, String expectedProposal, String proposal) {
        SportsAiTask visible=requireOwn(taskId);
        if("CREATED".equals(visible.getStatus())){
            eventService.withUnusedAiDraft(visible.getResultObjectId(),state->{
                taskMapper.lockById(taskId);SportsAiTask current=requireOwn(taskId);
                if(!"CREATED".equals(current.getStatus())||!Objects.equals(expectedProposal,current.getProposal()))throw new ServiceException("草稿已更新，请重新读取后继续；本次没有覆盖",409);
                ObjectNode next=readProposal(proposal);
                bindCreatedBaseline(current,next,state);
                next.put("createdDirty",true);current.setProposal(next.toString());
                if(taskMapper.updateById(current)!=1)throw new ServiceException("草稿已更新，请重新读取",409);
                return null;
            });return;
        }
        transactionTemplate.executeWithoutResult(status -> {
            requireOwn(taskId);
            // 模型调用不持数据库锁；写回时锁住并核对模型实际读取的候选，拒绝覆盖另一窗口的新对话。
            taskMapper.lockById(taskId);
            SportsAiTask current = requireOwn(taskId);
            if (!"PENDING_CONFIRMATION".equals(current.getStatus())
                || !Objects.equals(expectedProposal, current.getProposal())) {
                throw new ServiceException("任务已被更新，请重新读取后继续；本次回答没有覆盖草稿");
            }
            current.setProposal(proposal);
            if (taskMapper.updateById(current) != 1) {
                throw new ServiceException("任务已被更新，请重新读取后继续；本次回答没有覆盖草稿");
            }
        });
    }

    private List<DiscussTurn> dialogueOf(String proposal) {
        List<DiscussTurn> turns = new ArrayList<>();
        try {
            JsonNode dialogue = objectMapper.readTree(proposal == null ? "{}" : proposal).path("dialogue");
            if (dialogue.isArray()) {
                for (JsonNode turn : dialogue) {
                    turns.add(new DiscussTurn(turn.path("role").asText(""), turn.path("text").asText("")));
                }
            }
        } catch (Exception ignored) {
            return turns;
        }
        return turns;
    }

    private ConfirmDraft draftOf(String proposal) {
        try {
            JsonNode root = objectMapper.readTree(proposal == null ? "{}" : proposal);
            if(root instanceof ObjectNode candidate)DraftChoices.applyDefaults(candidate);
            JsonNode event = root.path("event");
            List<UnitDraft> units = new ArrayList<>();
            if (root.path("units").isArray()) {
                for (JsonNode unit : root.path("units")) {
                    units.add(new UnitDraft(
                        unit.path("name").path("value").asText(""),
                        unit.path("entryType").path("value").asText(""),
                        integerOrNull(unit.path("minMembers").path("value")),
                        integerOrNull(unit.path("maxMembers").path("value")),
                        integerOrNull(unit.path("limitCount").path("value")),
                        unit.path("feeAmount").path("value").asText(""),
                        unit.path("feeBasis").path("value").asText(""),
                        "conflict".equals(unit.path("feeAmount").path("status").asText()) || "conflict".equals(unit.path("feeBasis").path("status").asText())
                            ? "conflict" : unit.path("feeAmount").path("status").asText("missing")
                    ));
                }
            }
            return new ConfirmDraft(java.util.UUID.randomUUID().toString(),
                event.path("name").path("value").asText(""),
                event.path("location").path("value").asText(""),
                event.path("projectName").path("value").asText(""),
                event.path("feeDescription").path("value").asText(""),
                event.path("registrationOpensAt").path("value").asText(""),
                event.path("registrationClosesAt").path("value").asText(""),
                event.path("startsAt").path("value").asText(""),
                event.path("endsAt").path("value").asText(""),
                event.path("registrationReview").path("value").asText(""),
                event.path("rulesText").path("value").asText(""),
                units, event.path("contactName").path("value").asText(""),
                event.path("contactMethod").path("value").asText(""),
                event.path("refundTerms").path("value").asText(""),
                event.path("declarationText").path("value").asText(""),false,null);
        } catch (Exception exception) {
            throw new ServiceException("草稿读不出来");
        }
    }

    private Integer integerOrNull(JsonNode node) {
        if (node == null || node.isMissingNode() || node.isNull() || node.asText("").isBlank()) {
            return null;
        }
        try {
            return Integer.valueOf(node.asText());
        } catch (NumberFormatException exception) {
            return null;
        }
    }

    public TaskCard abandon(long taskId) {
        ManagedOrganization organization = organizer();
        SportsAiTask task = requireOwn(taskId);
        if ("CREATED".equals(task.getStatus())) {
            throw new ServiceException("已经创建赛事的任务不能放弃");
        }
        List<SportsAiTaskFile> files = filesOf(taskId);
        for (SportsAiTaskFile file : files) {
            storedObjectApi.discard(file.getFileId(), StoredObjectApi.AI_SOURCE, organization.tenantId());
        }
        transactionTemplate.executeWithoutResult(status -> {
            SportsAiTask current = requireOwn(taskId);
            current.setStatus("ABANDONED");
            current.setExtraction(null);
            current.setProposal(null);
            current.setErrorCode(null);
            current.setErrorMessage(null);
            taskMapper.updateById(current);
        });
        return get(taskId);
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.event.sportseventrunaitaskservice.confirm",title="兼容业务办理",reads={"asp_file","asp_organization","asp_staff_grant","asp_account_tenant_principal","asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"},writes={"asp_file","asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    public ConfirmResult confirm(long taskId, ConfirmDraft draft) {
        if (draft == null || draft.requestKey() == null || draft.requestKey().isBlank()) {
            throw new ServiceException("请提供确认请求键");
        }
        return transactionTemplate.execute(status -> {
            SportsAiTask visible = requireOwn(taskId);
            taskMapper.lockById(visible.getId());
            SportsAiTask task = requireOwn(taskId);
            String decision = AiTaskPolicy.confirmDecision(task.getStatus());
            if ("RETURN".equals(decision)) {
                return new ConfirmResult(task.getResultObjectId(), true);
            }
            if (!"APPLY".equals(decision)) {
                throw new ServiceException("请先完成识别，再确认创建");
            }
            validateDraft(draft);
            ConfirmDraft candidate = draftOf(task.getProposal());
            AiDeclarationProposal.requireMatch(objectMapper,task.getProposal(),draft,candidate,task.getVersion());
            boolean priced = AiFeeProposalPlan.present(candidate.units()) || AiFeeProposalPlan.present(draft.units());
            ManagedOrganization organization = organizer();
            if (draft.expectedVersion()!=null && !Objects.equals(task.getVersion(),draft.expectedVersion())) {
                throw new ServiceException("草稿已更新，请重新读取并核对后确认",409);
            }
            if (priced) {
                // A source price is not authority. Bind the visible unit/price confirmation to this exact task revision.
                if (draft.expectedVersion()==null || !Objects.equals(task.getVersion(),draft.expectedVersion())) {
                    throw new ServiceException("草稿已更新，请重新读取并核对项目人数、名额和每单价格后确认",409);
                }
                if (!Objects.equals(candidate.units(),draft.units()) || !AiFeeProposalPlan.present(candidate.units())) {
                    throw new ServiceException("确认的项目或价格与当前草稿不一致，请先补充草稿并重新确认",409);
                }
                if (!qualificationApi.hasStaffAction(organization.tenantId(),organization.organizationId(),organization.accountId(),"payment")) {
                    throw new ServiceException("当前组织身份没有费用管理权限，请由有权限的办赛人员确认价格",403);
                }
            }
            EventCard event = eventService.create(new EventDraft(
                draft.name(), draft.location(), draft.projectName(), draft.feeDescription(),
                draft.registrationOpensAt(), draft.registrationClosesAt(), draft.startsAt(), draft.endsAt(),
                draft.registrationReview(), keepChosenCover(task), draft.rulesText(), null,
                null, null, draft.declarationText(), null, null, null, Boolean.TRUE.equals(draft.declarationAckRequired()),
                draft.contactName(), draft.contactMethod(), draft.refundTerms()));
            ObjectNode createdProposal=readProposal(task.getProposal());int unitIndex=0;
            for (UnitDraft unit : draft.units()) {
                long unitId = competitionSetupApi.placeUnpricedUnit(event.id(), unit.name(), unit.entryType(), unit.minMembers(), unit.maxMembers(), unit.limitCount());
                if(createdProposal.path("units").isArray()&&unitIndex<createdProposal.path("units").size())((ObjectNode)createdProposal.path("units").get(unitIndex)).put("createdUnitId",Long.toString(unitId));
                unitIndex++;
                if (priced) {
                    var amount = AiFeeProposalPlan.amount(unit);
                    feeApi.placeInitialPolicy(organization.tenantId(),unitId,amount,amount.signum()==0?"free":"event",null,null);
                }
            }
            task.setStatus("CREATED");
            task.setResultObjectId(event.id());
            AiDraftState createdState=eventService.aiDraftState(event.id());
            if(createdState!=null){bindCreatedBaseline(task,createdProposal,createdState,true);createdProposal.put("createdDirty",false);task.setProposal(createdProposal.toString());}
            task.setConfirmKey(draft.requestKey().trim());
            task.setErrorCode(null);
            task.setErrorMessage(null);
            if (taskMapper.updateById(task) != 1) {
                throw new ServiceException("任务已被更新，请再确认一次");
            }
            return new ConfirmResult(event.id(), false);
        });
    }

    public StoredObjectApi.DocumentBody preview(long taskId, long fileId) {
        ManagedOrganization organization = organizer();
        requireFile(requireOwn(taskId).getId(), fileId);
        return storedObjectApi.readOwnedDocument(fileId, organization.tenantId());
    }

    /** Private source inspector; all thumbnails remain bound to the current organizer and original file. */
    public JsonNode sourceElements(long taskId) {
        var task=requireOwn(taskId);
        try {
            var output=objectMapper.readTree(task.getExtraction()==null?"{\"files\":[]}":task.getExtraction()).deepCopy();
            var notes=invocationMapper.selectList(Wrappers.<SportsAiInvocation>lambdaQuery().eq(SportsAiInvocation::getTaskId,taskId).eq(SportsAiInvocation::getToolName,"material_image").eq(SportsAiInvocation::getStatus,"succeeded").orderByDesc(SportsAiInvocation::getId));
            for(var file:output.path("files"))for(var item:file.path("visuals"))for(var note:notes){
                var cached=objectMapper.readTree(note.getSummary());
                if(cached.path("fileId").asText().equals(file.path("fileId").asText())&&cached.path("index").asInt(-1)==item.path("index").asInt(-2)&&cached.path("sha256").asText().equals(item.path("sha256").asText())){
                    var visual=(ObjectNode)item;visual.put("text",cached.path("text").asText()).put("recognitionStatus",cached.path("recognitionStatus").asText()).put("role",cached.path("role").asText("other")).put("caption",cached.path("caption").asText());break;
                }
            }return output;
        }catch(java.io.IOException e){throw new ServiceException("原文元素暂时无法读取");}
    }

    public StoredObjectApi.ImageBody previewVisual(long taskId,long fileId,int index) {
        var task=requireOwn(taskId);requireFile(taskId,fileId);
        byte[] body=storedObjectApi.readOwnedDocument(fileId,task.getTenantId()).body();
        try{
            JsonNode file=null;for(var item:sourceElements(taskId).path("files"))if(item.path("fileId").asLong()==fileId)file=item;
            if(file==null||index<0||index>=file.path("visuals").size())throw new ServiceException("图片不在当前资料中",403);
            var visual=file.path("visuals").get(index);
            if("unsupported".equals(visual.path("kind").asText()))throw new ServiceException("该图片格式需要对照原件");
            byte[] picture=visualBytes(body,file,index);
            String url=AgentMaterials.imageUrl(picture);
            return new StoredObjectApi.ImageBody("image/jpeg",java.util.Base64.getDecoder().decode(url.substring(url.indexOf(',')+1)));
        }catch(java.io.IOException|IllegalArgumentException e){throw new ServiceException("图片无法预览，请对照原件");}
    }

    /** A pending candidate stays local; an existing unused draft saves to its original event in one transaction. */
    public TaskCard editCandidate(long taskId,CandidateEdit input) {
        if(input==null||input.expectedVersion()==null||input.event()==null||!input.event().isObject())throw new ServiceException("请先读取完整草稿",400);
        SportsAiTask visible=requireOwn(taskId);
        if("CREATED".equals(visible.getStatus())){
            eventService.withUnusedAiDraft(visible.getResultObjectId(),state->{editCandidateBody(taskId,input,state);return null;});
        }else editCandidateBody(taskId,input,null);
        return get(taskId);
    }

    private void editCandidateBody(long taskId,CandidateEdit input,AiDraftState createdState){
        transactionTemplate.executeWithoutResult(status->{
            requireOwn(taskId);taskMapper.lockById(taskId);var task=requireOwn(taskId);
            if(!("PENDING_CONFIRMATION".equals(task.getStatus())||createdState!=null&&"CREATED".equals(task.getStatus()))||!Objects.equals(task.getVersion(),input.expectedVersion()))throw new ServiceException("草稿已更新，请重新查看后填写",409);
            try{
                var proposal=(ObjectNode)objectMapper.readTree(task.getProposal());var event=proposal.withObject("event");
                var fields=input.event().fields();while(fields.hasNext()){
                    var field=fields.next();String key=field.getKey();
                    if(!Set.of(EVENT_FIELDS).contains(key)||!field.getValue().isTextual())throw new ServiceException("表单内容无效",400);
                    String value=field.getValue().asText().trim();int limit=Set.of("rulesText","declarationText").contains(key)?120000:Set.of("feeDescription","refundTerms").contains(key)?12000:500;
                    if(value.length()>limit)throw new ServiceException("表单内容过长，请分段整理",400);
                    if(key.equals("registrationReview")&&!Set.of("","manual","none").contains(value))throw new ServiceException("请选择有效审核方式",400);
                    // Saving the visible form also confirms an unchanged disputed/suggested value.
                    if(!event.path(key).path("value").asText().equals(value)||!event.path(key).path("status").asText().equals(value.isBlank()?"missing":"filled")){
                        var node=event.putObject(key).put("value",value).put("status",value.isBlank()?"missing":"filled");
                        node.putArray("sources").addObject().put("kind","manual").put("label","本人表单填写").put("quote",value);node.putArray("alternatives");
                    }
                }
                if(input.units()!=null&&!input.units().isNull()){
                    if(!input.units().isArray()||input.units().size()!=proposal.path("units").size())throw new ServiceException("项目目录已变化，请重新查看草稿",409);
                    for(int i=0;i<input.units().size();i++){
                        var patch=input.units().get(i);var unit=(ObjectNode)proposal.path("units").get(i);
                        var entries=patch.fields();while(entries.hasNext()){
                            var item=entries.next();String key=item.getKey(),value=item.getValue().asText().trim();
                            if(!Set.of("name","entryType","limitCount","minMembers","maxMembers","feeAmount","feeBasis").contains(key)||!item.getValue().isTextual()||value.length()>200)throw new ServiceException("项目表单内容无效",400);
                            if(key.equals("entryType")&&!Set.of("","individual","pair","team").contains(value)||key.equals("feeBasis")&&!Set.of("","order","per_person","additional","unknown").contains(value))throw new ServiceException("请选择有效参赛形式或计费单位",400);
                            if(!value.isBlank()&&Set.of("limitCount","minMembers","maxMembers").contains(key)&&!value.matches("[1-9][0-9]{0,5}"))throw new ServiceException("人数与名额须填写正整数",400);
                            if(key.equals("feeAmount")&&!value.isBlank()&&!value.matches("[0-9]{1,9}(\\.[0-9]{1,2})?"))throw new ServiceException("费用须填写有效元金额",400);
                            if(!unit.path(key).path("value").asText().equals(value)||!unit.path(key).path("status").asText().equals(value.isBlank()?"missing":"filled")){
                                String original=unit.path(key).path("originalValue").asText(unit.path(key).path("value").asText());
                                var node=unit.putObject(key).put("value",value).put("status",value.isBlank()?"missing":"filled");if(key.equals("name"))node.put("originalValue",original);node.putArray("sources").addObject().put("kind","manual").put("label","本人表单填写").put("quote",value);node.putArray("alternatives");
                            }
                        }
                    }
                }
                if(input.cover()!=null&&!input.cover().isNull()){
                    long fileId=input.cover().path("fileId").asLong();int index=input.cover().path("index").asInt(-1);
                    if(fileId==0)proposal.remove("cover");
                    else{
                        requireFile(taskId,fileId);JsonNode visual=null;
                        for(var file:sourceElements(taskId).path("files"))if(file.path("fileId").asLong()==fileId&&index>=0&&index<file.path("visuals").size())visual=file.path("visuals").get(index);
                        if(visual==null||"unsupported".equals(visual.path("kind").asText()))throw new ServiceException("请从当前资料选择可读取的图片",403);
                        proposal.putObject("cover").put("fileId",Long.toString(fileId)).put("index",index).put("sha256",visual.path("sha256").asText()).put("role",visual.path("role").asText("other")).put("selection","manual");
                    }
                }
                if(input.declarationAckRequired()!=null)proposal.put("createdDeclarationAckRequired",input.declarationAckRequired());
                if(createdState!=null)syncCreatedDraft(task,proposal,createdState);
                task.setProposal(proposal.toString());if(taskMapper.updateById(task)!=1)throw new ServiceException("草稿已更新，请重新读取",409);
            }catch(java.io.IOException e){throw new ServiceException("草稿暂时无法读取");}
        });
    }

    private Long keepChosenCover(SportsAiTask task){
        try{
            var cover=objectMapper.readTree(task.getProposal()).path("cover");if(cover.isMissingNode())return null;
            long fileId=cover.path("fileId").asLong();int index=cover.path("index").asInt(-1);requireFile(task.getId(),fileId);
            JsonNode actual=null;for(var file:sourceElements(task.getId()).path("files"))if(file.path("fileId").asLong()==fileId&&index>=0&&index<file.path("visuals").size())actual=file.path("visuals").get(index);
            if(actual==null||!actual.path("sha256").asText().equals(cover.path("sha256").asText()))throw new ServiceException("封面来源已变化，请重新选择",409);
            return storedObjectApi.keepImage(task.getInitiatorAccountId(),task.getTenantId(),StoredObjectApi.EVENT_BANNER,previewVisual(task.getId(),fileId,index).body());
        }catch(java.io.IOException e){throw new ServiceException("封面来源无法读取");}
    }

    public record CandidateEdit(Integer expectedVersion,JsonNode event,JsonNode cover,JsonNode units,Boolean declarationAckRequired) {
        public CandidateEdit(Integer expectedVersion,JsonNode event,JsonNode cover,JsonNode units){this(expectedVersion,event,cover,units,null);}
    }

    /** Server-owned identity and baseline survive model rewrites; an external edit must never be overwritten silently. */
    private void bindCreatedBaseline(SportsAiTask task,ObjectNode proposal,AiDraftState state){
        bindCreatedBaseline(task,proposal,state,false);
    }

    private void bindCreatedBaseline(SportsAiTask task,ObjectNode proposal,AiDraftState state,boolean initialCreation){
        ObjectNode prior=readProposal(task.getProposal());
        var actual=competitionSetupApi.currentDraftUnits(state.event().id());
        JsonNode catalog=createdCatalog(task.getTenantId(),state.event().id(),actual);
        if(prior.has("createdEventVersion")){
            if(!Objects.equals(prior.path("createdEventVersion").asInt(),state.version())||!prior.path("createdCatalogSnapshot").equals(catalog))throw new ServiceException("赛事或项目费用已在其他页面更新，请重新核对实际赛事；本轮没有覆盖",409);
        }else if(!initialCreation){
            // A pre-upgrade task has no reliable concurrency baseline. Explicitly reread all actual fields first.
            throw new ServiceException("这份历史草稿尚未核对实际赛事版本，请点击读取赛事当前内容；原候选和资料会保留，本次没有覆盖",409);
        }
        if(!proposal.path("units").isArray()||proposal.path("units").size()!=actual.size())throw new ServiceException("当前聊天只支持修改已有项目；新增或删除项目请到项目与费用办理，再重新核对草稿",409);
        var used=new java.util.HashSet<Long>();
        for(JsonNode item:proposal.path("units")){
            ObjectNode unit=(ObjectNode)item;long id=unit.path("createdUnitId").asLong();
            if(id==0){
                String name=unit.path("name").path("originalValue").asText(unit.path("name").path("value").asText());
                var matches=actual.stream().filter(row->Objects.equals(row.name(),name)).toList();
                if(matches.size()!=1)throw new ServiceException("项目目录与这份草稿不一致，请先核对实际项目；不会新建另一份赛事",409);
                id=matches.get(0).unitId();unit.put("createdUnitId",Long.toString(id));
            }
            long unitId=id;if(!used.add(id)||actual.stream().noneMatch(row->row.unitId()==unitId))throw new ServiceException("项目编号不属于当前赛事或目录重复，请重新核对",409);
        }
        proposal.put("createdEventVersion",state.version());proposal.set("createdCatalogSnapshot",catalog);
        if(prior.has("createdCoverSnapshot"))proposal.set("createdCoverSnapshot",prior.path("createdCoverSnapshot").deepCopy());
        else proposal.set("createdCoverSnapshot",coverOf(prior));
    }

    private JsonNode coverOf(JsonNode proposal){return proposal.has("cover")?proposal.path("cover").deepCopy():com.fasterxml.jackson.databind.node.NullNode.instance;}

    private JsonNode createdCatalog(String tenantId,Long eventId,List<CompetitionSetupApi.DraftUnit> units){
        var result=objectMapper.createObjectNode();var directory=result.putArray("units");
        // Explicit scalar types survive JSON persistence even for small fixture Long IDs.
        for(var unit:units)directory.addObject().put("unitId",Long.toString(unit.unitId())).put("name",unit.name()).put("entryType",unit.entryType()).put("minMembers",unit.minMembers()).put("maxMembers",unit.maxMembers()).put("limitCount",unit.limitCount()).put("status",unit.status()).put("capacityStatus",unit.capacityStatus());
        var prices=result.putArray("prices");
        feeApi.publicUnitPrices(tenantId,eventId).stream().sorted(java.util.Comparator.comparing(FeeApi.PublicUnitPrice::unitId)).forEach(price->{
            var row=prices.addObject().put("unitId",Long.toString(price.unitId()));
            if(price.amount()==null)row.putNull("amount");else row.put("amount",price.amount().stripTrailingZeros().toPlainString());
            if(price.paymentMode()==null)row.putNull("paymentMode");else row.put("paymentMode",price.paymentMode());
        });return result;
    }

    /** Only the person's explicit reread adopts outside changes. The previous candidate is bounded, never recursively copied. */
    private void refreshCreatedCandidate(long taskId,Integer expectedVersion,String message){
        var visible=requireOwn(taskId);eventService.withUnusedAiDraft(visible.getResultObjectId(),state->{
            taskMapper.lockById(taskId);var task=requireOwn(taskId);
            if(!"CREATED".equals(task.getStatus())||!Objects.equals(expectedVersion,task.getVersion()))throw new ServiceException("草稿已更新，请重新读取后核对；本次没有覆盖",409);
            ObjectNode proposal=readProposal(task.getProposal());var previous=objectMapper.createObjectNode();
            for(String field:List.of("event","units","cover"))if(proposal.has(field))previous.set(field,proposal.path(field).deepCopy());
            previous.put("createdDirty",proposal.path("createdDirty").asBoolean(false));if(proposal.has("createdEventVersion"))previous.set("createdEventVersion",proposal.path("createdEventVersion").deepCopy());previous.put("retainedAt",java.time.OffsetDateTime.now(SHANGHAI).toString());
            proposal.set("previousCreatedCandidate",previous);
            EventCard event=state.event();var fields=proposal.putObject("event");
            actualField(fields,"name",event.name());actualField(fields,"location",event.location());actualField(fields,"projectName",event.projectName());actualField(fields,"feeDescription",event.feeDescription());actualField(fields,"registrationReview",event.registrationReview());actualField(fields,"rulesText",event.rulesText());actualField(fields,"declarationText",event.declarationText());actualField(fields,"contactName",event.contactName());actualField(fields,"contactMethod",event.contactMethod());actualField(fields,"refundTerms",event.refundTerms());
            actualField(fields,"registrationOpensAt",event.registrationOpensAt()==null?null:event.registrationOpensAt().toString());actualField(fields,"registrationClosesAt",event.registrationClosesAt()==null?null:event.registrationClosesAt().toString());actualField(fields,"startsAt",event.startsAt()==null?null:event.startsAt().toString());actualField(fields,"endsAt",event.endsAt()==null?null:event.endsAt().toString());
            var catalog=competitionSetupApi.currentDraftUnits(event.id());var prices=feeApi.publicUnitPrices(task.getTenantId(),event.id());var units=proposal.putArray("units");
            for(var unit:catalog){var row=units.addObject().put("createdUnitId",Long.toString(unit.unitId()));actualField(row,"name",unit.name());actualField(row,"entryType",unit.entryType());actualField(row,"minMembers",unit.minMembers()==null?null:unit.minMembers().toString());actualField(row,"maxMembers",unit.maxMembers()==null?null:unit.maxMembers().toString());actualField(row,"limitCount",Integer.toString(unit.limitCount()));var price=prices.stream().filter(item->Objects.equals(item.unitId(),unit.unitId())).findFirst().orElse(null);actualField(row,"feeAmount",price==null||price.amount()==null?null:price.amount().stripTrailingZeros().toPlainString());actualField(row,"feeBasis",price==null||price.amount()==null?null:"order");}
            proposal.put("createdEventVersion",state.version());proposal.set("createdCatalogSnapshot",createdCatalog(task.getTenantId(),event.id(),catalog));proposal.put("createdDirty",false);proposal.remove("createdDeclarationAckRequired");
            // The actual banner remains on the event. An old source selection must not pretend to be that current image.
            proposal.remove("cover");proposal.set("createdCoverSnapshot",com.fasterxml.jackson.databind.node.NullNode.instance);
            var dialogue=proposal.withArray("dialogue");dialogue.addObject().put("role","user").put("text",message);dialogue.addObject().put("role","ai").put("text","已明确读取实际赛事当前内容，上一候选已保留。现在修改会更新同一场未发布赛事。");while(dialogue.size()>40)dialogue.remove(0);
            task.setProposal(proposal.toString());if(taskMapper.updateById(task)!=1)throw new ServiceException("草稿已更新，请重新核对",409);return null;
        });
    }

    private void actualField(ObjectNode parent,String key,String value){var field=parent.putObject(key).put("value",value==null?"":value).put("status",value==null||value.isBlank()?"missing":"filled");var sources=field.putArray("sources");if(value!=null&&!value.isBlank())sources.addObject().put("kind","manual").put("label","实际赛事当前已保存内容").put("quote",value);field.putArray("alternatives");}

    private void syncCreatedDraft(SportsAiTask task,ObjectNode proposal,AiDraftState state){
        bindCreatedBaseline(task,proposal,state);
        ConfirmDraft draft=draftOf(proposal.toString());validateDraft(draft);
        var organization=organizer();var oldPrices=feeApi.publicUnitPrices(task.getTenantId(),state.event().id());
        boolean priced=AiFeeProposalPlan.present(draft.units());
        if(priced){
            var issues=AiFeeProposalPlan.issues(draft.units());if(!issues.isEmpty())throw new ServiceException(issues.get(0).message(),400);
            boolean changed=false;for(int i=0;i<draft.units().size();i++){
                long id=proposal.path("units").get(i).path("createdUnitId").asLong();var amount=AiFeeProposalPlan.amount(draft.units().get(i));
                var previous=oldPrices.stream().filter(price->price.unitId()==id).findFirst().orElse(null);
                if(previous==null||previous.amount()==null||previous.amount().compareTo(amount)!=0)changed=true;
            }
            if(changed&&!qualificationApi.hasStaffAction(organization.tenantId(),organization.organizationId(),organization.accountId(),"payment"))throw new ServiceException("当前组织身份没有费用管理权限，请由有权限的办赛人员保存价格",403);
        }
        for(int i=0;i<draft.units().size();i++){
            var unit=draft.units().get(i);long id=proposal.path("units").get(i).path("createdUnitId").asLong();
            competitionSetupApi.updateUnusedDraftUnit(state.event().id(),id,unit.name(),unit.entryType(),unit.minMembers(),unit.maxMembers(),unit.limitCount());
            if(priced){var amount=AiFeeProposalPlan.amount(unit);var previous=oldPrices.stream().filter(price->price.unitId()==id).findFirst().orElse(null);if(previous==null||previous.amount()==null||previous.amount().compareTo(amount)!=0)feeApi.reviseUnusedDraftPolicy(task.getTenantId(),state.event().id(),id,amount);}
        }
        EventCard actual=state.event();
        Long banner=actual.bannerFileId();
        if(!coverOf(proposal).equals(proposal.path("createdCoverSnapshot"))){
            if(proposal.has("cover")){SportsAiTask withCover=new SportsAiTask();withCover.setId(task.getId());withCover.setTenantId(task.getTenantId());withCover.setInitiatorAccountId(task.getInitiatorAccountId());withCover.setProposal(proposal.toString());banner=keepChosenCover(withCover);}else banner=null;
        }
        Boolean acknowledgement=proposal.path("createdDeclarationAckRequired").isBoolean()?proposal.path("createdDeclarationAckRequired").asBoolean():actual.declarationAckRequired();
        boolean retainedImageStatement=actual.declarationFileId()!=null&&(draft.declarationText()==null||draft.declarationText().isBlank())&&(actual.declarationText()==null||actual.declarationText().isBlank())&&Objects.equals(acknowledgement,actual.declarationAckRequired());
        if(!retainedImageStatement)AiDeclarationProposal.requireMatch(objectMapper,proposal.toString(),draft.withConsent(task.getVersion(),acknowledgement),draft,task.getVersion());
        eventService.update(actual.id(),new EventDraft(draft.name(),draft.location(),draft.projectName(),draft.feeDescription(),draft.registrationOpensAt(),draft.registrationClosesAt(),draft.startsAt(),draft.endsAt(),draft.registrationReview(),banner,draft.rulesText(),actual.rulesFileId(),actual.noticeText(),actual.noticeFileId(),draft.declarationText(),actual.declarationFileId(),actual.routeText(),actual.routeFileId(),acknowledgement,draft.contactName(),draft.contactMethod(),draft.refundTerms()));
        AiDraftState updated=eventService.aiDraftState(actual.id());
        proposal.put("createdEventVersion",updated.version());proposal.set("createdCatalogSnapshot",createdCatalog(task.getTenantId(),actual.id(),competitionSetupApi.currentDraftUnits(actual.id())));
        proposal.set("createdCoverSnapshot",coverOf(proposal));proposal.remove("createdDeclarationAckRequired");proposal.put("createdDirty",false);
    }

    private byte[] visualBytes(byte[] body,JsonNode file,int index)throws java.io.IOException{
        if(DocumentKinds.image(file.path("mediaKind").asText()))return body;
        if(file.path("visuals").get(index).path("kind").asText().equals("pdf-page"))return LocalDocumentExtractor.pdfPagePng(body,Integer.parseInt(file.path("visuals").get(index).path("location").asText().replaceAll("[^0-9]","")));
        return LocalDocumentExtractor.docxImage(body,index);
    }

    private JsonNode visualInventory(LocalDocumentExtractor.Extracted extracted,byte[] body){
        var visuals=(ArrayNode)objectMapper.valueToTree(extracted.visuals());
        try{
            if(DocumentKinds.image(extracted.mediaKind()))visuals.addObject().put("index",0).put("location","图片1").put("sha256",java.util.HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(body))).put("kind",extracted.mediaKind()).put("afterBlock",0);
            for(int page:extracted.scanPages()){int index=visuals.size();visuals.addObject().put("index",index).put("location","第"+page+"页").put("sha256",java.util.HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(LocalDocumentExtractor.pdfPagePng(body,page)))).put("kind","pdf-page").put("afterBlock",(int)extracted.blocks().stream().filter(b->b.label().matches("第[0-9]+页")&&Integer.parseInt(b.label().replaceAll("[^0-9]",""))<page).count());}
            return visuals;
        }catch(java.security.NoSuchAlgorithmException e){throw new IllegalStateException(e);}
    }

    public StoredObjectApi.DocumentBody internalFile(String token, long taskId, long fileId) {
        requireToken(token);
        SportsAiTask task = requireAny(taskId);
        requireFileInTenant(task, fileId);
        return TenantHelper.dynamic(task.getTenantId(), () -> storedObjectApi.readOwnedDocument(fileId, task.getTenantId()));
    }

    /** Existing originals and the previous derivative are retained when the extractor is upgraded. */
    private void refreshLegacyExtraction(SportsAiTask task){
        try{
            var source=(ObjectNode)objectMapper.readTree(task.getExtraction()==null?"{}":task.getExtraction());
            if(source.path("version").asInt()>=3)return;
            var upgraded=source.deepCopy();upgraded.set("previousExtraction",source);upgraded.put("version",3);
            for(var file:upgraded.path("files")){
                if(!file.has("fileId"))continue;
                long fileId=file.path("fileId").asLong();requireFileInTenant(task,fileId);
                byte[] body=TenantHelper.dynamic(task.getTenantId(),()->storedObjectApi.readOwnedDocument(fileId,task.getTenantId()).body());
                var extracted=LocalDocumentExtractor.extract(file.path("fileIndex").asInt(),DocumentKinds.sniff(body).media(),body,properties.getMaxScanPages());
                var target=(ObjectNode)file;target.set("blocks",objectMapper.valueToTree(extracted.blocks()));target.set("visuals",objectMapper.valueToTree(extracted.visuals()));target.put("sha256",java.util.HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(body)));
            }
            task.setExtraction(upgraded.toString());taskMapper.updateById(task);
        }catch(java.io.IOException|java.security.NoSuchAlgorithmException e){throw new ServiceException("原资料衍生解析无法恢复，请保留任务并重新提交资料");}
    }

    public JsonNode progress(long taskId){
        var task=requireOwn(taskId);var output=objectMapper.createObjectNode().put("id",Long.toString(taskId)).put("status",task.getStatus());var steps=output.putArray("steps");
        for(var note:invocationMapper.selectList(Wrappers.<SportsAiInvocation>lambdaQuery().eq(SportsAiInvocation::getTaskId,taskId).orderByAsc(SportsAiInvocation::getCreateTime,SportsAiInvocation::getId))){
            var step=steps.addObject().put("sequence",Long.toString(note.getId())).put("attempt",note.getAttemptNo()).put("name",note.getToolName()==null?"model":note.getToolName()).put("status",note.getStatus());
            if(note.getErrorCode()!=null)step.put("errorCode",note.getErrorCode());
            try{var saved=objectMapper.readTree(note.getSummary());var visible=objectMapper.createObjectNode();for(String key:List.of("completed","total","field","reason","recognitionStatus","index"))if(saved.has(key))visible.set(key,saved.get(key));step.put("summary",visible.toString());}catch(Exception ignored){step.put("summary","{}");}
        }return output;
    }

    public JsonNode internalImages(String token,long taskId,long fileId,int offset){
        requireToken(token);var task=requireAny(taskId);requireFileInTenant(task,fileId);
        if(!"PROCESSING".equals(task.getStatus())||offset<0||offset%6!=0)throw new ServiceException("图片批次已失效",409);
        try{
            var extraction=objectMapper.readTree(task.getExtraction());JsonNode file=null;for(var item:extraction.path("files"))if(item.path("fileId").asLong()==fileId)file=item;
            if(file==null||offset>=file.path("visuals").size())throw new ServiceException("图片不在本次资料清单",403);
            var images=file.path("visuals");byte[] body=TenantHelper.dynamic(task.getTenantId(),()->storedObjectApi.readOwnedDocument(fileId,task.getTenantId()).body());
            var output=objectMapper.createObjectNode();var batch=output.putArray("items");
            var notes=TenantHelper.dynamic(task.getTenantId(),()->invocationMapper.selectList(Wrappers.<SportsAiInvocation>lambdaQuery().eq(SportsAiInvocation::getTaskId,taskId).eq(SportsAiInvocation::getToolName,"material_image").eq(SportsAiInvocation::getStatus,"succeeded").orderByDesc(SportsAiInvocation::getId)));
            for(int index=offset;index<Math.min(offset+6,images.size());index++){
                var visual=(ObjectNode)images.get(index).deepCopy();
                for(var note:notes){var cached=objectMapper.readTree(note.getSummary());if(cached.has("role")&&cached.path("fileId").asLong()==fileId&&cached.path("index").asInt(-1)==index&&cached.path("sha256").asText().equals(visual.path("sha256").asText())){visual.set("cached",objectMapper.createObjectNode().put("status",cached.path("recognitionStatus").asText()).put("text",cached.path("text").asText()).put("role",cached.path("role").asText()).put("caption",cached.path("caption").asText()));break;}}
                if(!visual.has("cached")&&!visual.path("kind").asText().equals("unsupported"))visual.put("url",AgentMaterials.imageUrl(visualBytes(body,file,index)));
                batch.add(visual);
            }return output;
        }catch(java.io.IOException e){throw new ServiceException("Word图片无法读取，请对照原件补充");}
    }

    /** Stores only visible stage metadata and bounded source transcriptions; never model reasoning. */
    public void internalProgress(String token,long taskId,JsonNode input){
        requireToken(token);var task=requireAny(taskId);
        if(!"PROCESSING".equals(task.getStatus()))throw new ServiceException("本轮识别已结束",409);
        String stage=input.path("stage").asText(),status=input.path("status").asText();
        if(!Set.of("material_read","material_image","vision_batch","source_fields","source_projects","answer_prepare").contains(stage)||!Set.of("started","succeeded","failed").contains(status))throw new ServiceException("进度类型无效",400);
        var summary=objectMapper.createObjectNode();
        for(String key:List.of("completed","total"))summary.put(key,Math.max(0,Math.min(160,input.path(key).asInt())));
        if(Set.of(EVENT_FIELDS).contains(input.path("field").asText()))summary.put("field",input.path("field").asText());
        if(Set.of("invalid_catalog","invalid_name","duplicate_name","missing_project_quote","missing_fee_quote").contains(input.path("reason").asText()))summary.put("reason",input.path("reason").asText()).put("index",Math.max(-1,Math.min(299,input.path("index").asInt(-1))));
        if(stage.equals("material_image")){
            long fileId=input.path("fileId").asLong();int index=input.path("index").asInt(-1);requireFileInTenant(task,fileId);JsonNode visual=null;
            try{for(var file:objectMapper.readTree(task.getExtraction()).path("files"))if(file.path("fileId").asLong()==fileId&&index>=0&&index<file.path("visuals").size())visual=file.path("visuals").get(index);}catch(java.io.IOException e){throw new ServiceException("图片清单无法读取");}
            String recognition=input.path("recognitionStatus").asText(),text=input.path("text").asText();
            if(visual==null||!visual.path("sha256").asText().equals(input.path("sha256").asText())||text.length()>12000||!Set.of("read","unreadable").contains(recognition)||recognition.equals("read")&&text.isBlank())throw new ServiceException("图片转写依据无效",409);
            summary.put("fileId",Long.toString(fileId)).put("index",index).put("sha256",visual.path("sha256").asText()).put("recognitionStatus",recognition).put("text",recognition.equals("read")?text:"");
            String role=input.path("role").asText("other");summary.put("role",Set.of("poster","photo","logo","table","qr","other").contains(role)?role:"other").put("caption",input.path("caption").asText().substring(0,Math.min(80,input.path("caption").asText().length())));
        }
        var row=new SportsAiInvocation();row.setTenantId(task.getTenantId());row.setTaskId(taskId);row.setKind("tool");row.setToolName(stage);row.setStatus(status);row.setAttemptNo(task.getAttemptCount());row.setSummary(summary.toString());
        TenantHelper.dynamic(task.getTenantId(),()->{invocationMapper.insert(row);return null;});
    }

    public byte[] internalPage(String token, long taskId, long fileId, int page) {
        requireToken(token);
        SportsAiTask task = requireAny(taskId);
        requireFileInTenant(task, fileId);
        StoredObjectApi.DocumentBody body = TenantHelper.dynamic(task.getTenantId(),
            () -> storedObjectApi.readOwnedDocument(fileId, task.getTenantId()));
        try {
            return LocalDocumentExtractor.pdfPagePng(body.body(), page);
        } catch (IllegalArgumentException exception) {
            throw new ServiceException(exception.getMessage());
        }
    }

    public String internalTool(String token, long taskId, String name, JsonNode arguments) {
        requireToken(token);
        SportsAiTask task = requireAny(taskId);
        JsonNode args = arguments == null || arguments.isNull() ? objectMapper.createObjectNode() : arguments;
        String decision = AiTaskPolicy.toolDecision(name);
        return TenantHelper.dynamic(task.getTenantId(), () -> {
            recordInvocation(task, "tool", name, "", "ALLOW".equals(decision) ? "succeeded" : "refused",
                "ALLOW".equals(decision) ? "" : "TOOL_DENIED");
            if (!"ALLOW".equals(decision)) {
                return "{\"refused\":true,\"message\":\"这个工具不在授权范围内\"}";
            }
            return switch (name) {
                case "describe_event_constraints" -> constraints();
                case "read_document_block" -> readStored(task, args.path("fileIndex").asInt(0), args.path("blockLabel").asText(""));
                case "validate_event_proposal" -> validateStored(args.path("proposal").isMissingNode() ? args.toString() : args.path("proposal").toString());
                default -> "{\"refused\":true}";
            };
        });
    }

    @Override
    public String describeEventCreateConstraints() {
        organizer();
        return constraints();
    }

    @Override
    public String readEventCreateDocument(long taskId, int fileIndex, String blockLabel) {
        return readStored(requireOwn(taskId), fileIndex, blockLabel);
    }

    @Override
    public String validateEventCreateProposal(String proposalJson) {
        organizer();
        return validateStored(proposalJson);
    }

    private void recognize(long taskId) {
        recognize(taskId, false);
    }

    private void recognize(long taskId, boolean refresh) {
        SportsAiTask task = requireOwn(taskId);
        if ("CREATED".equals(task.getStatus()) || "ABANDONED".equals(task.getStatus()) || (!refresh && "PENDING_CONFIRMATION".equals(task.getStatus()))) {
            return;
        }
        String previousProposal = task.getProposal();
        refreshLegacyExtraction(task);
        transactionTemplate.executeWithoutResult(status -> {
            taskMapper.lockById(taskId);
            SportsAiTask current = requireOwn(taskId);
            if("PROCESSING".equals(current.getStatus()))throw new ServiceException("资料已在识别中，请查看进度",409);
            current.setStatus("PROCESSING");
            current.setAttemptCount(current.getAttemptCount() == null ? 1 : current.getAttemptCount() + 1);
            current.setErrorCode(null);
            current.setErrorMessage(null);
            if(taskMapper.updateById(current)!=1)throw new ServiceException("任务已更新，请重新读取",409);
        });
        Runnable launch=()->{try{recognitionWorkers.execute(()->TenantHelper.dynamic(task.getTenantId(),()->{processRecognition(taskId,previousProposal);return null;}));}catch(RejectedExecutionException busy){fail(taskId,"BUSY");}};
        if(org.springframework.transaction.support.TransactionSynchronizationManager.isSynchronizationActive())org.springframework.transaction.support.TransactionSynchronizationManager.registerSynchronization(new org.springframework.transaction.support.TransactionSynchronization(){@Override public void afterCommit(){launch.run();}});
        else launch.run();
    }

    private void processRecognition(long taskId,String previousProposal){
        try {
            if (!properties.keyConfigured()) {
                fail(taskId, AiTaskPolicy.NEED_API_KEY);
                return;
            }
            Reply reply = gatewayClient.run(taskId, requireAny(taskId).getExtraction());
            if (!reply.ok()) {
                var current=requireAny(taskId);
                for(var note:reply.invocations())recordInvocation(current,note.kind(),note.toolName(),note.modelName(),note.status(),note.errorCode());
                if(reply.invocations().isEmpty())recordInvocation(current,"model","","","failed",reply.errorCode());
                if(!reply.field().isBlank())internalProgress(properties.getInternalToken(),taskId,objectMapper.createObjectNode().put("stage",reply.field().equals("projectName")?"source_projects":"source_fields").put("status","failed").put("field",reply.field()));
                fail(taskId, reply.errorCode());
                return;
            }
            DraftMerge.Merged merged = DraftMerge.absorb(objectMapper, previousProposal, reply.proposal(), null, false);
            succeed(taskId, preserveManualEdits(merged.proposal(),previousProposal), reply.invocations());
        } catch (RuntimeException exception) {
            fail(taskId, "MODEL_FAILED");
        }
    }

    private String preserveManualEdits(String proposal,String previous){
        if(previous==null||previous.isBlank())return proposal;
        try{var next=(ObjectNode)objectMapper.readTree(proposal);var old=objectMapper.readTree(previous);var event=next.withObject("event");
            for(String key:EVENT_FIELDS)for(var source:old.path("event").path(key).path("sources"))if(source.path("kind").asText().equals("manual")){event.set(key,old.path("event").path(key).deepCopy());break;}
            if(next.path("units") instanceof ArrayNode catalog)for(var oldUnit:old.path("units")){
                ObjectNode match=null;String name=oldUnit.path("name").path("value").asText(),original=oldUnit.path("name").path("originalValue").asText(name);
                for(var unit:catalog)if(unit.path("name").path("value").asText().equals(name)||unit.path("name").path("value").asText().equals(original)){match=(ObjectNode)unit;break;}
                boolean manual=false;for(String key:List.of("name","entryType","limitCount","minMembers","maxMembers","feeAmount","feeBasis"))for(var source:oldUnit.path(key).path("sources"))if(source.path("kind").asText().equals("manual")){manual=true;if(match!=null)match.set(key,oldUnit.path(key).deepCopy());break;}
                if(manual&&match==null){catalog.add(oldUnit.deepCopy());next.withArray("warnings").add("补充资料的项目命名与人工表单不同，已保留人工项目，请核对并调整项目目录。");}
            }
            if(old.has("cover")&&old.path("cover").path("selection").asText().equals("manual"))next.set("cover",old.path("cover").deepCopy());return next.toString();
        }catch(java.io.IOException e){throw new ServiceException("之前的表单修改无法核对");}
    }

    private long insertPasted(ManagedOrganization organization, String text) {
        SportsAiTask task = newTask(organization, 0);
        ObjectNode fileNode = objectMapper.createObjectNode();
        fileNode.put("fileIndex", 0);
        fileNode.put("mediaKind", "pasted-text");
        fileNode.put("originalName", "粘贴的规程");
        ArrayNode blocks = fileNode.putArray("blocks");
        ObjectNode blockNode = blocks.addObject();
        blockNode.put("kind", "paragraph");
        blockNode.put("label", "规程");
        blockNode.put("text", text);
        ObjectNode extraction = objectMapper.createObjectNode();
        extraction.put("version", 3);
        extraction.putArray("files").add(fileNode);
        task.setExtraction(extraction.toString());
        taskMapper.updateById(task);
        return task.getId();
    }

    private SportsAiTask newTask(ManagedOrganization organization, int scanPages) {
        Date start = Date.from(LocalDate.now(SHANGHAI).atStartOfDay(SHANGHAI).toInstant());
        Long created = taskMapper.selectCount(Wrappers.<SportsAiTask>lambdaQuery()
            .eq(SportsAiTask::getOrganizationId, organization.organizationId())
            .ge(SportsAiTask::getCreateTime, start));
        AiTaskPolicy.requireDaily(created == null ? 0 : created, properties.getDailyTasks());
        AiTaskPolicy.requireScanPages(scanPages, properties.getMaxScanPages());
        SportsAiTask task = new SportsAiTask();
        task.setTenantId(organization.tenantId());
        task.setScene(AiTaskPolicy.SCENE);
        task.setBusinessObject(AiTaskPolicy.BUSINESS_OBJECT);
        task.setOrganizationId(organization.organizationId());
        task.setInitiatorAccountId(organization.accountId());
        task.setStatus("UPLOADED");
        task.setBailianConsent(false);
        task.setProviderConsent(true);
        task.setProviderName("deepseek");
        task.setConsentVersion("deepseek-v4.1-20261010");
        task.setAttemptCount(0);
        task.setVersion(0);
        taskMapper.insert(task);
        return task;
    }

    private long insertTask(ManagedOrganization organization, List<Prepared> prepared) {
        int scans = 0;
        for (Prepared item : prepared) {
            scans += item.extracted().scanPages().size();
        }
        SportsAiTask task = newTask(organization, scans);
        ArrayNode files = objectMapper.createArrayNode();
        int index = 0;
        for (Prepared item : prepared) {
            long fileId = storedObjectApi.keepDocument(organization.accountId(), organization.tenantId(), StoredObjectApi.AI_SOURCE, item.body());
            SportsAiTaskFile row = new SportsAiTaskFile();
            row.setTenantId(organization.tenantId());
            row.setTaskId(task.getId());
            row.setFileId(fileId);
            row.setSortOrder(index);
            row.setMediaKind(item.extracted().mediaKind());
            row.setOriginalName(item.originalName());
            row.setPageCount(item.extracted().pageCount());
            row.setVersion(0);
            fileMapper.insert(row);
            ObjectNode fileNode = files.addObject();
            fileNode.put("fileIndex", index);
            fileNode.put("fileId", Long.toString(fileId));
            fileNode.put("mediaKind", item.extracted().mediaKind());
            fileNode.put("originalName", item.originalName() == null ? "" : item.originalName());
            if (item.extracted().pageCount() != null) {
                fileNode.put("pageCount", item.extracted().pageCount());
            }
            ArrayNode scanPages = fileNode.putArray("scanPages");
            item.extracted().scanPages().forEach(scanPages::add);
            fileNode.set("visuals",visualInventory(item.extracted(),item.body()));
            ArrayNode blocks = fileNode.putArray("blocks");
            for (Block block : item.extracted().blocks()) {
                ObjectNode blockNode = blocks.addObject();
                blockNode.put("kind", block.kind());
                blockNode.put("label", block.label());
                blockNode.put("text", block.text());
            }
            index++;
        }
        ObjectNode extraction = objectMapper.createObjectNode();
        extraction.put("version", 3);
        extraction.set("files", files);
        task.setExtraction(extraction.toString());
        taskMapper.updateById(task);
        return task.getId();
    }

    private List<Prepared> prepare(MultipartFile[] files) {
        if (files == null || files.length == 0) {
            throw new ServiceException("请选择资料");
        }
        AiTaskPolicy.requireUpload(java.util.Arrays.stream(files).mapToLong(file -> file == null ? 0 : file.getSize()).toArray());
        List<Prepared> prepared = new ArrayList<>();
        int index = 0;
        for (MultipartFile file : files) {
            if (file == null || file.isEmpty()) {
                throw new ServiceException("请选择资料");
            }
            byte[] body;
            try {
                body = file.getBytes();
            } catch (Exception exception) {
                throw new ServiceException("文件读不出来");
            }
            DocumentKinds.Kind kind;
            try {
                kind = DocumentKinds.sniff(body);
                Extracted extracted = LocalDocumentExtractor.extract(index, kind.media(), body, properties.getMaxScanPages());
                prepared.add(new Prepared(cleanName(file.getOriginalFilename()), body, extracted));
            } catch (IllegalArgumentException exception) {
                throw new ServiceException(exception.getMessage());
            }
            index++;
        }
        return prepared;
    }

    private void succeed(long taskId, String proposal, List<CallNote> notes) {
        transactionTemplate.executeWithoutResult(status -> {
            SportsAiTask task = requireAny(taskId);
            if ("CREATED".equals(task.getStatus()) || "ABANDONED".equals(task.getStatus())) {
                return;
            }
            for (CallNote note : notes) {
                recordInvocation(task, note.kind(), note.toolName(), note.modelName(), note.status(), note.errorCode());
            }
            task.setStatus("PENDING_CONFIRMATION");
            try{
                var candidate=(ObjectNode)objectMapper.readTree(proposal);
                DraftChoices.applyDefaults(candidate);
                if(!candidate.has("cover"))for(var note:invocationMapper.selectList(Wrappers.<SportsAiInvocation>lambdaQuery().eq(SportsAiInvocation::getTaskId,taskId).eq(SportsAiInvocation::getToolName,"material_image").eq(SportsAiInvocation::getStatus,"succeeded").orderByDesc(SportsAiInvocation::getId))){
                    var visual=objectMapper.readTree(note.getSummary());
                    if(Set.of("poster","photo").contains(visual.path("role").asText())&&visual.path("recognitionStatus").asText().equals("read")){
                        candidate.putObject("cover").put("fileId",visual.path("fileId").asText()).put("index",visual.path("index").asInt()).put("sha256",visual.path("sha256").asText()).put("role",visual.path("role").asText()).put("selection","recommended");break;
                    }
                }
                task.setProposal(candidate.toString());
            }catch(java.io.IOException e){throw new ServiceException("候选草稿格式无效");}
            task.setErrorCode(null);
            task.setErrorMessage(null);
            taskMapper.updateById(task);
        });
    }

    private void fail(long taskId, String code) {
        transactionTemplate.executeWithoutResult(status -> {
            SportsAiTask task = requireAny(taskId);
            if ("CREATED".equals(task.getStatus()) || "ABANDONED".equals(task.getStatus())) {
                return;
            }
            task.setStatus("FAILED");
            task.setErrorCode(code);
            task.setErrorMessage(message(code));
            taskMapper.updateById(task);
        });
    }

    private void recordInvocation(SportsAiTask task, String kind, String toolName, String modelName, String status, String errorCode) {
        SportsAiInvocation row = new SportsAiInvocation();
        row.setTenantId(task.getTenantId());
        row.setTaskId(task.getId());
        row.setKind(kind);
        row.setToolName(toolName == null || toolName.isBlank() ? null : toolName);
        row.setModelName(modelName == null || modelName.isBlank() ? null : modelName);
        row.setStatus(status);
        row.setAttemptNo(task.getAttemptCount() == null ? 0 : task.getAttemptCount());
        row.setErrorCode(errorCode == null || errorCode.isBlank() ? null : errorCode);
        row.setSummary("{\"degraded\":false}");
        row.setVersion(0);
        invocationMapper.insert(row);
    }

    private void validateDraft(ConfirmDraft draft) {
        var ready = AiDraftReadiness.check(draft, java.time.OffsetDateTime.now(SHANGHAI));
        if (!ready.canSaveDraft()) throw new ServiceException(ready.blockingIssues().stream().map(AiDraftReadiness.Issue::message).collect(java.util.stream.Collectors.joining("；")));
    }

    private String viewProposal(String proposal) {
        if (proposal == null || proposal.isBlank()) return proposal;
        try {
            ObjectNode root = (ObjectNode) objectMapper.readTree(proposal);
            DraftChoices.applyDefaults(root);
            var ready=AiDeclarationProposal.readiness(objectMapper,root.toString(),AiDraftReadiness.check(draftOf(root.toString()), java.time.OffsetDateTime.now(SHANGHAI)));
            root.set("readiness", objectMapper.valueToTree(ready));
            DraftChoices.writeSuggestions(objectMapper, root, java.time.OffsetDateTime.now(SHANGHAI));
            return root.toString();
        } catch (Exception unreadable) { return proposal; }
    }

    private String validateStored(String proposalJson) {
        List<String> errors = new ArrayList<>();
        try {
            JsonNode root = objectMapper.readTree(proposalJson == null ? "{}" : proposalJson);
            if (root.toString().contains("\"amount\"") || root.toString().contains("\"paymentMode\"") || root.toString().contains("\"qrFileId\"")) {
                errors.add("不能从资料写入收费金额、收费方式或收款码");
            }
            JsonNode review = root.path("event").path("registrationReview").path("value");
            if (review.isMissingNode()) {
                review = root.path("registrationReview");
            }
            String reviewText = review.asText("");
            if (!reviewText.isBlank() && !"manual".equals(reviewText) && !"none".equals(reviewText)) {
                errors.add("审核方式只能是人工审核或无需审核");
            }
            JsonNode units = root.path("units");
            if (units.isArray()) {
                for (JsonNode unit : units) {
                    String entry = unit.path("entryType").path("value").asText(unit.path("entryType").asText(""));
                    if (!entry.isBlank() && !"individual".equals(entry) && !"pair".equals(entry) && !"team".equals(entry)) {
                        errors.add("竞赛项目玩法无效");
                    }
                }
            }
        } catch (Exception exception) {
            errors.add("候选方案不是可读取的结构");
        }
        var readiness = AiDeclarationProposal.readiness(objectMapper,proposalJson,AiDraftReadiness.check(draftOf(proposalJson), java.time.OffsetDateTime.now(SHANGHAI)));
        errors.addAll(readiness.blockingIssues().stream().map(AiDraftReadiness.Issue::message).toList());
        ObjectNode result = objectMapper.createObjectNode();
        result.set("readiness", objectMapper.valueToTree(readiness));
        result.put("ok", errors.isEmpty());
        ArrayNode listed = result.putArray("errors");
        errors.forEach(listed::add);
        return result.toString();
    }

    private String readStored(SportsAiTask task, int fileIndex, String blockLabel) {
        try {
            JsonNode files = objectMapper.readTree(task.getExtraction() == null ? "{}" : task.getExtraction()).path("files");
            if (!files.isArray() || fileIndex < 0 || fileIndex >= files.size()) {
                return "{\"text\":\"\"}";
            }
            ArrayNode found = objectMapper.createArrayNode();
            for (JsonNode block : files.get(fileIndex).path("blocks")) {
                if (blockLabel == null || blockLabel.isBlank() || blockLabel.equals(block.path("label").asText())) {
                    found.add(block);
                }
            }
            ObjectNode result = objectMapper.createObjectNode();
            result.set("blocks", found);
            return result.toString();
        } catch (Exception exception) {
            return "{\"blocks\":[]}";
        }
    }

    private String constraints() {
        return "{\"scene\":\"" + AiTaskPolicy.SCENE + "\",\"review\":[\"manual\",\"none\"],\"entryType\":[\"individual\",\"pair\",\"team\"],\"fee\":\"manual_confirmation_required\",\"publish\":false}";
    }

    private String sanitize(String raw) {
        try {
            JsonNode incoming = objectMapper.readTree(raw == null ? "" : raw);
            if (!incoming.isObject()) {
                return null;
            }
            ObjectNode root = objectMapper.createObjectNode();
            root.put("version", 1);
            ObjectNode event = root.putObject("event");
            for (String field : EVENT_FIELDS) {
                JsonNode source = incoming.path("event").path(field);
                if (source.isMissingNode()) {
                    source = incoming.path(field);
                }
                event.set(field, copyField(source));
            }
            ArrayNode units = root.putArray("units");
            if (incoming.path("units").isArray()) {
                for (JsonNode unit : incoming.path("units")) {
                    ObjectNode copy = units.addObject();
                    for (String field : new String[] {"name", "entryType", "limitCount", "minMembers", "maxMembers", "feeAmount", "feeBasis"}) {
                        copy.set(field, copyField(unit.path(field)));
                    }
                }
            }
            root.putArray("warnings").add("请核对项目价格与原文后确认；未识别费用不会自动设成免费，保存不等于发布或收款。");
            return root.toString();
        } catch (Exception exception) {
            return null;
        }
    }

    private ObjectNode copyField(JsonNode source) {
        ObjectNode node = objectMapper.createObjectNode();
        if (source != null && source.isObject()) {
            node.put("value", source.path("value").asText(""));
            String status = source.path("status").asText("filled");
            if (!"missing".equals(status) && !"filled".equals(status) && !"conflict".equals(status) && !"suggestion".equals(status)) {
                status = "filled";
            }
            node.put("status", node.path("value").asText("").isBlank() && !"conflict".equals(status) ? "missing" : status);
            node.set("sources", source.path("sources").isArray() ? source.path("sources").deepCopy() : objectMapper.createArrayNode());
            node.set("alternatives", source.path("alternatives").isArray() ? source.path("alternatives").deepCopy() : objectMapper.createArrayNode());
            return node;
        }
        node.put("value", source == null || source.isMissingNode() || source.isNull() ? "" : source.asText(""));
        node.put("status", node.path("value").asText("").isBlank() ? "missing" : "filled");
        node.putArray("sources");
        node.putArray("alternatives");
        return node;
    }

    private List<Block> blocksOf(String extraction) {
        List<Block> blocks = new ArrayList<>();
        try {
            JsonNode files = objectMapper.readTree(extraction == null ? "{}" : extraction).path("files");
            if (!files.isArray()) {
                return blocks;
            }
            for (JsonNode file : files) {
                int fileIndex = file.path("fileIndex").asInt(0);
                for (JsonNode block : file.path("blocks")) {
                    blocks.add(new Block(fileIndex, block.path("kind").asText(""), block.path("label").asText(""), block.path("text").asText("")));
                }
            }
        } catch (Exception exception) {
            return blocks;
        }
        return blocks;
    }

    private SportsAiTask requireOwn(long taskId) {
        ManagedOrganization organization = organizer();
        SportsAiTask task = taskMapper.selectById(taskId);
        if (task == null || !AiTaskPolicy.sameOrganization(task.getOrganizationId(), organization.organizationId())) {
            throw new ServiceException("任务不存在");
        }
        return task;
    }

    private SportsAiTask requireAny(long taskId) {
        SportsAiTask task = TenantHelper.ignore(() -> taskMapper.selectById(taskId));
        if (task == null) {
            throw new ServiceException("任务不存在");
        }
        return task;
    }

    private void requireFile(long taskId, long fileId) {
        Long count = fileMapper.selectCount(Wrappers.<SportsAiTaskFile>lambdaQuery()
            .eq(SportsAiTaskFile::getTaskId, taskId)
            .eq(SportsAiTaskFile::getFileId, fileId));
        if (count == null || count == 0) {
            throw new ServiceException("资料不存在");
        }
    }

    private void requireFileInTenant(SportsAiTask task, long fileId) {
        Long count = TenantHelper.dynamic(task.getTenantId(), () -> fileMapper.selectCount(Wrappers.<SportsAiTaskFile>lambdaQuery()
            .eq(SportsAiTaskFile::getTaskId, task.getId())
            .eq(SportsAiTaskFile::getFileId, fileId)));
        if (count == null || count == 0) {
            throw new ServiceException("资料不存在");
        }
    }

    private List<SportsAiTaskFile> filesOf(long taskId) {
        return fileMapper.selectList(Wrappers.<SportsAiTaskFile>lambdaQuery()
            .eq(SportsAiTaskFile::getTaskId, taskId)
            .orderByAsc(SportsAiTaskFile::getSortOrder));
    }

    private TaskCard toCard(SportsAiTask task, List<SportsAiTaskFile> files) {
        List<FileCard> cards = new ArrayList<>();
        for (SportsAiTaskFile file : files) {
            cards.add(new FileCard(file.getFileId(), file.getSortOrder(), file.getMediaKind(), file.getOriginalName(), file.getPageCount()));
        }
        boolean published=false,draftEditable="PENDING_CONFIRMATION".equals(task.getStatus());String eventStatus=null;Integer eventVersion=null;
        if("CREATED".equals(task.getStatus())&&task.getResultObjectId()!=null){
            try{var state=eventService.aiDraftState(task.getResultObjectId());if(state!=null){eventStatus=state.event().publicationStatus();eventVersion=state.version();published="published".equals(eventStatus);draftEditable=state.draftEditable();}}
            catch(ServiceException inaccessible){draftEditable=false;}
        }
        return new TaskCard(task.getId(), task.getStatus(), task.getErrorCode(), task.getErrorMessage(),
            viewProposal(task.getProposal()), task.getExtraction(), task.getResultObjectId(), cards, task.getVersion(),published,eventStatus,draftEditable,eventVersion);
    }

    private ManagedOrganization organizer() {
        if (!LoginHelper.isLogin() || LoginHelper.getUserType() != UserType.SYS_USER) {
            throw new ServiceException("请先进入组织");
        }
        ManagedOrganization organization = sessionApi.managedOrganization(LoginHelper.getUserId())
            .orElseThrow(() -> new ServiceException("当前账号不能管理这个组织的赛事"));
        if (!organization.tenantId().equals(LoginHelper.getTenantId())) {
            throw new ServiceException("请先进入该组织");
        }
        return organization;
    }

    private void requireToken(String presented) {
        String expected = properties.getInternalToken();
        byte[] actual = presented == null ? new byte[0] : presented.getBytes(StandardCharsets.UTF_8);
        byte[] wanted = expected == null ? new byte[0] : expected.getBytes(StandardCharsets.UTF_8);
        if (!properties.tokenConfigured() || !MessageDigest.isEqual(wanted, actual)) {
            throw new ServiceException("内部调用未授权");
        }
    }

    private String message(String code) {
        return switch (code == null ? "" : code) {
            case "NEED_API_KEY" -> "资料已保留。配置模型后可以整理成草稿";
            case "KEY_ABSENT" -> "密钥为空，没有请求模型";
            case "INTERNAL_TOKEN_MISSING" -> "内部调用令牌还没配置，模型路径没有发出";
            case "MODEL_NOT_CONFIGURED" -> "请先配置文本模型和视觉模型名称";
            case "MODEL_TIMEOUT" -> "模型超时。任务和已有解析都还在，可以重试";
            case "MODEL_QUOTA" -> "模型额度不足。任务已保留，可以稍后重试";
            case "GATEWAY_UNAVAILABLE" -> "AI 网关没有连上。可以稍后重试";
            case "MODEL_FAILED" -> "模型没有返回可用结果，可以重试";
            case "PROJECT_GROUPS_INCOMPLETE" -> "原文项目分类没有完整读出，资料已保留，请重试并核对完整项目列表；没有创建赛事";
            case "SOURCE_FIELDS_INCOMPLETE" -> "原文字段依据没有通过校验。已保留读取记录，请查看处理过程中的具体字段后重试或补充；没有创建赛事";
            case "MODEL_OUTPUT_TRUNCATED" -> "模型返回内容超出本轮长度限制，候选没有采用。请查看处理记录后重试或拆分资料；没有创建赛事";
            case "MATERIAL_INCOMPLETE" -> "部分图片没有返回完整识别清单。已保留处理位置，请重试或对照原件补充；没有创建赛事";
            case "BUSY" -> "正在处理其他资料，原文件已保留，请稍后重试";
            default -> "识别没有完成，可以重试";
        };
    }

    private String cleanName(String name) {
        if (name == null || name.isBlank()) {
            return "未命名资料";
        }
        String trimmed = name.trim().replace('\\', '/');
        int slash = trimmed.lastIndexOf('/');
        String base = slash >= 0 ? trimmed.substring(slash + 1) : trimmed;
        return base.length() > 200 ? base.substring(0, 200) : base;
    }

    private record Prepared(String originalName, byte[] body, Extracted extracted) {
    }

    public record FileCard(Long fileId, Integer sortOrder, String mediaKind, String originalName, Integer pageCount) {
    }

    public record TaskCard(Long id, String status, String errorCode, String errorMessage, String proposal, String extraction,
                           Long resultObjectId, List<FileCard> files, Integer version,boolean published,String eventStatus,boolean draftEditable,Integer eventVersion) {
    }

    public record UnitDraft(String name, String entryType, Integer minMembers, Integer maxMembers, Integer limitCount,
                            String feeAmount, String feeBasis, String feeStatus) {
        public UnitDraft(String name, String entryType, Integer minMembers, Integer maxMembers, Integer limitCount) {
            this(name,entryType,minMembers,maxMembers,limitCount,null,null,null);
        }
    }

    public record ConfirmDraft(String requestKey, String name, String location, String projectName, String feeDescription,
                               String registrationOpensAt, String registrationClosesAt, String startsAt, String endsAt,
                               String registrationReview, String rulesText, List<UnitDraft> units,
                               String contactName, String contactMethod, String refundTerms,
                               String declarationText, Boolean declarationAckRequired, Integer expectedVersion) {
        public ConfirmDraft(String requestKey, String name, String location, String projectName, String feeDescription,
                            String registrationOpensAt, String registrationClosesAt, String startsAt, String endsAt,
                            String registrationReview, String rulesText, List<UnitDraft> units,
                            String contactName, String contactMethod, String refundTerms, Integer expectedVersion) {
            this(requestKey,name,location,projectName,feeDescription,registrationOpensAt,registrationClosesAt,startsAt,endsAt,
                registrationReview,rulesText,units,contactName,contactMethod,refundTerms,null,null,expectedVersion);
        }
        public ConfirmDraft(String requestKey, String name, String location, String projectName, String feeDescription,
                            String registrationOpensAt, String registrationClosesAt, String startsAt, String endsAt,
                            String registrationReview, String rulesText, List<UnitDraft> units,
                            String contactName, String contactMethod, String refundTerms) {
            this(requestKey,name,location,projectName,feeDescription,registrationOpensAt,registrationClosesAt,startsAt,endsAt,
                registrationReview,rulesText,units,contactName,contactMethod,refundTerms,null,null,null);
        }
        public ConfirmDraft withVersion(Integer version) {
            return new ConfirmDraft(requestKey,name,location,projectName,feeDescription,registrationOpensAt,registrationClosesAt,
                startsAt,endsAt,registrationReview,rulesText,units,contactName,contactMethod,refundTerms,declarationText,declarationAckRequired,version);
        }
        public ConfirmDraft withConsent(Integer version,Boolean required) {
            return new ConfirmDraft(requestKey,name,location,projectName,feeDescription,registrationOpensAt,registrationClosesAt,
                startsAt,endsAt,registrationReview,rulesText,units,contactName,contactMethod,refundTerms,declarationText,required,version);
        }
        /** 老调用仍只准备草稿；没有来源的新信息留空，不补默认退改承诺。 */
        public ConfirmDraft(String requestKey, String name, String location, String projectName, String feeDescription,
                            String registrationOpensAt, String registrationClosesAt, String startsAt, String endsAt,
                            String registrationReview, String rulesText, List<UnitDraft> units) {
            this(requestKey,name,location,projectName,feeDescription,registrationOpensAt,registrationClosesAt,
                startsAt,endsAt,registrationReview,rulesText,units,null,null,null);
        }
    }

    public record ConfirmResult(Long eventId, boolean replayed) {
    }

    public record TalkRequest(String message, Integer expectedVersion, Boolean declarationAckRequired) {
        public TalkRequest(String message) { this(message,null,null); }
    }

    public record TalkReply(String reply, List<String> suggestions, String action, String proposal, Long eventId, boolean created) {
    }
}
