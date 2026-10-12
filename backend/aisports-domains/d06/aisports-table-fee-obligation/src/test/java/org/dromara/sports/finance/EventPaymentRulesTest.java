package org.dromara.sports.finance;

import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.api.FeeApi.PaymentChannel;
import org.dromara.sports.finance.service.EventPaymentRules;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.util.List;
import static org.junit.jupiter.api.Assertions.*;

@Tag("local")
class EventPaymentRulesTest {
    private PaymentChannel channel(String type, Long qr, String note) { return new PaymentChannel(type, "自定义码", qr, "模拟户名", "模拟银行", "SIMULATED-ACCOUNT", note); }
    @Test void acceptsAllFiveChannelsAndClearsIrrelevantBankFields() {
        var channels = EventPaymentRules.normalize(List.of(channel("wechat", 1L, ""), channel("alipay", 2L, ""), channel("bank", null, ""), channel("custom_qr", 3L, ""), channel("offline", null, "联系模拟承办方")));
        assertEquals(5, channels.size()); assertNull(channels.get(0).bankAccount()); assertEquals("SIMULATED-ACCOUNT", channels.get(2).bankAccount());
    }
    @Test void rejectsMissingQrDuplicateAndUnknownChannels() {
        assertThrows(ServiceException.class, () -> EventPaymentRules.normalize(List.of(channel("wechat", null, ""))));
        assertThrows(ServiceException.class, () -> EventPaymentRules.normalize(List.of(channel("wechat", 1L, ""), channel("wechat", 2L, ""))));
        assertThrows(ServiceException.class, () -> EventPaymentRules.normalize(List.of(channel("invalid", 1L, ""))));
    }
    @Test void requiresActualBankAndOfflineInstructionsButAllowsEmptyFreeEventConfig() {
        assertThrows(ServiceException.class, () -> EventPaymentRules.normalize(List.of(new PaymentChannel("bank", "银行", null, "", "银行", "模拟账号", ""))));
        assertThrows(ServiceException.class, () -> EventPaymentRules.normalize(List.of(channel("offline", null, ""))));
        assertTrue(EventPaymentRules.normalize(List.of()).isEmpty());
    }
}
