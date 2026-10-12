package org.dromara.web.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * 阿里云验证码 2.0。ekey 和 AccessKey 只留在服务端，不返回给页面。
 * 客户端 region 为 cn 时，验签地址使用上海公网 captcha.cn-shanghai.aliyuncs.com。
 */
@Data
@Component
@ConfigurationProperties(prefix = "aliyun.captcha")
public class AliyunCaptchaProperties {

    private String region = "cn";

    private String prefix = "";

    private String ekey = "";

    private String sceneId = "";

    private String sceneName = "";

    private String mode = "traceless";

    private String client = "web";

    private String accessKeyId = "";

    private String accessKeySecret = "";

    /** 本地跑通流程时关闭。打开后发码前才调用 VerifyIntelligentCaptcha。 */
    private boolean serverVerify = false;

    public boolean ready() {
        return prefix != null && !prefix.isBlank() && sceneId != null && !sceneId.isBlank();
    }

    public boolean serverReady() {
        return serverVerify && ready() && accessKeyId != null && !accessKeyId.isBlank()
            && accessKeySecret != null && !accessKeySecret.isBlank();
    }
}
