package org.dromara.web.service;

import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.core.lock.MutualLock;
import cn.hutool.extra.spring.SpringUtil;
import org.dromara.common.redis.utils.RedisUtils;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.common.web.config.properties.CaptchaProperties;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.identity.service.IdentityService;
import org.dromara.system.mapper.SysUserMapper;
import org.dromara.system.mapper.SysUserRoleMapper;
import org.dromara.web.config.AliyunCaptchaProperties;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.mockito.MockedStatic;
import org.redisson.api.RateType;
import org.redisson.api.RedissonClient;
import org.springframework.test.util.ReflectionTestUtils;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Supplier;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** Redis/数据库/供应商隔离，验证失败不留有效验证码、限频和真实模式禁止回显。 */
@Tag("local")
class ParticipantRegistrationSmsTest {
    static final String PHONE = "13900000000";
    final IdentityService identity = mock(IdentityService.class);
    final TencentRegistrationSmsSender sender = mock(TencentRegistrationSmsSender.class);
    final ParticipantRegisterService service = create();
    ParticipantRegisterService create() {
        var captcha = new CaptchaProperties(); captcha.setEnable(false);
        when(identity.phoneHash(PHONE)).thenReturn("fixture-phone-hash");
        when(sender.enabled()).thenReturn(true);
        return new ParticipantRegisterService(mock(SysUserMapper.class),mock(SysUserRoleMapper.class),identity,
            mock(OrganizationSessionApi.class),mock(MutualLock.class),captcha,new AliyunCaptchaProperties(),
            mock(AliyunCaptchaVerifier.class),sender);
    }
    void withCache(java.util.function.Consumer<MockedStatic<RedisUtils>> check) {
        // RedisUtils静态客户端需要Spring bean；此处仅提供隔离客户端，所有缓存操作再静态mock。
        try (var spring = mockStatic(SpringUtil.class)) {
            spring.when(() -> SpringUtil.getBean(RedissonClient.class)).thenReturn(mock(RedissonClient.class));
            try (var redis = mockStatic(RedisUtils.class); var tenant = mockStatic(TenantHelper.class)) {
                tenant.when(() -> TenantHelper.dynamic(anyString(),any(Supplier.class)))
                    .thenAnswer(call -> ((Supplier<?>)call.getArgument(1)).get());
                redis.when(() -> RedisUtils.setObjectIfAbsent(anyString(),anyString(),any(Duration.class))).thenReturn(true);
                check.accept(redis);
            }
        }
    }
    @Test void cachesOnlyAfterAcceptedSendForFiveMinutesAndNeverEchoesRealCode() {
        ReflectionTestUtils.setField(service,"smsEchoCode",true);
        var order = new ArrayList<String>();
        doAnswer(call -> { assertTrue(((String)call.getArgument(1)).matches("\\d{6}")); order.add("send"); return null; })
            .when(sender).send(eq(PHONE),anyString());
        withCache(redis -> {
            redis.when(() -> RedisUtils.setCacheObject(eq("participant_sms:register:"+PHONE),anyString(),eq(Duration.ofMinutes(5))))
                .thenAnswer(call -> { order.add("cache"); return null; });
            assertNull(service.sendSmsCode(PHONE,null,null,null));
            assertEquals(List.of("send","cache"),order);
        });
    }
    @Test void providerFailureInvalidatesOldCodeAndDoesNotCacheNewOne() {
        doThrow(new ServiceException("发送失败")).when(sender).send(eq(PHONE),anyString());
        withCache(redis -> {
            assertThrows(ServiceException.class,() -> service.sendSmsCode(PHONE,null,null,null));
            redis.verify(() -> RedisUtils.deleteObject("participant_sms:register:"+PHONE));
            redis.verify(() -> RedisUtils.setCacheObject(anyString(),anyString(),any(Duration.class)),never());
        });
    }
    @Test void sharedPhoneCooldownPreventsSending() {
        withCache(redis -> {
            redis.when(() -> RedisUtils.setObjectIfAbsent(eq("participant_sms_lock:all:fixture-phone-hash"),anyString(),any(Duration.class)))
                .thenReturn(false);
            assertThrows(ServiceException.class,() -> service.sendSmsCode(PHONE,null,null,null));
            verify(sender,never()).send(anyString(),anyString());
        });
    }
    @Test void dailyLimitPreventsSending() {
        withCache(redis -> {
            redis.when(() -> RedisUtils.rateLimiter("participant_sms_daily:fixture-phone-hash",RateType.OVERALL,10,86400,90000))
                .thenReturn(-1L);
            assertThrows(ServiceException.class,() -> service.sendSmsCode(PHONE,null,null,null));
            verify(sender,never()).send(anyString(),anyString());
        });
    }
    @Test void registeredPhoneNeverContactsProvider() {
        when(identity.findVerifiedAccountId(PHONE)).thenReturn(java.util.Optional.of(1L));
        withCache(redis -> {
            assertThrows(ServiceException.class,() -> service.sendSmsCode(PHONE,null,null,null));
            verify(sender,never()).send(anyString(),anyString());
        });
    }
    @Test void registrationTemplateIsNeverUsedForReset() {
        when(identity.findVerifiedAccountId(PHONE)).thenReturn(java.util.Optional.of(1L));
        withCache(redis -> {
            assertThrows(ServiceException.class,() -> service.sendResetCode(PHONE,null,null,null));
            verify(sender,never()).send(anyString(),anyString());
            redis.verify(() -> RedisUtils.setCacheObject(anyString(),anyString(),any(Duration.class)),never());
        });
    }
    @Test void unavailableResetDoesNotPretendItSentToUnknownNumberOrQueryRegistrationState() {
        var error = assertThrows(ServiceException.class,() -> service.sendResetCode(PHONE,null,null,null));
        assertTrue(error.getMessage().contains("未发送"));
        verify(identity,never()).findVerifiedAccountId(anyString());
        verify(sender,never()).send(anyString(),anyString());
    }
}
