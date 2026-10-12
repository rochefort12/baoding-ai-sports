package org.dromara.web.service.impl;

import cn.dev33.satoken.stp.StpUtil;
import cn.dev33.satoken.stp.parameter.SaLoginParameter;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.constant.Constants;
import org.dromara.common.core.constant.GlobalConstants;
import org.dromara.common.core.constant.TenantConstants;
import org.dromara.common.core.domain.model.LoginUser;
import org.dromara.common.core.domain.model.PasswordLoginBody;
import org.dromara.common.core.exception.user.CaptchaException;
import org.dromara.common.core.exception.user.CaptchaExpireException;
import org.dromara.common.core.utils.MessageUtils;
import org.dromara.common.core.utils.StringUtils;
import org.dromara.common.core.utils.ValidatorUtils;
import org.dromara.common.json.utils.JsonUtils;
import org.dromara.common.ratelimiter.annotation.RateLimiter;
import org.dromara.common.ratelimiter.enums.LimitType;
import org.dromara.common.redis.utils.RedisUtils;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.web.config.properties.CaptchaProperties;
import org.dromara.system.domain.vo.SysClientVo;
import org.dromara.web.domain.vo.LoginVo;
import org.dromara.web.service.IAuthStrategy;
import org.dromara.web.service.SysLoginService;
import org.dromara.web.service.WorkAccountResolver;
import org.dromara.web.service.WorkLoginGrantPolicy;
import org.springframework.stereotype.Service;

/** 工作账号自动定位组织；登录之前保留图形验证码及 IP 限频。 */
@Service(WorkLoginGrantPolicy.WORK_PASSWORD + IAuthStrategy.BASE_NAME)
@RequiredArgsConstructor
public class WorkPasswordAuthStrategy implements IAuthStrategy {
    private final CaptchaProperties captchaProperties;
    private final SysLoginService loginService;
    private final WorkAccountResolver accountResolver;

    @Override
    @RateLimiter(time = 60, count = 60, limitType = LimitType.IP)
    public LoginVo login(String body, SysClientVo client) {
        PasswordLoginBody loginBody = JsonUtils.parseObject(body, PasswordLoginBody.class);
        ValidatorUtils.validate(loginBody);
        if (captchaProperties.getEnable()) {
            validateCaptcha(loginBody);
        }
        LoginUser user = accountResolver.authenticate(loginBody);
        user.setClientKey(client.getClientKey());
        user.setDeviceType(client.getDeviceType());
        SaLoginParameter parameter = new SaLoginParameter();
        parameter.setDeviceType(client.getDeviceType());
        parameter.setTimeout(client.getTimeout());
        parameter.setActiveTimeout(client.getActiveTimeout());
        parameter.setExtra(LoginHelper.CLIENT_KEY, client.getClientId());
        LoginHelper.login(user, parameter);
        LoginVo result = new LoginVo();
        result.setAccessToken(StpUtil.getTokenValue());
        result.setExpireIn(StpUtil.getTokenTimeout());
        result.setClientId(client.getClientId());
        return result;
    }

    void validateCaptcha(PasswordLoginBody body) {
        String key = GlobalConstants.CAPTCHA_CODE_KEY + StringUtils.blankToDefault(body.getUuid(), "");
        String captcha = RedisUtils.getCacheObject(key);
        RedisUtils.deleteObject(key);
        if (captcha == null) {
            loginService.recordLogininfor(TenantConstants.DEFAULT_TENANT_ID, body.getUsername(),
                Constants.LOGIN_FAIL, MessageUtils.message("user.jcaptcha.expire"));
            throw new CaptchaExpireException();
        }
        if (!StringUtils.equalsIgnoreCase(body.getCode(), captcha)) {
            loginService.recordLogininfor(TenantConstants.DEFAULT_TENANT_ID, body.getUsername(),
                Constants.LOGIN_FAIL, MessageUtils.message("user.jcaptcha.error"));
            throw new CaptchaException();
        }
    }
}
