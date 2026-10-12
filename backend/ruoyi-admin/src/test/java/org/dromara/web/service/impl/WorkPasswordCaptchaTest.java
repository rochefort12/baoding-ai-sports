package org.dromara.web.service.impl;

import cn.hutool.extra.spring.SpringUtil;
import org.dromara.common.core.constant.GlobalConstants;
import org.dromara.common.core.domain.model.PasswordLoginBody;
import org.dromara.common.core.exception.user.CaptchaException;
import org.dromara.common.core.exception.user.CaptchaExpireException;
import org.dromara.common.core.utils.MessageUtils;
import org.dromara.common.redis.utils.RedisUtils;
import org.dromara.common.web.config.properties.CaptchaProperties;
import org.dromara.web.service.SysLoginService;
import org.dromara.web.service.WorkAccountResolver;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.redisson.api.RedissonClient;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 自动定位组织不影响验证码一次消费、过期及不匹配拒绝。 */
@Tag("local")
class WorkPasswordCaptchaTest {
    private final SysLoginService login = mock(SysLoginService.class);
    private final WorkAccountResolver resolver = mock(WorkAccountResolver.class);
    private final WorkPasswordAuthStrategy strategy = new WorkPasswordAuthStrategy(new CaptchaProperties(), login, resolver);

    private PasswordLoginBody body() {
        PasswordLoginBody value = new PasswordLoginBody();
        value.setUsername("work-person"); value.setUuid("fixture-id"); value.setCode("AB12");
        value.setTenantId("untrusted-tenant");
        return value;
    }

    private void withCaptcha(String expected, Runnable test) {
        try (var spring = mockStatic(SpringUtil.class)) {
            spring.when(() -> SpringUtil.getBean(RedissonClient.class)).thenReturn(mock(RedissonClient.class));
            try (var redis = mockStatic(RedisUtils.class); var messages = mockStatic(MessageUtils.class)) {
                redis.when(() -> RedisUtils.getCacheObject(GlobalConstants.CAPTCHA_CODE_KEY + "fixture-id")).thenReturn(expected);
                test.run();
                redis.verify(() -> RedisUtils.deleteObject(GlobalConstants.CAPTCHA_CODE_KEY + "fixture-id"));
            }
        }
    }

    @Test void validCodeConsumesCaptchaWithoutUsingSubmittedTenant() {
        withCaptcha("ab12", () -> assertDoesNotThrow(() -> strategy.validateCaptcha(body())));
        verifyNoInteractions(login, resolver);
    }

    @Test void expiredCaptchaIsRejectedBeforeAccountAuthentication() {
        withCaptcha(null, () -> assertThrows(CaptchaExpireException.class, () -> strategy.validateCaptcha(body())));
        verifyNoInteractions(resolver);
    }

    @Test void incorrectCaptchaIsRejectedAndConsumed() {
        withCaptcha("OTHER", () -> assertThrows(CaptchaException.class, () -> strategy.validateCaptcha(body())));
        verifyNoInteractions(resolver);
    }
}
