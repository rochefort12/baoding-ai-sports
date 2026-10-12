package org.dromara.web.service;

import cn.hutool.json.JSONUtil;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sms4j.api.SmsBlend;
import org.dromara.sms4j.api.entity.SmsResponse;
import org.dromara.sms4j.tencent.config.TencentConfig;
import org.dromara.sms4j.tencent.service.TencentSmsImpl;
import org.dromara.web.config.TencentSmsProperties;
import org.springframework.stereotype.Service;
import java.util.LinkedHashMap;

/** 注册模板只发注册验证码。供应商受理不表示终端已收到，不返回原响应或记录号码/验证码。 */
@Service
@RequiredArgsConstructor
public class TencentRegistrationSmsSender {
    private final TencentSmsProperties properties;

    public boolean enabled() { return properties.getSms().isEnabled(); }

    public void send(String phone, String code) {
        if (!properties.configured()) throw new ServiceException("注册短信服务尚未配置，请稍后再试");
        if (phone == null || !phone.matches("^1[3-9]\\d{9}$") || code == null || !code.matches("^\\d{6}$"))
            throw new ServiceException("请检查手机号和验证码格式");
        // 已通过腾讯云模板查询核对：{1}=注册验证码，{2}=有效分钟数。LinkedHashMap保证顺序。
        LinkedHashMap<String, String> parameters = new LinkedHashMap<>();
        parameters.put("code", code); parameters.put("minutes", "5");
        try {
            SmsResponse response = client().sendMessage("+86" + phone, properties.getSms().getTemplateId(), parameters);
            if (response == null || !response.isSuccess()) throw new ServiceException("注册短信未发送成功，请稍后再试");
            // 不仅依赖适配器success：必须确有单收件人受理状态，空状态不能冒充发送成功。
            var root = JSONUtil.parseObj(response.getData()).getJSONObject("Response");
            var statuses = root == null ? null : root.getJSONArray("SendStatusSet");
            if (statuses == null || statuses.size() != 1 || !"Ok".equals(statuses.getJSONObject(0).getStr("Code")))
                throw new ServiceException("注册短信未发送成功，请稍后再试");
        } catch (ServiceException rejected) { throw rejected; }
        catch (Exception unavailable) { throw new ServiceException("注册短信暂时不可用，请稍后再试"); }
    }

    /** 使用工程已有sms4j腾讯适配，不引入第二套SDK。关闭自动重试，避免未知结果重复发码。 */
    SmsBlend client() {
        TencentConfig config = new TencentConfig();
        config.setConfigId("aisports-registration"); config.setAccessKeyId(properties.getSecretId());
        config.setAccessKeySecret(properties.getSecretKey()); config.setSdkAppId(properties.getSms().getSdkAppId());
        config.setSignature(properties.getSms().getSignName()); config.setTerritory(properties.getRegion());
        config.setConnTimeout(15); config.setMaxRetries(0);
        // 本服务只用同步发送；不依赖旧短信开关初始化的全局异步线程池/延迟调度器。
        return new TencentSmsImpl(config, Runnable::run, null);
    }
}
