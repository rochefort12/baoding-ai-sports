package org.dromara.web.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/** 独立短信凭据仅在服务端绑定，不生成包含密钥的toString，不复用人机验证配置。 */
@Getter
@Setter
@Component
@ConfigurationProperties(prefix = "tencent")
public class TencentSmsProperties {
    private String secretId = "";
    private String secretKey = "";
    private String region = "ap-guangzhou";
    private Sms sms = new Sms();

    @Getter
    @Setter
    public static class Sms {
        private boolean enabled;
        private String sdkAppId = "";
        private String signName = "";
        private String templateId = "";
    }

    public boolean configured() {
        return sms.isEnabled() && present(secretId) && present(secretKey) && present(region)
            && present(sms.getSdkAppId()) && present(sms.getSignName()) && present(sms.getTemplateId());
    }
    private static boolean present(String value) { return value != null && !value.isBlank(); }
}
