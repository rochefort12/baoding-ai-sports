package org.dromara.web.service.impl;

import cn.dev33.satoken.stp.StpUtil;
import cn.dev33.satoken.stp.parameter.SaLoginParameter;
import cn.hutool.crypto.digest.BCrypt;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.constant.Constants;
import org.dromara.common.core.constant.GlobalConstants;
import org.dromara.common.core.domain.model.LoginUser;
import org.dromara.common.core.domain.model.PasswordLoginBody;
import org.dromara.common.core.enums.LoginType;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.core.exception.user.CaptchaException;
import org.dromara.common.core.exception.user.CaptchaExpireException;
import org.dromara.common.core.utils.StringUtils;
import org.dromara.common.core.utils.ValidatorUtils;
import org.dromara.common.json.utils.JsonUtils;
import org.dromara.common.redis.utils.RedisUtils;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.common.web.config.properties.CaptchaProperties;
import org.dromara.sports.identity.PlatformSession;
import org.dromara.sports.identity.domain.SportsAccount;
import org.dromara.sports.identity.service.IdentityService;
import org.dromara.system.domain.vo.SysClientVo;
import org.dromara.web.domain.vo.LoginVo;
import org.dromara.web.service.IAuthStrategy;
import org.dromara.web.service.SysLoginService;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Set;

/**
 * 平台账号登录。只核对手机号渠道和平台账号上的密码，不查询后台用户。
 */
@Service("platform" + IAuthStrategy.BASE_NAME)
@RequiredArgsConstructor
public class PlatformAuthStrategy implements IAuthStrategy {

    private final CaptchaProperties captchaProperties;
    private final SysLoginService loginService;
    private final IdentityService identityService;

    @Override
    public LoginVo login(String body, SysClientVo client) {
        PasswordLoginBody loginBody = JsonUtils.parseObject(body, PasswordLoginBody.class);
        ValidatorUtils.validate(loginBody);
        String phone = loginBody.getUsername();
        if (captchaProperties.getEnable()) {
            validateCaptcha(phone, loginBody.getCode(), loginBody.getUuid());
        }
        String normalized = phone == null ? "" : phone.trim();
        SportsAccount account = identityService.findActivePhoneAccount(normalized);
        if (account == null) {
            throw new ServiceException("手机号或密码错误");
        }
        String rawPassword = loginBody.getPassword();
        TenantHelper.dynamic(PlatformSession.TENANT_ID, () -> loginService.checkLogin(
            LoginType.PASSWORD, PlatformSession.TENANT_ID, normalized,
            () -> {
                String hash = account.getPasswordHash();
                return hash == null || hash.isBlank() || rawPassword == null || !BCrypt.checkpw(rawPassword, hash);
            }));
        LoginUser loginUser = new LoginUser();
        loginUser.setTenantId(PlatformSession.TENANT_ID);
        loginUser.setUserId(account.getId());
        loginUser.setUsername(normalized);
        loginUser.setNickname(account.getDisplayName());
        loginUser.setUserType(UserType.PLATFORM_USER.getUserType());
        loginUser.setMenuPermission(Set.of());
        loginUser.setRolePermission(Set.of(PlatformSession.LANDING_ROLE));
        loginUser.setRoles(List.of());
        loginUser.setPosts(List.of());
        loginUser.setClientKey(client.getClientKey());
        loginUser.setDeviceType(client.getDeviceType());
        SaLoginParameter model = new SaLoginParameter();
        model.setDeviceType(client.getDeviceType());
        model.setTimeout(client.getTimeout());
        model.setActiveTimeout(client.getActiveTimeout());
        model.setExtra(LoginHelper.CLIENT_KEY, client.getClientId());
        LoginHelper.login(loginUser, model);

        LoginVo loginVo = new LoginVo();
        loginVo.setAccessToken(StpUtil.getTokenValue());
        loginVo.setExpireIn(StpUtil.getTokenTimeout());
        loginVo.setClientId(client.getClientId());
        return loginVo;
    }

    private void validateCaptcha(String username, String code, String uuid) {
        String verifyKey = GlobalConstants.CAPTCHA_CODE_KEY + StringUtils.blankToDefault(uuid, "");
        String captcha = RedisUtils.getCacheObject(verifyKey);
        RedisUtils.deleteObject(verifyKey);
        if (captcha == null) {
            loginService.recordLogininfor(PlatformSession.TENANT_ID, username, Constants.LOGIN_FAIL, "验证码已失效");
            throw new CaptchaExpireException();
        }
        if (!StringUtils.equalsIgnoreCase(code, captcha)) {
            loginService.recordLogininfor(PlatformSession.TENANT_ID, username, Constants.LOGIN_FAIL, "验证码错误");
            throw new CaptchaException();
        }
    }
}
