package org.dromara.sports.identity.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.sports.api.AccountClosureApi;
import org.dromara.sports.api.CallerContext;
import org.dromara.sports.api.PersonApi;
import org.dromara.sports.api.PlatformAccountApi.InviteCandidate;
import org.dromara.sports.api.PlatformAccountApi.MemberLabel;
import org.dromara.sports.api.PlatformAccountApi.RegistrationProfile;
import org.dromara.sports.identity.domain.SportsAccount;
import org.dromara.sports.identity.domain.SportsConsent;
import org.dromara.sports.identity.domain.SportsPerson;
import org.dromara.sports.identity.domain.SportsLoginIdentity;
import org.dromara.sports.identity.mapper.SportsAccountMapper;
import org.dromara.sports.identity.mapper.SportsConsentMapper;
import org.dromara.sports.identity.mapper.SportsLoginIdentityMapper;
import org.dromara.sports.identity.mapper.SportsPersonMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import cn.hutool.crypto.digest.BCrypt;
import cn.hutool.crypto.SecureUtil;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashMap;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

/**
 * 平台身份。同名只是展示名，不能并成同一个参赛人。一名账号只绑定自己的档案。
 */
@Service
@RequiredArgsConstructor
public class IdentityService implements PersonApi {

    public static final String REGISTER = "register";
    public static final String SELF_PROFILE = "self-profile";
    public static final String CHILD_PROXY = "child-proxy";
    public static final String SELF_PROFILE_VERSION = "m1.1-self-profile";
    public static final String CHILD_PROXY_VERSION = "m1.1-child-proxy";
    public static final String PHONE_CHANNEL = "phone";
    private static final ZoneId SHANGHAI_ZONE = ZoneId.of("Asia/Shanghai");
    private static final ZoneOffset SHANGHAI = ZoneOffset.ofHours(8);

    private final SportsAccountMapper accountMapper;
    private final SportsPersonMapper personMapper;
    private final SportsConsentMapper consentMapper;
    private final SportsLoginIdentityMapper loginIdentityMapper;
    private final AccountClosureApi accountClosureApi;
    private final ProfileTraceService profileTraceService;

    @Value("${participant.phone-pepper:}")
    private String phonePepper;

    @org.dromara.sports.platform.core.SportsAction(value="legacy.account.identity_service.ensure_account", title="IdentityService.ensureAccount", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_consent","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_login_identity","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_consent","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_login_identity","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional
    public SportsAccount ensureAccount(Long backendUserId, String displayName) {
        if (backendUserId != null) {
            SportsAccount existing = accountMapper.selectOne(Wrappers.<SportsAccount>lambdaQuery()
                .eq(SportsAccount::getBackendUserId, backendUserId)
                .eq(SportsAccount::getStatus, "active"));
            if (existing != null) {
                return existing;
            }
        }
        return openAccount(displayName, backendUserId);
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.account.identity_service.open_account", title="IdentityService.openAccount", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_consent","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_login_identity","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_consent","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_login_identity","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional
    public SportsAccount openAccount(String displayName, Long backendUserId) {
        SportsAccount account = new SportsAccount();
        account.setDisplayName(requiredName(displayName));
        account.setBackendUserId(backendUserId);
        account.setStatus("active");
        account.setVersion(0);
        accountMapper.insert(account);
        return account;
    }

    /**
     * 短信验证通过后绑定手机号。摘要判重，不把明文号码写成渠道标识。
     */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.account.identity_service.bind_verified_phone", title="IdentityService.bindVerifiedPhone", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_consent","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_login_identity","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_consent","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_login_identity","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional
    public void bindVerifiedPhone(Long accountId, String phone) {
        requireActiveAccount(accountId);
        String hash = phoneHash(phone);
        Long existing = loginIdentityMapper.selectCount(Wrappers.<SportsLoginIdentity>lambdaQuery()
            .eq(SportsLoginIdentity::getChannel, PHONE_CHANNEL)
            .eq(SportsLoginIdentity::getSubjectHash, hash)
            .isNull(SportsLoginIdentity::getValidUntil));
        if (existing != null && existing > 0) {
            throw new ServiceException("手机号已注册");
        }
        SportsLoginIdentity identity = new SportsLoginIdentity();
        identity.setAccountId(accountId);
        identity.setChannel(PHONE_CHANNEL);
        identity.setSubjectHash(hash);
        identity.setValidFrom(now());
        identity.setVerificationSource("sms");
        identity.setVersion(0);
        loginIdentityMapper.insert(identity);
    }

    /**
     * 修改平台登录密码。只改平台账号上的散列，不改后台用户密码。
     */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.account.identity_service.change_login_password", title="IdentityService.changeLoginPassword", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_consent","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_login_identity","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_consent","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_login_identity","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional
    public void changeLoginPassword(Long accountId, String oldPassword, String newPassword) {
        if (newPassword == null || newPassword.length() < 6 || newPassword.length() > 20) {
            throw new ServiceException("新密码长度需要在 6 到 20 个字符");
        }
        if (newPassword.chars().anyMatch(ch -> "<>\"'|\\".indexOf(ch) >= 0)) {
            throw new ServiceException("密码不能包含非法字符");
        }
        SportsAccount account = requireActiveAccount(accountId);
        if (account.getPasswordHash() == null || account.getPasswordHash().isBlank()
            || oldPassword == null || !BCrypt.checkpw(oldPassword, account.getPasswordHash())) {
            throw new ServiceException("修改密码失败，旧密码错误");
        }
        if (BCrypt.checkpw(newPassword, account.getPasswordHash())) {
            throw new ServiceException("新密码不能与旧密码相同");
        }
        account.setPasswordHash(BCrypt.hashpw(newPassword));
        accountMapper.updateById(account);
    }

    /**
     * 已验证且仍有效的手机号对应的平台账号。没有绑定时为空，不说明原因。
     */
    public Optional<Long> findVerifiedAccountId(String phone) {
        String normalized = phone == null ? "" : phone.trim();
        if (!normalized.matches("^1[3-9]\\d{9}$")) {
            return Optional.empty();
        }
        SportsLoginIdentity identity = loginIdentityMapper.selectOne(Wrappers.<SportsLoginIdentity>lambdaQuery()
            .eq(SportsLoginIdentity::getChannel, PHONE_CHANNEL)
            .eq(SportsLoginIdentity::getSubjectHash, phoneHash(normalized))
            .isNull(SportsLoginIdentity::getValidUntil));
        if (identity == null) {
            return Optional.empty();
        }
        SportsAccount account = accountMapper.selectById(identity.getAccountId());
        if (account == null || !"active".equals(account.getStatus())) {
            return Optional.empty();
        }
        return Optional.of(account.getId());
    }

    /**
     * 重置平台登录密码。只改平台账号散列，不改后台用户密码，也不改档案或手机号绑定。
     */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.account.identity_service.replace_login_password", title="IdentityService.replaceLoginPassword", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_consent","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_login_identity","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_consent","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_login_identity","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional
    public void replaceLoginPassword(Long accountId, String rawPassword) {
        SportsAccount account = requireActiveAccount(accountId);
        account.setPasswordHash(BCrypt.hashpw(rawPassword));
        if (accountMapper.updateById(account) != 1) {
            throw new ServiceException("暂时不能重置密码，请稍后再试");
        }
    }

    /**
     * 保存平台登录密码。散列只落在平台账号上。
     */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.account.identity_service.set_login_password", title="IdentityService.setLoginPassword", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_consent","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_login_identity","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_consent","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_login_identity","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional
    public void setLoginPassword(Long accountId, String rawPassword) {
        SportsAccount account = requireActiveAccount(accountId);
        account.setPasswordHash(BCrypt.hashpw(rawPassword));
        accountMapper.updateById(account);
    }

    /**
     * 已验证、仍有效的手机号账号。格式不对、未绑定或已停用时为空，不说明原因。
     */
    public SportsAccount findActivePhoneAccount(String phone) {
        String normalized = phone == null ? "" : phone.trim();
        if (!normalized.matches("^1[3-9]\\d{9}$")) {
            return null;
        }
        SportsLoginIdentity identity = loginIdentityMapper.selectOne(Wrappers.<SportsLoginIdentity>lambdaQuery()
            .eq(SportsLoginIdentity::getChannel, PHONE_CHANNEL)
            .eq(SportsLoginIdentity::getSubjectHash, phoneHash(normalized))
            .isNull(SportsLoginIdentity::getValidUntil));
        if (identity == null) {
            return null;
        }
        SportsAccount account = accountMapper.selectById(identity.getAccountId());
        if (account == null || !"active".equals(account.getStatus())) {
            return null;
        }
        return account;
    }

    /**
     * 用已验证手机号和密码确认平台账号。不查询后台用户。
     */
    public SportsAccount authenticatePhone(String phone, String rawPassword) {
        String normalized = phone == null ? "" : phone.trim();
        if (!normalized.matches("^1[3-9]\\d{9}$")) {
            throw new ServiceException("手机号或密码错误");
        }
        SportsLoginIdentity identity = loginIdentityMapper.selectOne(Wrappers.<SportsLoginIdentity>lambdaQuery()
            .eq(SportsLoginIdentity::getChannel, PHONE_CHANNEL)
            .eq(SportsLoginIdentity::getSubjectHash, phoneHash(normalized))
            .isNull(SportsLoginIdentity::getValidUntil));
        if (identity == null) {
            throw new ServiceException("手机号或密码错误");
        }
        SportsAccount account = requireActiveAccount(identity.getAccountId());
        if (account.getPasswordHash() == null || account.getPasswordHash().isBlank()
            || rawPassword == null || !BCrypt.checkpw(rawPassword, account.getPasswordHash())) {
            throw new ServiceException("手机号或密码错误");
        }
        return account;
    }

    public SportsAccount requireAccount(Long accountId) {
        return requireActiveAccount(accountId);
    }

    public String phoneHash(String phone) {
        if (phonePepper == null || phonePepper.isBlank()) {
            throw new IllegalStateException("缺少手机号摘要密钥");
        }
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                .digest((phonePepper + "\n" + phone).getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 不可用", exception);
        }
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.account.identity_service.bind_self", title="IdentityService.bindSelf", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_consent","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_login_identity","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_consent","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_login_identity","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional
    public SportsPerson bindSelf(Long accountId, String legalName, LocalDate birthDate, String gender, String mobile) {
        return bindSelf(accountId, PersonDraft.basic(legalName, birthDate, gender, mobile));
    }

    /**
     * 保存本人通用档案。没有档案时建立并绑定；已有档案时按本次提交覆盖，选填项可以清空。
     */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.account.identity_service.bind_self", title="IdentityService.bindSelf", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_consent","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_login_identity","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_consent","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_login_identity","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional
    public SportsPerson bindSelf(Long accountId, PersonDraft draft) {
        draft = withVerifiedPhone(draft);
        SportsAccount account = requireActiveAccount(accountId);
        if (account.getPersonId() == null) {
            SportsPerson person = insertPerson(draft);
            int version = account.getVersion() == null ? 0 : account.getVersion();
            int bound = accountMapper.update(null, Wrappers.<SportsAccount>lambdaUpdate()
                .eq(SportsAccount::getId, account.getId())
                .isNull(SportsAccount::getPersonId)
                .eq(SportsAccount::getVersion, version)
                .set(SportsAccount::getPersonId, person.getId())
                .set(SportsAccount::getVersion, version + 1));
            if (bound != 1) {
                throw new ServiceException("档案已被更新，请刷新后再试");
            }
            accept(accountId, person.getId(), SELF_PROFILE, SELF_PROFILE_VERSION, "{\"action\":\"self-profile\"}");
            profileTraceService.profileChanged(accountId, person.getId(), List.of("created"));
            return person;
        }
        SportsPerson person = personMapper.selectById(account.getPersonId());
        List<String> changed = changedFields(person, draft);
        applyDraft(person, draft);
        int saved = personMapper.update(null, Wrappers.<SportsPerson>lambdaUpdate()
            .eq(SportsPerson::getId, person.getId())
            .set(SportsPerson::getLegalName, person.getLegalName())
            .set(SportsPerson::getBirthDate, person.getBirthDate())
            .set(SportsPerson::getGender, person.getGender())
            .set(SportsPerson::getMobile, person.getMobile())
            .set(SportsPerson::getIdDocType, person.getIdDocType())
            .set(SportsPerson::getIdentityHash, person.getIdentityHash())
            .set(SportsPerson::getIdentityCipher, person.getIdentityCipher())
            .set(SportsPerson::getCity, person.getCity())
            .set(SportsPerson::getAddressDetail, person.getAddressDetail())
            .set(SportsPerson::getBloodType, person.getBloodType())
            .set(SportsPerson::getClothingSize, person.getClothingSize())
            .set(SportsPerson::getEmergencyContactName, person.getEmergencyContactName())
            .set(SportsPerson::getEmergencyContactPhone, person.getEmergencyContactPhone()));
        if (saved != 1) {
            throw new ServiceException("档案已被更新，请刷新后再试");
        }
        if (!changed.isEmpty()) {
            profileTraceService.profileChanged(accountId, person.getId(), changed);
        }
        return person;
    }

    public void submitFeedback(Long accountId, String topic, String detail) {
        requireActiveAccount(accountId);
        String kind = topic == null ? "" : topic.trim();
        if (!kind.equals("event") && !kind.equals("account") && !kind.equals("other")) {
            throw new ServiceException("请选择问题类型");
        }
        String text = detail == null ? "" : detail.trim();
        if (text.isEmpty() || text.length() > 1000) {
            throw new ServiceException("请用 1000 字以内说明问题");
        }
        profileTraceService.feedback(accountId, kind, text);
    }

    /**
     * 新账号遇到已有证件时，只在原账号已经关闭后关联同一份档案。不恢复旧登录。
     */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.account.identity_service.link_closed_identity", title="IdentityService.linkClosedIdentity", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_consent","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_login_identity","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_consent","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_login_identity","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional
    public void linkClosedIdentity(Long accountId, String idType, String idNumber, String reason) {
        String note = reason == null ? "" : reason.trim();
        if (note.isEmpty() || note.length() > 500) {
            throw new ServiceException("请填写核验理由");
        }
        SportsAccount account = requireActiveAccount(accountId);
        if (account.getPersonId() != null) {
            throw new ServiceException("这个账号已经有档案");
        }
        String normalizedType = idType == null ? "" : idType.trim();
        String normalizedNumber = normalizeIdNumber(normalizedType, idNumber == null ? null : idNumber.trim());
        if (normalizedNumber == null || normalizedNumber.isBlank()) {
            throw new ServiceException("请填写证件号码");
        }
        String hash = phoneHash(normalizedType + "\n" + normalizedNumber);
        SportsPerson person = personMapper.selectOne(Wrappers.<SportsPerson>lambdaQuery()
            .eq(SportsPerson::getIdentityHash, hash)
            .eq(SportsPerson::getStatus, "active"));
        if (person == null) {
            throw new ServiceException("没有找到这份证件的档案");
        }
        List<SportsAccount> holders = accountMapper.selectList(Wrappers.<SportsAccount>lambdaQuery()
            .eq(SportsAccount::getPersonId, person.getId()));
        boolean activeHolder = holders.stream().anyMatch(holder -> "active".equals(holder.getStatus()));
        if (activeHolder) {
            throw new ServiceException("这份证件仍绑定在有效账号上");
        }
        int version = account.getVersion() == null ? 0 : account.getVersion();
        int bound = accountMapper.update(null, Wrappers.<SportsAccount>lambdaUpdate()
            .eq(SportsAccount::getId, account.getId())
            .isNull(SportsAccount::getPersonId)
            .eq(SportsAccount::getVersion, version)
            .set(SportsAccount::getPersonId, person.getId())
            .set(SportsAccount::getVersion, version + 1));
        if (bound != 1) {
            throw new ServiceException("账号已被更新，请再试一次");
        }
        profileTraceService.identityLinked(accountId, accountId, person.getId(), note);
    }

    public boolean isSelf(Long accountId, Long personId) {
        if (accountId == null || personId == null) {
            return false;
        }
        SportsAccount account = accountMapper.selectById(accountId);
        return account != null && personId.equals(account.getPersonId());
    }

    /**
     * 报名段用来判断能否替自己报名。未建档或必填未齐时为 false。这里不开放报名入口。
     */
    /**
     * 按已验证手机号找平台账号。展示名不包含证件。档案未齐时仍可邀请，确认时再要求档案。
     */
    public Optional<InviteCandidate> findInviteCandidate(String phone) {
        String normalized = phone == null ? "" : phone.trim();
        if (!normalized.matches("^1[3-9]\\d{9}$")) {
            return Optional.empty();
        }
        SportsLoginIdentity identity = loginIdentityMapper.selectOne(Wrappers.<SportsLoginIdentity>lambdaQuery()
            .eq(SportsLoginIdentity::getChannel, PHONE_CHANNEL)
            .eq(SportsLoginIdentity::getSubjectHash, phoneHash(normalized))
            .isNull(SportsLoginIdentity::getValidUntil));
        if (identity == null) {
            return Optional.empty();
        }
        SportsAccount account = accountMapper.selectById(identity.getAccountId());
        if (account == null || !"active".equals(account.getStatus())) {
            return Optional.empty();
        }
        SportsPerson person = account.getPersonId() == null ? null : personMapper.selectById(account.getPersonId());
        boolean ready = profileReady(person);
        return Optional.of(new InviteCandidate(account.getId(), account.getDisplayName(), ready, ready ? person.getId() : null));
    }

    /**
     * 报名快照只取本人必填档案，不带证件号码。
     */
    public Optional<RegistrationProfile> registrationProfile(Long accountId) {
        if (accountId == null) {
            return Optional.empty();
        }
        SportsAccount account = accountMapper.selectById(accountId);
        if (account == null || !"active".equals(account.getStatus()) || account.getPersonId() == null) {
            return Optional.empty();
        }
        SportsPerson person = personMapper.selectById(account.getPersonId());
        if (!profileReady(person)) {
            return Optional.empty();
        }
        return Optional.of(new RegistrationProfile(account.getId(), person.getId(), person.getLegalName(),
            person.getGender(), person.getBirthDate(), person.getMobile()));
    }

    /**
     * 只给已经授权查看这些队员的服务使用。这里不判断队伍关系。
     */
    public List<MemberLabel> memberLabels(Collection<Long> personIds) {
        if (personIds == null || personIds.isEmpty()) {
            return List.of();
        }
        List<SportsPerson> people = personMapper.selectList(Wrappers.<SportsPerson>lambdaQuery()
            .in(SportsPerson::getId, personIds));
        List<SportsAccount> accounts = accountMapper.selectList(Wrappers.<SportsAccount>lambdaQuery()
            .in(SportsAccount::getPersonId, personIds));
        Map<Long, SportsAccount> accountByPerson = new HashMap<>();
        for (SportsAccount account : accounts) {
            accountByPerson.putIfAbsent(account.getPersonId(), account);
        }
        List<MemberLabel> labels = new ArrayList<>();
        for (SportsPerson person : people) {
            SportsAccount account = accountByPerson.get(person.getId());
            boolean selectable = account != null && "active".equals(account.getStatus()) && profileReady(person);
            labels.add(new MemberLabel(person.getId(), account == null ? null : account.getId(), person.getLegalName(), selectable));
        }
        return labels;
    }

    public boolean profileReady(SportsPerson person) {
        return person != null
            && "active".equals(person.getStatus())
            && person.getLegalName() != null && !person.getLegalName().isBlank()
            && person.getBirthDate() != null
            && !person.getBirthDate().isAfter(LocalDate.now(SHANGHAI_ZONE))
            && person.getGender() != null && !person.getGender().isBlank()
            && person.getMobile() != null && !person.getMobile().isBlank();
    }

    public IdentityHome home(Long accountId) {
        SportsAccount account = accountMapper.selectById(accountId);
        SportsPerson selfPerson = account.getPersonId() == null ? null : personMapper.selectById(account.getPersonId());
        PersonCard self = selfPerson == null ? null : toCard(selfPerson, true);
        return new IdentityHome(account.getId(), account.getDisplayName(), self, List.of(), List.of(), verifiedLoginPhone());
    }

    @Override
    public Optional<PersonSummary> findAuthorized(CallerContext caller, Long personId, String purpose) {
        if (!REGISTER.equals(purpose) || !isSelf(caller.accountId(), personId)) {
            return Optional.empty();
        }
        SportsPerson person = personMapper.selectById(personId);
        if (!profileReady(person)) {
            return Optional.empty();
        }
        return Optional.of(new PersonSummary(person.getId(), shownName(person), "verified".equals(person.getVerificationStatus())));
    }

    @Override
    public boolean canRegister(CallerContext caller, Long personId) {
        if (!isSelf(caller.accountId(), personId)) {
            return false;
        }
        return profileReady(personMapper.selectById(personId));
    }

    private String normalizeIdNumber(String idType, String idNumber) {
        if (idNumber == null || !"id_card".equals(idType)) {
            return idNumber;
        }
        return idNumber.toUpperCase(java.util.Locale.ROOT);
    }

    private SportsPerson insertPerson(PersonDraft draft) {
        SportsPerson person = new SportsPerson();
        applyDraft(person, draft);
        person.setVerificationStatus("unverified");
        person.setStatus("active");
        person.setVersion(0);
        personMapper.insert(person);
        return person;
    }

    private void applyDraft(SportsPerson person, PersonDraft draft) {
        person.setLegalName(requiredLegalName(draft.legalName()));
        if (draft.birthDate() == null) {
            throw new ServiceException("请填写出生日期");
        }
        if (draft.birthDate().isAfter(LocalDate.now(SHANGHAI_ZONE))) {
            throw new ServiceException("出生日期不能晚于今天");
        }
        person.setBirthDate(draft.birthDate());
        person.setGender(requiredGender(draft.gender()));
        person.setMobile(requiredMobile(draft.mobile()));
        String idType = blankToNull(draft.idDocType());
        String idNumber = normalizeIdNumber(idType, blankToNull(draft.idNumber()));
        if ((idType == null) != (idNumber == null)) {
            throw new ServiceException("请同时填写证件类型和证件号码");
        }
        if (idType != null && !Set.of("id_card", "passport", "hmt_pass", "other").contains(idType)) {
            throw new ServiceException("证件类型无效");
        }
        String hash = idNumber == null ? null : phoneHash(idType + "\n" + idNumber);
        if (hash != null) {
            Long duplicated = personMapper.selectCount(Wrappers.<SportsPerson>lambdaQuery()
                .eq(SportsPerson::getIdentityHash, hash)
                .eq(SportsPerson::getStatus, "active")
                .ne(person.getId() != null, SportsPerson::getId, person.getId()));
            if (duplicated != null && duplicated > 0) {
                throw new ServiceException("这份证件已经有档案，请通过平台核验，不能另建一份");
            }
        }
        person.setIdDocType(idType);
        person.setIdentityHash(hash);
        person.setIdentityCipher(idNumber == null ? null : SecureUtil.aes(aesKey()).encryptHex(idNumber));
        person.setCity(limit(blankToNull(draft.city()), 100, "所在城市"));
        person.setAddressDetail(limit(blankToNull(draft.addressDetail()), 200, "详细地址"));
        person.setBloodType(optionalEnum(draft.bloodType(), Set.of("A", "B", "AB", "O", "unknown"), "血型无效"));
        person.setClothingSize(optionalEnum(draft.clothingSize(), Set.of("XS", "S", "M", "L", "XL", "XXL", "XXXL"), "衣服尺码无效"));
        person.setEmergencyContactName(limit(blankToNull(draft.emergencyContactName()), 100, "紧急联系人"));
        person.setEmergencyContactPhone(optionalMobile(draft.emergencyContactPhone()));
    }

    private void accept(Long accountId, Long personId, String purpose, String documentVersion, String scope) {
        SportsConsent consent = new SportsConsent();
        consent.setPersonId(personId);
        consent.setActorAccountId(accountId);
        consent.setPurpose(purpose);
        consent.setDocumentVersion(documentVersion);
        consent.setScope(scope);
        consent.setAcceptedAt(now());
        consent.setEvidenceHash(evidence(documentVersion, purpose, scope));
        consent.setVersion(0);
        consentMapper.insert(consent);
    }

    private String evidence(String documentVersion, String purpose, String scope) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                .digest((documentVersion + "\n" + purpose + "\n" + scope).getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 不可用", exception);
        }
    }

    /**
     * 注销验证码只能发给当前登录账号仍有效的手机号。
     */
    public void assertVerifiedPhone(Long accountId, String phone) {
        requireActiveAccount(accountId);
        SportsLoginIdentity identity = loginIdentityMapper.selectOne(Wrappers.<SportsLoginIdentity>lambdaQuery()
            .eq(SportsLoginIdentity::getAccountId, accountId)
            .eq(SportsLoginIdentity::getChannel, PHONE_CHANNEL)
            .eq(SportsLoginIdentity::getSubjectHash, phoneHash(phone))
            .isNull(SportsLoginIdentity::getValidUntil));
        if (identity == null) {
            throw new ServiceException("请使用已验证的手机号注销");
        }
    }

    public List<String> closureBlocks(Long accountId) {
        SportsAccount account = requireActiveAccount(accountId);
        return accountClosureApi.blocks(accountId, account.getPersonId());
    }

    /**
     * 约束通过后关闭账号并结束手机号绑定。历史报名和档案保留，不自动撤回。
     */
    @org.dromara.sports.platform.core.SportsAction(value="legacy.account.identity_service.close_account", title="IdentityService.closeAccount", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_consent","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_login_identity","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_consent","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_login_identity","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional
    public Long closeAccount(Long accountId) {
        SportsAccount account = requireActiveAccount(accountId);
        List<String> blocks = accountClosureApi.blocks(accountId, account.getPersonId());
        if (!blocks.isEmpty()) {
            throw new ServiceException(String.join("；", blocks));
        }
        account.setStatus("closed");
        account.setClosedAt(OffsetDateTime.now(SHANGHAI));
        if (accountMapper.updateById(account) != 1) {
            throw new ServiceException("账号已被更新，请再试一次");
        }
        List<SportsLoginIdentity> phones = loginIdentityMapper.selectList(Wrappers.<SportsLoginIdentity>lambdaQuery()
            .eq(SportsLoginIdentity::getAccountId, accountId)
            .eq(SportsLoginIdentity::getChannel, PHONE_CHANNEL)
            .isNull(SportsLoginIdentity::getValidUntil));
        for (SportsLoginIdentity identity : phones) {
            identity.setValidUntil(OffsetDateTime.now(SHANGHAI));
            if (loginIdentityMapper.updateById(identity) != 1) {
                throw new ServiceException("手机号绑定已被更新，请再试一次");
            }
        }
        return account.getBackendUserId();
    }

    private SportsAccount requireActiveAccount(Long accountId) {
        SportsAccount account = accountMapper.selectById(accountId);
        if (account == null || !"active".equals(account.getStatus())) {
            throw new ServiceException("平台账号不存在或已停用");
        }
        return account;
    }

    public PersonCard profileCard(SportsPerson person, boolean boundToMe) {
        return toCard(person, boundToMe);
    }

    private PersonCard toCard(SportsPerson person, boolean boundToMe) {
        return new PersonCard(person.getId(), person.getLegalName(), person.getDisplayName(), person.getBirthDate(),
            person.getGender(), person.getMobile(), person.getIdDocType(), boundToMe ? decryptId(person.getIdentityCipher()) : null,
            person.getCity(), person.getAddressDetail(), person.getBloodType(), person.getClothingSize(),
            person.getEmergencyContactName(), person.getEmergencyContactPhone(), boundToMe);
    }

    private String shownName(SportsPerson person) {
        if (person.getDisplayName() != null && !person.getDisplayName().isBlank()) {
            return person.getDisplayName();
        }
        return person.getLegalName();
    }

    private String requiredName(String displayName) {
        if (displayName == null || displayName.isBlank() || displayName.length() > 100) {
            throw new ServiceException("请填写不超过100字的姓名");
        }
        return displayName.trim();
    }

    private String requiredLegalName(String legalName) {
        if (legalName == null || legalName.isBlank() || legalName.trim().length() > 100) {
            throw new ServiceException("请填写不超过100字的真实姓名");
        }
        return legalName.trim();
    }

    private String requiredGender(String gender) {
        if (gender == null || !Set.of("male", "female", "other").contains(gender)) {
            throw new ServiceException("请选择性别");
        }
        return gender;
    }

    private List<String> changedFields(SportsPerson current, PersonDraft draft) {
        List<String> changed = new java.util.ArrayList<>();
        if (!java.util.Objects.equals(current.getLegalName(), draft.legalName())) {
            changed.add("legalName");
        }
        if (!java.util.Objects.equals(current.getBirthDate(), draft.birthDate())) {
            changed.add("birthDate");
        }
        if (!java.util.Objects.equals(current.getGender(), draft.gender())) {
            changed.add("gender");
        }
        if (!java.util.Objects.equals(current.getMobile(), draft.mobile())) {
            changed.add("mobile");
        }
        if (!java.util.Objects.equals(current.getCity(), blankToNull(draft.city()))) {
            changed.add("city");
        }
        if (!java.util.Objects.equals(current.getAddressDetail(), blankToNull(draft.addressDetail()))) {
            changed.add("addressDetail");
        }
        return changed;
    }

    private PersonDraft withVerifiedPhone(PersonDraft draft) {
        String phone = verifiedLoginPhone();
        if (phone == null) {
            return draft;
        }
        if (draft.mobile() != null && !draft.mobile().isBlank() && !phone.equals(draft.mobile().trim())) {
            throw new ServiceException("手机号以注册时验证的号码为准");
        }
        return new PersonDraft(draft.legalName(), draft.birthDate(), draft.gender(), phone, draft.idDocType(), draft.idNumber(),
            draft.city(), draft.addressDetail(), draft.bloodType(), draft.clothingSize(),
            draft.emergencyContactName(), draft.emergencyContactPhone());
    }

    private String verifiedLoginPhone() {
        String phone = LoginHelper.getUsername();
        if (phone == null || !phone.matches("^1[3-9]\\d{9}$")) {
            return null;
        }
        return phone.trim();
    }

    private String requiredMobile(String mobile) {
        String normalized = blankToNull(mobile);
        if (normalized == null || !normalized.matches("^1[3-9]\\d{9}$")) {
            throw new ServiceException("请填写中国大陆11位手机号");
        }
        return normalized;
    }

    private String optionalMobile(String mobile) {
        String normalized = blankToNull(mobile);
        if (normalized != null && !normalized.matches("^1[3-9]\\d{9}$")) {
            throw new ServiceException("紧急联系号码需为中国大陆11位手机号");
        }
        return normalized;
    }

    private String optionalEnum(String value, Set<String> allowed, String message) {
        String normalized = blankToNull(value);
        if (normalized != null && !allowed.contains(normalized)) {
            throw new ServiceException(message);
        }
        return normalized;
    }

    private String limit(String value, int max, String label) {
        if (value != null && value.length() > max) {
            throw new ServiceException(label + "不超过" + max + "字");
        }
        return value;
    }

    private String blankToNull(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim();
    }

    private byte[] aesKey() {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(phonePepper.getBytes(StandardCharsets.UTF_8));
            return Arrays.copyOf(digest, 16);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 不可用", exception);
        }
    }

    private String decryptId(String cipher) {
        if (cipher == null || cipher.isBlank()) {
            return null;
        }
        return SecureUtil.aes(aesKey()).decryptStr(cipher);
    }

    private OffsetDateTime now() {
        return OffsetDateTime.now(SHANGHAI);
    }

    public record PersonDraft(String legalName, LocalDate birthDate, String gender, String mobile, String idDocType,
                              String idNumber, String city, String addressDetail, String bloodType, String clothingSize,
                              String emergencyContactName, String emergencyContactPhone) {
        public static PersonDraft basic(String legalName, LocalDate birthDate, String gender, String mobile) {
            return new PersonDraft(legalName, birthDate, gender, mobile, null, null, null, null, null, null, null, null);
        }
    }

    public record PersonCard(Long personId, String legalName, String displayName, LocalDate birthDate, String gender,
                             String mobile, String idDocType, String idNumber, String city, String addressDetail,
                             String bloodType, String clothingSize, String emergencyContactName, String emergencyContactPhone,
                             boolean boundToMe) {
    }

    public record WardCard(Long personId, String displayName, Long independentAccountId, boolean parentCanRegister, boolean childCanRegister) {
    }

    public record IdentityHome(Long accountId, String displayName, PersonCard self, List<PersonCard> createdPersons, List<WardCard> wards,
                               String loginPhone) {
    }

    public record ChildArchive(Long personId, Long independentAccountId, boolean parentCanRegister, boolean childCanRegister) {
    }

    public record AccessDecision(Long personId, boolean allowed, String reason) {
    }
}
