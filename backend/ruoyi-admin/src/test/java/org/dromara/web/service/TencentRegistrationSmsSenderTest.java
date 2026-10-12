package org.dromara.web.service;

import cn.hutool.json.JSONUtil;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sms4j.api.SmsBlend;
import org.dromara.sms4j.api.entity.SmsResponse;
import org.dromara.web.config.TencentSmsProperties;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.util.LinkedHashMap;
import java.util.List;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 供应商隔离契约测试，不发真实短信，也不打印验证码。 */
@Tag("local")
class TencentRegistrationSmsSenderTest {
    final TencentSmsProperties properties = configured();
    final SmsBlend provider = mock(SmsBlend.class);
    final TencentRegistrationSmsSender sender = spy(new TencentRegistrationSmsSender(properties));

    static TencentSmsProperties configured() {
        var properties = new TencentSmsProperties();
        properties.setSecretId("fixture-id"); properties.setSecretKey("fixture-secret");
        properties.getSms().setEnabled(true); properties.getSms().setSdkAppId("fixture-app");
        properties.getSms().setSignName("测试签名"); properties.getSms().setTemplateId("fixture-template");
        return properties;
    }
    SmsResponse response(boolean success, String json) {
        var result = mock(SmsResponse.class);
        when(result.isSuccess()).thenReturn(success);
        when(result.getData()).thenReturn(JSONUtil.parseObj(json));
        return result;
    }
    void providerReturns(SmsResponse result) {
        doReturn(provider).when(sender).client();
        when(provider.sendMessage(anyString(), anyString(), any(LinkedHashMap.class))).thenReturn(result);
    }
    @Test void sendsRegistrationTemplateWithE164AndOrderedCodeAndFiveMinutes() {
        providerReturns(response(true,"{\"Response\":{\"SendStatusSet\":[{\"Code\":\"Ok\"}]}}"));
        sender.send("13900000000","123456");
        var parameters = org.mockito.ArgumentCaptor.forClass(LinkedHashMap.class);
        verify(provider).sendMessage(eq("+8613900000000"),eq("fixture-template"),parameters.capture());
        assertEquals(List.of("123456","5"),List.copyOf(parameters.getValue().values()));
    }
    @Test void missingConfigurationNeverContactsProvider() {
        properties.setSecretKey("");
        assertThrows(ServiceException.class,() -> sender.send("13900000000","123456"));
        verify(sender,never()).client();
    }
    @Test void refusesEmptyRecipientStatusesEvenWhenSdkReportsSuccess() {
        providerReturns(response(true,"{\"Response\":{\"SendStatusSet\":[]}}"));
        assertThrows(ServiceException.class,() -> sender.send("13900000000","123456"));
    }
    @Test void recipientRejectionDoesNotBecomeSuccess() {
        providerReturns(response(true,"{\"Response\":{\"SendStatusSet\":[{\"Code\":\"FailedOperation\"}]}}"));
        assertThrows(ServiceException.class,() -> sender.send("13900000000","123456"));
    }
    @Test void providerExceptionDoesNotExposeItsPrivateMessageOrRetry() {
        doReturn(provider).when(sender).client();
        when(provider.sendMessage(anyString(),anyString(),any(LinkedHashMap.class)))
            .thenThrow(new IllegalStateException("private-provider-payload"));
        var error = assertThrows(ServiceException.class,() -> sender.send("13900000000","123456"));
        assertFalse(error.getMessage().contains("private-provider"));
        verify(provider,times(1)).sendMessage(anyString(),anyString(),any(LinkedHashMap.class));
    }
    @Test void malformedPhoneNeverContactsProvider() {
        assertThrows(ServiceException.class,() -> sender.send("invalid","123456"));
        verify(sender,never()).client();
    }
    @Test void createsRealAdapterWithoutGlobalSmsFactoryStartupOrNetwork() {
        assertNotNull(new TencentRegistrationSmsSender(properties).client());
    }
}
