package org.dromara.web.service;

import cn.dev33.satoken.stp.StpUtil;
import cn.hutool.crypto.digest.BCrypt;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.constant.Constants;
import org.dromara.common.core.constant.GlobalConstants;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.core.exception.user.CaptchaException;
import org.dromara.common.core.exception.user.CaptchaExpireException;
import org.dromara.common.core.utils.ServletUtils;
import org.dromara.common.core.utils.SpringUtils;
import org.dromara.common.core.utils.StringUtils;
import org.dromara.common.log.event.LogininforEvent;
import org.dromara.common.core.lock.MutualLock;
import org.dromara.common.mybatis.helper.DataPermissionHelper;
import org.dromara.common.redis.utils.RedisUtils;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.common.web.config.properties.CaptchaProperties;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.api.OrganizationSessionApi.OrganizationEntry;
import org.dromara.web.config.AliyunCaptchaProperties;
import org.dromara.sports.identity.ParticipantEntry;
import org.dromara.sports.identity.service.IdentityService;
import org.dromara.system.domain.SysUser;
import org.dromara.system.domain.SysUserRole;
import org.dromara.system.domain.vo.SysUserVo;
import org.dromara.system.mapper.SysUserMapper;
import org.dromara.system.mapper.SysUserRoleMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Duration;
import java.util.List;
import java.util.regex.Pattern;

/**
 * 参赛者注册。手机号验证通过后创建登录用户、平台账号和 phone 渠道，不创建参赛人档案。
 * 注册短信经真实服务受理后缓存；仅显式隔离回显模式模拟发送。人机验证与短信是独立能力。
 */
@Service
@RequiredArgsConstructor
public class ParticipantRegisterService {

    private static final Pattern PHONE = Pattern.compile("^1[3-9]\\d{9}$");
    private static final Pattern PASSWORD = Pattern.compile("^[^<>\"'|\\\\]{5,20}$");
    private static final String SMS_KEY_REGISTER = "participant_sms:register:";
    private static final String SMS_KEY_RESET = "participant_sms:reset:";
    private static final String SMS_FAIL_RESET = "participant_sms_fail:reset:";
    private static final String SMS_KEY_CLOSE = "participant_sms:close:";
    private static final String SMS_FAIL_CLOSE = "participant_sms_fail:close:";
    private static final String SMS_LOCK_REGISTER = "participant_sms_lock:register:";
    private static final String SMS_LOCK_RESET = "participant_sms_lock:reset:";
    private static final String SMS_LOCK_CLOSE = "participant_sms_lock:close:";
    private static final String RESET_REJECTED = "验证码错误或已失效";
    private static final int RESET_ATTEMPT_LIMIT = 5;

    private final SysUserMapper userMapper;
    private final SysUserRoleMapper userRoleMapper;
    private final IdentityService identityService;
    private final OrganizationSessionApi sessionApi;
    private final MutualLock mutualLock;
    private final CaptchaProperties captchaProperties;
    private final AliyunCaptchaProperties aliyunCaptchaProperties;
    private final AliyunCaptchaVerifier aliyunCaptchaVerifier;
    private final TencentRegistrationSmsSender registrationSmsSender;
    private final SecureRandom random = new SecureRandom();

    @Value("${participant.sms-echo-code:false}")
    private boolean smsEchoCode;

    /**
     * 发码前先过验证码。阿里云场景已配置时接收无痕验证参数；否则仍用本地算术验证码。
     * 返回值仅在本地回显开关打开时带短信验证码。
     */
    public String sendSmsCode(String phone, String captchaCode, String uuid, String captchaVerifyParam) {
        String normalized = requirePhone(phone);
        verifySendCaptcha(normalized, captchaCode, uuid, captchaVerifyParam);
        if (phoneTaken(normalized)) {
            throw new ServiceException("手机号已注册");
        }
        return storeSmsCode(SMS_LOCK_REGISTER, SMS_KEY_REGISTER, normalized);
    }

    /**
     * 重置发码。未知号码也返回空验证码，由接口给出同一句提示，避免暴露是否注册。
     * 本地回显只在确实写入重置验证码时带回，不能当成已经发出真实短信。
     */
    public String sendResetCode(String phone, String captchaCode, String uuid, String captchaVerifyParam) {
        String normalized = requirePhone(phone);
        verifySendCaptcha(normalized, captchaCode, uuid, captchaVerifyParam);
        requireOtherPurposeTemplate();
        if (identityService.findVerifiedAccountId(normalized).isEmpty()) {
            holdSendSlot(SMS_LOCK_RESET, normalized);
            record(normalized, "重置验证码未发送");
            return null;
        }
        String smsCode = storeSmsCode(SMS_LOCK_RESET, SMS_KEY_RESET, normalized);
        record(normalized, "重置验证码已写入本地");
        return smsCode;
    }

    /**
     * 用重置验证码更换平台密码。先作废验证码，再写 asp_account.password_hash，最后注销会话。
     * 数据库更新失败时验证码已经作废，必须重新获取，不能靠同一验证码重试。
     */
    public void resetPassword(String phone, String smsCode, String password) {
        String normalized = requirePhone(phone);
        requirePassword(password);
        Long accountId = mutualLock.execute("password-reset:" + identityService.phoneHash(normalized), 3000, 15000, () -> {
            consumeResetCode(normalized, smsCode);
            Long found = identityService.findVerifiedAccountId(normalized).orElse(null);
            if (found == null) {
                record(normalized, "重置未完成");
                throw new ServiceException(RESET_REJECTED);
            }
            identityService.replaceLoginPassword(found, password);
            return found;
        });
        boolean sessionsClosed = logoutResetSessions(accountId);
        record(String.valueOf(accountId), sessionsClosed ? "平台密码已重置" : "平台密码已重置，会话注销未完成");
    }

    /**
     * 给当前登录账号已验证的手机号发注销验证码。验证码和注册、重置互不通用。
     */
    public String sendCloseCode(String captchaCode, String uuid, String captchaVerifyParam) {
        String phone = currentPhone();
        verifySendCaptcha(phone, captchaCode, uuid, captchaVerifyParam);
        requireOtherPurposeTemplate();
        Long accountId = LoginHelper.getUserId();
        identityService.assertVerifiedPhone(accountId, phone);
        String smsCode = storeSmsCode(SMS_LOCK_CLOSE, SMS_KEY_CLOSE, phone);
        record(String.valueOf(accountId), "注销验证码已写入本地");
        return smsCode;
    }

    /**
     * 先列出阻塞事项。通过后关闭账号、结束手机号绑定、停用参赛者后台用户，再注销会话。
     */
    public void closeAccount(String smsCode) {
        String phone = currentPhone();
        Long accountId = LoginHelper.getUserId();
        identityService.assertVerifiedPhone(accountId, phone);
        List<String> blocks = identityService.closureBlocks(accountId);
        if (!blocks.isEmpty()) {
            throw new ServiceException(String.join("；", blocks));
        }
        consumeCloseCode(phone, smsCode);
        Long backendUserId = identityService.closeAccount(accountId);
        boolean sessionsClosed = false;
        try {
            if (backendUserId != null) {
                TenantHelper.dynamic(ParticipantEntry.TENANT_ID, () -> {
                    releaseLoginName(backendUserId);
                    return null;
                });
            }
        } finally {
            sessionsClosed = logoutResetSessions(accountId);
        }
        record(String.valueOf(accountId), sessionsClosed ? "账号已注销" : "账号已注销，会话注销未完成");
    }

    @Transactional
    public void register(String phone, String password, String smsCode) {
        String normalized = requirePhone(phone);
        requirePassword(password);
        consumeSmsCode(normalized, smsCode);
        createVerifiedLogin(normalized, password);
    }

    /**
     * 供已通过短信验证码的注册和回滚测试使用。
     */
    @Transactional
    public Long createVerifiedLogin(String phone, String password) {
        String normalized = requirePhone(phone);
        requirePassword(password);
        if (phoneTaken(normalized)) {
            throw new ServiceException("手机号已注册");
        }
        String tenantId = ParticipantEntry.TENANT_ID;
        SysUser user = new SysUser();
        user.setTenantId(tenantId);
        user.setDeptId(ParticipantEntry.DEPT_ID);
        user.setUserName(normalized);
        user.setNickName(maskPhone(normalized));
        user.setPhonenumber(normalized);
        user.setUserType(UserType.APP_USER.getUserType());
        user.setPassword(BCrypt.hashpw(password));
        user.setStatus("0");
        TenantHelper.dynamic(tenantId, () -> userMapper.insert(user));
        SysUserRole userRole = new SysUserRole();
        userRole.setUserId(user.getUserId());
        userRole.setRoleId(ParticipantEntry.ROLE_ID);
        userRoleMapper.insert(userRole);
        var account = identityService.openAccount(maskPhone(normalized), user.getUserId());
        identityService.setLoginPassword(account.getId(), password);
        identityService.bindVerifiedPhone(account.getId(), normalized);
        return user.getUserId();
    }

    private void verifySendCaptcha(String phone, String captchaCode, String uuid, String captchaVerifyParam) {
        if (aliyunCaptchaProperties.serverReady()) {
            if (captchaVerifyParam == null || captchaVerifyParam.isBlank()) {
                throw new ServiceException("请先完成验证码");
            }
            if (!aliyunCaptchaVerifier.passed(captchaVerifyParam)) {
                throw new ServiceException("验证未通过，请重试");
            }
            return;
        }
        if (aliyunCaptchaProperties.ready()) {
            if (captchaVerifyParam == null || captchaVerifyParam.isBlank()) {
                throw new ServiceException("请先完成验证码");
            }
            return;
        }
        if (captchaProperties.getEnable()) {
            validateCaptcha(phone, captchaCode, uuid);
        }
    }

    private void holdSendSlot(String lockKey, String phone) {
        boolean acquired = RedisUtils.setObjectIfAbsent(lockKey + phone, "1", Duration.ofSeconds(60));
        if (!acquired) {
            throw new ServiceException("请60秒后再获取验证码");
        }
        String phoneHash = identityService.phoneHash(phone);
        if (!RedisUtils.setObjectIfAbsent("participant_sms_lock:all:" + phoneHash, "1", Duration.ofSeconds(60)))
            throw new ServiceException("请60秒后再获取验证码");
        if (RedisUtils.rateLimiter("participant_sms_daily:" + phoneHash, org.redisson.api.RateType.OVERALL, 10, 86400, 90000) < 0)
            throw new ServiceException("今天获取验证码次数已达上限，请明天再试");
    }

    private String storeSmsCode(String lockKey, String codeKey, String phone) {
        holdSendSlot(lockKey, phone);
        RedisUtils.deleteObject(codeKey + phone);
        String smsCode = String.format("%06d", random.nextInt(1_000_000));
        boolean echo = smsEchoCode && !registrationSmsSender.enabled();
        if (!echo) {
            if (!SMS_KEY_REGISTER.equals(codeKey)) throw new ServiceException("该用途的短信模板尚未配置，验证码未发送");
            registrationSmsSender.send(phone, smsCode);
        }
        RedisUtils.setCacheObject(codeKey + phone, smsCode, Duration.ofMinutes(5));
        return echo ? smsCode : null;
    }

    /** 当前只配置注册模板。未知/已知号码统一拒绝其他用途，不能借响应差异泄露注册状态。 */
    private void requireOtherPurposeTemplate() {
        if (!smsEchoCode || registrationSmsSender.enabled()) {
            throw new ServiceException("该用途的短信模板尚未配置，验证码未发送");
        }
    }

    private void consumeResetCode(String phone, String smsCode) {
        String key = SMS_KEY_RESET + phone;
        String cached = RedisUtils.getCacheObject(key);
        String submitted = smsCode == null ? "" : smsCode.trim();
        if (cached == null || !cached.equals(submitted)) {
            Integer fails = RedisUtils.getCacheObject(SMS_FAIL_RESET + phone);
            int next = fails == null ? 1 : fails + 1;
            RedisUtils.setCacheObject(SMS_FAIL_RESET + phone, next, Duration.ofMinutes(5));
            if (next >= RESET_ATTEMPT_LIMIT) {
                RedisUtils.deleteObject(key);
            }
            record(phone, "重置验证码未通过");
            throw new ServiceException(RESET_REJECTED);
        }
        RedisUtils.deleteObject(key);
        RedisUtils.deleteObject(SMS_FAIL_RESET + phone);
    }

    private void consumeCloseCode(String phone, String smsCode) {
        String key = SMS_KEY_CLOSE + phone;
        String cached = RedisUtils.getCacheObject(key);
        String submitted = smsCode == null ? "" : smsCode.trim();
        if (cached == null || !cached.equals(submitted)) {
            Integer fails = RedisUtils.getCacheObject(SMS_FAIL_CLOSE + phone);
            int next = fails == null ? 1 : fails + 1;
            RedisUtils.setCacheObject(SMS_FAIL_CLOSE + phone, next, Duration.ofMinutes(5));
            if (next >= RESET_ATTEMPT_LIMIT) {
                RedisUtils.deleteObject(key);
            }
            record(String.valueOf(LoginHelper.getUserId()), "注销验证码未通过");
            throw new ServiceException(RESET_REJECTED);
        }
        RedisUtils.deleteObject(key);
        RedisUtils.deleteObject(SMS_FAIL_CLOSE + phone);
    }

    private String currentPhone() {
        String phone = LoginHelper.getUsername();
        return requirePhone(phone);
    }

    /**
     * 按完整登录号注销。认证数据走全局键，不依赖当前请求租户。
     * 没有组织入口时只注销平台会话。
     */
    private boolean logoutResetSessions(Long accountId) {
        boolean closed = true;
        try {
            StpUtil.logout(UserType.PLATFORM_USER.getUserType() + ":" + accountId);
        } catch (Exception exception) {
            closed = false;
        }
        try {
            OrganizationEntry entry = sessionApi.entryFor(accountId).orElse(null);
            if (entry != null) {
                SysUserVo user = TenantHelper.dynamic(entry.tenantId(), () -> userMapper.selectVoById(entry.sysUserId()));
                if (user != null && user.getUserType() != null && user.getUserId() != null) {
                    StpUtil.logout(user.getUserType() + ":" + user.getUserId());
                }
            }
        } catch (Exception exception) {
            closed = false;
        }
        return closed;
    }

    private void consumeSmsCode(String phone, String smsCode) {
        String key = SMS_KEY_REGISTER + phone;
        String cached = RedisUtils.getCacheObject(key);
        RedisUtils.deleteObject(key);
        if (cached == null) {
            record(phone, "短信验证码已失效");
            throw new CaptchaExpireException();
        }
        if (smsCode == null || !cached.equals(smsCode.trim())) {
            record(phone, "短信验证码错误");
            throw new CaptchaException();
        }
    }

    /**
     * 仍有效的手机号绑定，或仍启用的后台登录名，才算占用。
     * 已注销账号的后台登录名会让出来，同一号码才能注册新的独立账号。
     */
    private boolean phoneTaken(String phone) {
        if (identityService.findVerifiedAccountId(phone).isPresent()) {
            return true;
        }
        boolean enabled = Boolean.TRUE.equals(TenantHelper.dynamic(ParticipantEntry.TENANT_ID, () -> userMapper.exists(new LambdaQueryWrapper<SysUser>()
            .eq(SysUser::getUserName, phone)
            .eq(SysUser::getStatus, "0"))));
        if (enabled) {
            return true;
        }
        TenantHelper.dynamic(ParticipantEntry.TENANT_ID, () -> {
            userMapper.selectList(new LambdaQueryWrapper<SysUser>().eq(SysUser::getUserName, phone)).forEach(user -> releaseLoginName(user.getUserId()));
            return null;
        });
        return false;
    }

    /**
     * 停用后台用户并让出登录名。这个更新方法带部门数据权限。
     * 未登录获取注册验证码、或注销后的失效会话，都会在取当前用户时被当成登录过期。
     * 让出登录名只按指定用户执行，不按部门范围过滤。
     */
    private void releaseLoginName(Long userId) {
        if (userId == null) {
            return;
        }
        int updated = DataPermissionHelper.ignore(() -> userMapper.update(null, Wrappers.<SysUser>lambdaUpdate()
            .eq(SysUser::getUserId, userId)
            .set(SysUser::getStatus, "1")
            .set(SysUser::getUserName, "c" + userId)
            .set(SysUser::getPhonenumber, null)));
        if (updated != 1) {
            throw new ServiceException("登录名暂时不能让出，请稍后再试");
        }
    }

    private String requirePhone(String phone) {
        String normalized = phone == null ? "" : phone.trim();
        if (!PHONE.matcher(normalized).matches()) {
            throw new ServiceException("请填写中国大陆11位手机号");
        }
        return normalized;
    }

    private void requirePassword(String password) {
        if (password == null || !PASSWORD.matcher(password).matches()) {
            throw new ServiceException("密码需为5到20位，且不能包含 < > \" ' \\ |");
        }
    }

    private String maskPhone(String phone) {
        return phone.substring(0, 3) + "****" + phone.substring(7);
    }

    private void validateCaptcha(String username, String code, String uuid) {
        String verifyKey = GlobalConstants.CAPTCHA_CODE_KEY + StringUtils.blankToDefault(uuid, "");
        String captcha = RedisUtils.getCacheObject(verifyKey);
        RedisUtils.deleteObject(verifyKey);
        if (captcha == null) {
            record(username, "验证码已失效");
            throw new CaptchaExpireException();
        }
        if (!StringUtils.equalsIgnoreCase(code, captcha)) {
            record(username, "验证码错误");
            throw new CaptchaException();
        }
    }

    private void record(String username, String message) {
        LogininforEvent event = new LogininforEvent();
        event.setTenantId(ParticipantEntry.TENANT_ID);
        event.setUsername(username != null && PHONE.matcher(username).matches() ? maskPhone(username) : username);
        event.setStatus(Constants.LOGIN_FAIL);
        event.setMessage(message);
        event.setRequest(ServletUtils.getRequest());
        SpringUtils.context().publishEvent(event);
    }
}
