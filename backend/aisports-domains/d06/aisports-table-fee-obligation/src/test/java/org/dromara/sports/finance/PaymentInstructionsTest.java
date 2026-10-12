package org.dromara.sports.finance;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.finance.domain.SportsFeeObligation;
import org.dromara.sports.finance.domain.SportsFeePolicy;
import org.dromara.sports.finance.mapper.*;
import org.dromara.sports.finance.service.FinanceService;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.util.*;
import java.util.function.Supplier;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 隔离依赖验证历史付款依据，不能用当前渠道/active版本覆盖已提交快照。 */
@Tag("local")
class PaymentInstructionsTest {
    private final Map<Class<?>, Object> dependencies = new HashMap<>();
    private final FinanceService service = createService();
    private <T> T dependency(Class<T> type) { return type.cast(dependencies.get(type)); }
    private FinanceService createService() {
        try {
            var constructor = FinanceService.class.getDeclaredConstructors()[0];
            Object[] args = Arrays.stream(constructor.getParameterTypes()).map(type -> {
                Object value = type == ObjectMapper.class ? new ObjectMapper() : mock(type);
                dependencies.put(type, value); return value;
            }).toArray();
            return (FinanceService) constructor.newInstance(args);
        } catch (ReflectiveOperationException error) { throw new AssertionError(error); }
    }
    private void obligation(String json) {
        SportsFeeObligation obligation = new SportsFeeObligation(); obligation.setFeePolicyId(22L); obligation.setQuoteSnapshot(json);
        when(dependency(SportsFeeObligationMapper.class).selectOne(any())).thenReturn(obligation);
    }
    private <T> T inTenant(Supplier<T> action) {
        try (var tenant = mockStatic(TenantHelper.class)) {
            tenant.when(() -> TenantHelper.dynamic(eq("fixture"), any(Supplier.class))).thenAnswer(invocation -> ((Supplier<?>) invocation.getArgument(1)).get());
            return action.get();
        }
    }
    @Test void readsSubmittedSnapshotWithoutCurrentEventConfigOrPolicy() {
        obligation("{\"paymentMode\":\"event\",\"paymentSettings\":{\"revision\":3,\"instruction\":\"原始说明\",\"channels\":[{\"type\":\"wechat\",\"label\":\"微信\",\"qrFileId\":\"11\",\"instruction\":\"\"}]}}");
        var settings = inTenant(() -> service.paymentInstructions("fixture", 1L));
        assertEquals("原始说明", settings.instruction()); assertEquals(11L, settings.channels().get(0).qrFileId());
        verifyNoInteractions(dependency(SportsEventPaymentConfigMapper.class), dependency(SportsFeePolicyMapper.class));
    }
    @Test void legacyQrComesFromObligationPolicyIdAndNeverActivePolicy() {
        obligation("{\"paymentMode\":\"organizer_qr\",\"payInstruction\":\"旧付款说明\"}");
        SportsFeePolicy original = new SportsFeePolicy(); original.setQrFileId(11L);
        when(dependency(SportsFeePolicyMapper.class).selectById(22L)).thenReturn(original);
        var settings = inTenant(() -> service.paymentInstructions("fixture", 1L));
        assertEquals(11L, settings.channels().get(0).qrFileId()); assertEquals("旧付款说明", settings.instruction());
        verify(dependency(SportsFeePolicyMapper.class), never()).selectOne(any()); verifyNoInteractions(dependency(SportsEventPaymentConfigMapper.class));
    }
}
