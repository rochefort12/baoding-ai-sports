package org.dromara.web.service;

import org.dromara.web.config.TencentSmsProperties;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import java.security.SecureRandom;
import static org.junit.jupiter.api.Assertions.*;

/** 显式外部烟测：收费短信仅发给已获用户授权的环境号码。默认不运行，不创建账号、不绕过人机验证。 */
@Tag("external")
@EnabledIfEnvironmentVariable(named="TENCENT_SMS_SEND_LIVE_TEST",matches="true")
class TencentRegistrationSmsLiveTest {
    @Test void providerAcceptsOneRealRegistrationSms() {
        var properties = new TencentSmsProperties();
        properties.setSecretId(System.getenv("TENCENT_SMS_SECRET_ID"));
        properties.setSecretKey(System.getenv("TENCENT_SMS_SECRET_KEY"));
        properties.setRegion(System.getenv("TENCENT_SMS_REGION"));
        properties.getSms().setEnabled(Boolean.parseBoolean(System.getenv("TENCENT_SMS_ENABLED")));
        properties.getSms().setSdkAppId(System.getenv("TENCENT_SMS_APP_ID"));
        properties.getSms().setSignName(System.getenv("TENCENT_SMS_SIGN"));
        properties.getSms().setTemplateId(System.getenv("TENCENT_SMS_TEMPLATE_ID"));
        assertTrue(properties.configured(),"真实短信测试缺少环境配置");
        String phone = System.getenv("TENCENT_SMS_TEST_PHONE");
        assertTrue(phone != null && phone.matches("^1[3-9]\\d{9}$"),"测试号码未提供");
        String code = String.format("%06d",new SecureRandom().nextInt(1_000_000));
        new TencentRegistrationSmsSender(properties).send(phone,code);
        // 只验证供应商受理，终端是否收到需收件人确认；验证码不写日志、不回显、不写注册缓存。
    }
}
