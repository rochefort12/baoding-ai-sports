package org.dromara.web.service;

import com.aliyun.captcha20230305.Client;
import com.aliyun.captcha20230305.models.VerifyIntelligentCaptchaRequest;
import com.aliyun.captcha20230305.models.VerifyIntelligentCaptchaResponse;
import com.aliyun.captcha20230305.models.VerifyIntelligentCaptchaResponseBody;
import com.aliyun.tea.TeaException;
import com.aliyun.teaopenapi.models.Config;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.web.config.AliyunCaptchaProperties;
import org.springframework.stereotype.Service;

/**
 * 按验证码 2.0 服务端接入调用 VerifyIntelligentCaptcha。
 * CaptchaVerifyParam 原样上送。网络故障按官方建议放行；权限或验签失败则拒绝。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AliyunCaptchaVerifier {

    private static final String ENDPOINT = "captcha.cn-shanghai.aliyuncs.com";

    private final AliyunCaptchaProperties properties;

    private volatile Client client;

    public boolean passed(String captchaVerifyParam) {
        try {
            VerifyIntelligentCaptchaRequest request = new VerifyIntelligentCaptchaRequest()
                .setCaptchaVerifyParam(captchaVerifyParam)
                .setSceneId(properties.getSceneId());
            VerifyIntelligentCaptchaResponse response = client().verifyIntelligentCaptcha(request);
            VerifyIntelligentCaptchaResponseBody.VerifyIntelligentCaptchaResponseBodyResult result =
                response.getBody() == null ? null : response.getBody().getResult();
            if (result == null || !Boolean.TRUE.equals(result.getVerifyResult())) {
                log.info("Aliyun captcha rejected, verifyCode={}", result == null ? "missing" : result.getVerifyCode());
                return false;
            }
            log.info("Aliyun captcha accepted, verifyCode={}", result.getVerifyCode());
            return true;
        } catch (TeaException exception) {
            log.warn("Aliyun captcha verify refused, code={}", exception.getCode());
            throw new ServiceException("验证码校验失败，请重试");
        } catch (Exception exception) {
            log.warn("Aliyun captcha verify unavailable, request allowed");
            return true;
        }
    }

    private Client client() throws Exception {
        Client current = client;
        if (current != null) {
            return current;
        }
        synchronized (this) {
            if (client == null) {
                Config config = new Config()
                    .setAccessKeyId(properties.getAccessKeyId())
                    .setAccessKeySecret(properties.getAccessKeySecret())
                    .setEndpoint(ENDPOINT);
                client = new Client(config);
            }
            return client;
        }
    }
}
