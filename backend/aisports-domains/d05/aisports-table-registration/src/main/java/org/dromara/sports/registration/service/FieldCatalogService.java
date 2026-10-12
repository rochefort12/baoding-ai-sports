package org.dromara.sports.registration.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.EventRegistrationApi;
import org.dromara.sports.api.EventRegistrationApi.EventRegistrationGate;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.api.OrganizationSessionApi.ManagedOrganization;
import org.dromara.sports.api.PlatformAccountApi;
import org.dromara.sports.registration.domain.SportsCompetitionUnit;
import org.dromara.sports.registration.domain.SportsEntryFieldValue;
import org.dromara.sports.registration.domain.SportsEventField;
import org.dromara.sports.registration.domain.SportsOrgField;
import org.dromara.sports.registration.domain.SportsRegistration;
import org.dromara.sports.registration.domain.SportsRegistrationMember;
import org.dromara.sports.registration.mapper.SportsCompetitionUnitMapper;
import org.dromara.sports.registration.mapper.SportsEntryFieldValueMapper;
import org.dromara.sports.registration.mapper.SportsEventFieldMapper;
import org.dromara.sports.registration.mapper.SportsOrgFieldMapper;
import org.dromara.sports.registration.mapper.SportsRegistrationMapper;
import org.dromara.sports.registration.mapper.SportsRegistrationMemberMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * 组织字段目录、赛事选用和成员本人填写。默认存在这条报名上，不写入共享档案。
 */
@Service
@RequiredArgsConstructor
public class FieldCatalogService {

    private static final Pattern CODE = Pattern.compile("^[a-z][a-z0-9_]{0,63}$");
    private static final TypeReference<List<String>> STRINGS = new TypeReference<>() {
    };

    private final SportsOrgFieldMapper orgFieldMapper;
    private final SportsEventFieldMapper eventFieldMapper;
    private final SportsEntryFieldValueMapper valueMapper;
    private final SportsRegistrationMapper registrationMapper;
    private final SportsRegistrationMemberMapper memberMapper;
    private final SportsCompetitionUnitMapper unitMapper;
    private final EventRegistrationApi eventRegistrationApi;
    private final OrganizationSessionApi sessionApi;
    private final PlatformAccountApi platformAccountApi;
    private final ObjectMapper objectMapper;

    /** 仅由报名服务在同一租户、容量锁和删除事务中清理从未提交草稿的成员值。 */
    void deleteDraftValues(List<Long> memberIds) {
        if (!memberIds.isEmpty()) valueMapper.delete(Wrappers.<SportsEntryFieldValue>lambdaQuery()
            .in(SportsEntryFieldValue::getRegistrationMemberId, memberIds));
    }

    public List<OrgFieldCard> listOrgFields() {
        ManagedOrganization organization = requireOrganizer();
        return orgFieldMapper.selectList(Wrappers.<SportsOrgField>lambdaQuery()
                .eq(SportsOrgField::getOrganizationId, organization.organizationId())
                .orderByAsc(SportsOrgField::getId))
            .stream().map(this::toOrg).toList();
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.field_catalog_service.create_org_field", title="FieldCatalogService.createOrgField", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional(rollbackFor = Exception.class)
    public OrgFieldCard createOrgField(String code, String label, String valueType, List<String> options) {
        ManagedOrganization organization = requireOrganizer();
        String normalizedCode = requiredCode(code);
        String normalizedLabel = required(label, 100, "字段名称");
        String type = requiredType(valueType);
        String optionJson = optionJson(type, options);
        Long taken = orgFieldMapper.selectCount(Wrappers.<SportsOrgField>lambdaQuery()
            .eq(SportsOrgField::getOrganizationId, organization.organizationId())
            .eq(SportsOrgField::getCode, normalizedCode));
        if (taken != null && taken > 0) {
            throw new ServiceException("这个编码已经用过");
        }
        SportsOrgField field = new SportsOrgField();
        field.setOrganizationId(organization.organizationId());
        field.setCode(normalizedCode);
        field.setLabel(normalizedLabel);
        field.setValueType(type);
        field.setOptions(optionJson);
        field.setStatus("active");
        field.setVersion(0);
        orgFieldMapper.insert(field);
        return toOrg(field);
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.field_catalog_service.revise_org_field", title="FieldCatalogService.reviseOrgField", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional(rollbackFor = Exception.class)
    public OrgFieldCard reviseOrgField(Long fieldId, String label, String valueType, List<String> options) {
        ManagedOrganization organization = requireOrganizer();
        SportsOrgField field = requireOrgField(organization, fieldId);
        String type = requiredType(valueType);
        String optionJson = optionJson(type, options);
        boolean used = eventFieldMapper.selectCount(Wrappers.<SportsEventField>lambdaQuery()
            .eq(SportsEventField::getOrgFieldId, field.getId())) > 0;
        boolean sameType = type.equals(field.getValueType());
        boolean sameOptions = readOptions(optionJson).equals(readOptions(field.getOptions()));
        if (used && (!sameType || !sameOptions)) {
            throw new ServiceException("这个字段已经被赛事选用，不能改类型或选项");
        }
        field.setLabel(required(label, 100, "字段名称"));
        field.setValueType(type);
        field.setOptions(optionJson);
        if (orgFieldMapper.updateById(field) != 1) {
            throw new ServiceException("字段已被更新，请再试一次");
        }
        return toOrg(orgFieldMapper.selectById(field.getId()));
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.field_catalog_service.stop_org_field", title="FieldCatalogService.stopOrgField", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional(rollbackFor = Exception.class)
    public OrgFieldCard stopOrgField(Long fieldId) {
        ManagedOrganization organization = requireOrganizer();
        SportsOrgField field = requireOrgField(organization, fieldId);
        if (!"stopped".equals(field.getStatus())) {
            field.setStatus("stopped");
            if (orgFieldMapper.updateById(field) != 1) {
                throw new ServiceException("字段已被更新，请再试一次");
            }
        }
        return toOrg(orgFieldMapper.selectById(field.getId()));
    }

    public List<EventFieldCard> listEventFields(Long eventId) {
        requireManagedEvent(eventId);
        return eventFields(eventId).stream().map(this::toEvent).toList();
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.field_catalog_service.replace_event_fields", title="FieldCatalogService.replaceEventFields", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional(rollbackFor = Exception.class)
    public List<EventFieldCard> replaceEventFields(Long eventId, List<EventFieldDraft> drafts) {
        ManagedOrganization organization = requireOrganizer();
        EventRegistrationGate gate = requireManagedEvent(eventId);
        if (gate.registrationReviewLocked()) {
            throw new ServiceException("已有正式报名，不能再改采集项");
        }
        List<EventFieldDraft> items = drafts == null ? List.of() : drafts;
        Set<Long> wanted = new LinkedHashSet<>();
        for (EventFieldDraft draft : items) {
            if (draft == null || draft.orgFieldId() == null || !wanted.add(draft.orgFieldId())) {
                throw new ServiceException("采集项不能重复选用");
            }
        }
        List<SportsEventField> existing = eventFields(eventId);
        for (SportsEventField row : existing) {
            if (!wanted.contains(row.getOrgFieldId())) {
                deleteValues(row.getId());
                eventFieldMapper.deleteById(row.getId());
            }
        }
        int sort = 0;
        for (EventFieldDraft draft : items) {
            SportsOrgField field = requireOrgField(organization, draft.orgFieldId());
            if (!"active".equals(field.getStatus()) && existing.stream().noneMatch(row -> field.getId().equals(row.getOrgFieldId()))) {
                throw new ServiceException("停用的字段不能再选用");
            }
            SportsEventField row = eventFieldMapper.selectOne(Wrappers.<SportsEventField>lambdaQuery()
                .eq(SportsEventField::getEventId, eventId)
                .eq(SportsEventField::getOrgFieldId, field.getId()));
            if (row == null) {
                row = new SportsEventField();
                row.setEventId(eventId);
                row.setOrgFieldId(field.getId());
                row.setVersion(0);
            }
            row.setRequired(Boolean.TRUE.equals(draft.required()));
            row.setSortOrder(sort++);
            row.setNote(blankToNull(draft.note(), 500, "说明"));
            if (row.getId() == null) {
                eventFieldMapper.insert(row);
            } else if (eventFieldMapper.updateById(row) != 1) {
                throw new ServiceException("采集项已被更新，请再试一次");
            }
        }
        return eventFields(eventId).stream().map(this::toEvent).toList();
    }

    public List<EntryFieldCard> listMine(Long registrationId) {
        LocatedMember located = locateMine(registrationId);
        return TenantHelper.dynamic(located.registration().getTenantId(), () -> cardsFor(located));
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.registration.field_catalog_service.save_mine", title="FieldCatalogService.saveMine", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional(rollbackFor = Exception.class)
    public List<EntryFieldCard> saveMine(Long registrationId, List<ValueDraft> drafts) {
        LocatedMember located = locateMine(registrationId);
        return TenantHelper.dynamic(located.registration().getTenantId(), () -> {
            SportsRegistration registration = registrationMapper.selectById(registrationId);
            if (registration == null || !editable(registration)) {
                throw new ServiceException("报名已提交，不能再改采集项");
            }
            SportsRegistrationMember member = memberMapper.selectById(located.member().getId());
            if (member == null) {
                throw new ServiceException("你不在这条报名里");
            }
            Long eventId = eventIdOf(registration);
            for (ValueDraft draft : drafts == null ? List.<ValueDraft>of() : drafts) {
                SportsEventField eventField = eventFieldMapper.selectById(draft == null ? null : draft.eventFieldId());
                if (eventField == null || !eventId.equals(eventField.getEventId())) {
                    throw new ServiceException("这个采集项不属于这场赛事");
                }
                writeValue(member.getId(), eventField, draft == null ? null : draft.valueText());
            }
            return cardsFor(new LocatedMember(registration, member, eventId));
        });
    }

    /**
     * 正式提交前核对每位已确认成员的必填项，并把当时的名称和选项写入快照。
     */
    public void requireFilled(Long eventId, List<SportsRegistrationMember> confirmed) {
        List<SportsEventField> fields = eventFields(eventId);
        if (fields.isEmpty()) {
            return;
        }
        for (SportsRegistrationMember member : confirmed) {
            for (SportsEventField field : fields) {
                SportsEntryFieldValue value = valueOf(member.getId(), field.getId());
                String text = value == null ? "" : value.getValueText();
                String checked = checkValue(field, text, Boolean.TRUE.equals(field.getRequired()));
                if (checked == null) {
                    continue;
                }
                copySnapshot(value, field, checked);
                if (valueMapper.updateById(value) != 1) {
                    throw new ServiceException("采集项已被更新，请再提交一次");
                }
            }
        }
    }

    private List<EntryFieldCard> cardsFor(LocatedMember located) {
        List<EntryFieldCard> cards = new ArrayList<>();
        for (SportsEventField field : eventFields(located.eventId())) {
            SportsOrgField orgField = orgFieldMapper.selectById(field.getOrgFieldId());
            SportsEntryFieldValue value = valueOf(located.member().getId(), field.getId());
            cards.add(new EntryFieldCard(field.getId(), orgField == null ? "" : orgField.getLabel(),
                orgField == null ? "text" : orgField.getValueType(), readOptions(orgField == null ? "[]" : orgField.getOptions()),
                Boolean.TRUE.equals(field.getRequired()), field.getNote(), value == null ? "" : value.getValueText()));
        }
        return cards;
    }

    /** Freeze answers with their submitted labels; later catalog/profile edits cannot change the review evidence. */
    public List<java.util.Map<String, String>> snapshotValues(Long memberId) {
        return valueMapper.selectList(Wrappers.<SportsEntryFieldValue>lambdaQuery()
            .eq(SportsEntryFieldValue::getRegistrationMemberId, memberId).orderByAsc(SportsEntryFieldValue::getId))
            .stream().map(value -> {
                java.util.Map<String, String> item = new java.util.LinkedHashMap<>();
                item.put("label", value.getLabelSnapshot()); item.put("value", value.getValueText());
                return item;
            }).toList();
    }

    private void writeValue(Long memberId, SportsEventField field, String raw) {
        // 草稿允许逐项填写或清空；非空答案仍校验类型。必填完整性仅在
        // requireFilled 的正式提交事务核对，不能让“保存草稿”变成提交门槛。
        String checked = checkValue(field, raw, false);
        SportsEntryFieldValue value = valueOf(memberId, field.getId());
        if (checked == null) {
            if (value != null) {
                valueMapper.deleteById(value.getId());
            }
            return;
        }
        if (value == null) {
            value = new SportsEntryFieldValue();
            value.setRegistrationMemberId(memberId);
            value.setEventFieldId(field.getId());
            value.setVersion(0);
            copySnapshot(value, field, checked);
            valueMapper.insert(value);
            return;
        }
        copySnapshot(value, field, checked);
        if (valueMapper.updateById(value) != 1) {
            throw new ServiceException("采集项已被更新，请再试一次");
        }
    }

    private String checkValue(SportsEventField field, String raw, boolean required) {
        SportsOrgField orgField = orgFieldMapper.selectById(field.getOrgFieldId());
        String label = orgField == null ? "采集项" : orgField.getLabel();
        String text = raw == null ? "" : raw.trim();
        if (text.isEmpty()) {
            if (required) {
                throw new ServiceException("请填写" + label);
            }
            return null;
        }
        if (text.length() > 1000) {
            throw new ServiceException(label + "不超过1000字");
        }
        String type = orgField == null ? "text" : orgField.getValueType();
        if ("number".equals(type) && !text.matches("^-?\\d+(\\.\\d+)?$")) {
            throw new ServiceException(label + "需要填写数字");
        }
        if ("date".equals(type)) {
            try {
                LocalDate.parse(text);
            } catch (DateTimeParseException exception) {
                throw new ServiceException(label + "需要填写日期");
            }
        }
        if ("enum".equals(type) && !readOptions(orgField.getOptions()).contains(text)) {
            throw new ServiceException(label + "需要从选项里选择");
        }
        return text;
    }

    private void copySnapshot(SportsEntryFieldValue value, SportsEventField field, String text) {
        SportsOrgField orgField = orgFieldMapper.selectById(field.getOrgFieldId());
        value.setValueText(text);
        value.setLabelSnapshot(orgField == null ? "" : orgField.getLabel());
        value.setTypeSnapshot(orgField == null ? "text" : orgField.getValueType());
        value.setOptionsSnapshot(orgField == null ? "[]" : orgField.getOptions());
    }

    private void deleteValues(Long eventFieldId) {
        valueMapper.delete(Wrappers.<SportsEntryFieldValue>lambdaQuery()
            .eq(SportsEntryFieldValue::getEventFieldId, eventFieldId));
    }

    private SportsEntryFieldValue valueOf(Long memberId, Long eventFieldId) {
        return valueMapper.selectOne(Wrappers.<SportsEntryFieldValue>lambdaQuery()
            .eq(SportsEntryFieldValue::getRegistrationMemberId, memberId)
            .eq(SportsEntryFieldValue::getEventFieldId, eventFieldId));
    }

    private List<SportsEventField> eventFields(Long eventId) {
        return eventFieldMapper.selectList(Wrappers.<SportsEventField>lambdaQuery()
            .eq(SportsEventField::getEventId, eventId)
            .orderByAsc(SportsEventField::getSortOrder)
            .orderByAsc(SportsEventField::getId));
    }

    private LocatedMember locateMine(Long registrationId) {
        Long accountId = platformAccountApi.currentAccountId().orElseThrow(() -> new ServiceException("请使用参赛者账号登录"));
        SportsRegistration registration = TenantHelper.ignore(() -> registrationMapper.selectById(registrationId));
        if (registration == null) {
            throw new ServiceException("报名不存在");
        }
        SportsRegistrationMember member = TenantHelper.ignore(() -> memberMapper.selectOne(Wrappers.<SportsRegistrationMember>lambdaQuery()
            .eq(SportsRegistrationMember::getRegistrationId, registrationId)
            .eq(SportsRegistrationMember::getAccountId, accountId)));
        if (member == null) {
            throw new ServiceException("你不在这条报名里");
        }
        return new LocatedMember(registration, member, eventIdOf(registration));
    }

    private Long eventIdOf(SportsRegistration registration) {
        SportsCompetitionUnit unit = TenantHelper.ignore(() -> unitMapper.selectById(registration.getUnitId()));
        if (unit == null) {
            throw new ServiceException("竞赛项目不存在");
        }
        return unit.getEventId();
    }

    private boolean editable(SportsRegistration registration) {
        return "draft".equals(registration.getStatus()) || "rejected".equals(registration.getStatus());
    }

    private SportsOrgField requireOrgField(ManagedOrganization organization, Long fieldId) {
        SportsOrgField field = orgFieldMapper.selectById(fieldId);
        if (field == null || !organization.organizationId().equals(field.getOrganizationId())) {
            throw new ServiceException("字段不存在");
        }
        return field;
    }

    private EventRegistrationGate requireManagedEvent(Long eventId) {
        return eventRegistrationApi.managedGate(eventId).orElseThrow(() -> new ServiceException("赛事不存在"));
    }

    private ManagedOrganization requireOrganizer() {
        return sessionApi.managedOrganization(org.dromara.sports.platform.core.BusinessIdentity.getUserId())
            .orElseThrow(() -> new ServiceException("当前账号不能管理这个组织的字段"));
    }

    private OrgFieldCard toOrg(SportsOrgField field) {
        return new OrgFieldCard(field.getId(), field.getCode(), field.getLabel(), field.getValueType(),
            readOptions(field.getOptions()), field.getStatus());
    }

    private EventFieldCard toEvent(SportsEventField field) {
        SportsOrgField orgField = orgFieldMapper.selectById(field.getOrgFieldId());
        return new EventFieldCard(field.getId(), field.getOrgFieldId(), orgField == null ? "" : orgField.getLabel(),
            orgField == null ? "" : orgField.getValueType(), Boolean.TRUE.equals(field.getRequired()),
            field.getSortOrder() == null ? 0 : field.getSortOrder(), field.getNote());
    }

    private List<String> readOptions(String json) {
        if (json == null || json.isBlank()) {
            return List.of();
        }
        try {
            List<String> values = objectMapper.readValue(json, STRINGS);
            return values == null ? List.of() : values;
        } catch (JsonProcessingException exception) {
            return List.of();
        }
    }

    private String optionJson(String type, List<String> options) {
        List<String> clean = new ArrayList<>();
        if ("enum".equals(type)) {
            for (String option : options == null ? List.<String>of() : options) {
                String text = option == null ? "" : option.trim();
                if (text.isEmpty() || text.length() > 40 || clean.contains(text)) {
                    throw new ServiceException("单选项需要填写不重复的选项");
                }
                clean.add(text);
            }
            if (clean.isEmpty()) {
                throw new ServiceException("单选项至少要有一个选项");
            }
        }
        try {
            return objectMapper.writeValueAsString(clean);
        } catch (JsonProcessingException exception) {
            throw new ServiceException("选项无法保存");
        }
    }

    private String requiredType(String valueType) {
        String type = valueType == null ? "" : valueType.trim();
        if (!type.equals("text") && !type.equals("number") && !type.equals("date") && !type.equals("enum")) {
            throw new ServiceException("字段类型不正确");
        }
        return type;
    }

    private String requiredCode(String code) {
        String text = code == null ? "" : code.trim();
        if (!CODE.matcher(text).matches()) {
            throw new ServiceException("编码使用小写字母、数字和下划线");
        }
        return text;
    }

    private String required(String value, int max, String label) {
        String text = value == null ? "" : value.trim();
        if (text.isEmpty()) {
            throw new ServiceException("请填写" + label);
        }
        if (text.length() > max) {
            throw new ServiceException(label + "不超过" + max + "字");
        }
        return text;
    }

    private String blankToNull(String value, int max, String label) {
        String text = value == null ? "" : value.trim();
        if (text.isEmpty()) {
            return null;
        }
        if (text.length() > max) {
            throw new ServiceException(label + "不超过" + max + "字");
        }
        return text;
    }

    public record OrgFieldCard(Long id, String code, String label, String valueType, List<String> options, String status) {
    }

    public record EventFieldCard(Long id, Long orgFieldId, String label, String valueType, boolean required, int sortOrder, String note) {
    }

    public record EntryFieldCard(Long eventFieldId, String label, String valueType, List<String> options, boolean required,
                                 String note, String valueText) {
    }

    public record EventFieldDraft(Long orgFieldId, Boolean required, String note) {
    }

    public record ValueDraft(Long eventFieldId, String valueText) {
    }

    private record LocatedMember(SportsRegistration registration, SportsRegistrationMember member, Long eventId) {
    }
}
