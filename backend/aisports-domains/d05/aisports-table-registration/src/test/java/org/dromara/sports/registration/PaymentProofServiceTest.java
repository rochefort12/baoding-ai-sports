package org.dromara.sports.registration;

import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.api.FeeApi.ObligationView;
import org.dromara.sports.api.StoredObjectApi;
import org.dromara.sports.registration.domain.SportsRegistrationPaymentProof;
import org.dromara.sports.registration.mapper.SportsRegistrationPaymentProofMapper;
import org.dromara.sports.registration.service.PaymentProofService;
import org.dromara.sports.registration.service.RegistrationService;
import org.junit.jupiter.api.*;
import java.math.BigDecimal;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Function;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 模拟报名锁/存储之间的撤回竞态；不代替真实角色及对象存储验证。 */
@Tag("local")
class PaymentProofServiceTest {
    final RegistrationService registrations = mock(RegistrationService.class);
    final SportsRegistrationPaymentProofMapper mapper = mock(SportsRegistrationPaymentProofMapper.class);
    final StoredObjectApi storage = mock(StoredObjectApi.class);
    final PaymentProofService service = new PaymentProofService(registrations, mapper, storage);
    final AtomicReference<RegistrationService.ProofContext> context = new AtomicReference<>();
    RegistrationService.ProofContext ctx(String state, long obligation, String funding) {
        return new RegistrationService.ProofContext("fixture", 2L, 3L, state,
            new ObligationView(obligation, 9L, new BigDecimal("198"), "offline", funding, "", false, null), "normal");
    }
    @BeforeEach void setup() {
        context.set(ctx("submitted", 4L, "open"));
        when(registrations.withParticipantProof(eq(2L), any())).thenAnswer(invocation ->
            ((Function<RegistrationService.ProofContext, ?>) invocation.getArgument(1)).apply(context.get()));
        when(storage.keepPaymentProof(anyLong(), anyString(), any())).thenReturn(5L);
        when(mapper.insert(any(SportsRegistrationPaymentProof.class))).thenAnswer(invocation -> {
            ((SportsRegistrationPaymentProof) invocation.getArgument(0)).setId(6L); return 1;
        });
    }
    @Test void draftCannotCreateFinancialMaterial() {
        context.set(ctx("draft", 4L, "open"));
        assertThrows(ServiceException.class, () -> service.upload(2L, "key", new byte[]{1}));
        verifyNoInteractions(storage);
    }
    @Test void proofDoesNotDeclareOrConfirmPayment() {
        var proof = service.upload(2L, "key", new byte[]{1});
        assertEquals(4L, proof.obligationId());
        verify(storage).keepPaymentProof(3L, "fixture", new byte[]{1});
        verify(mapper).insert(argThat((SportsRegistrationPaymentProof row) -> row.getRegistrationId() == 2L && row.getObligationId() == 4L));
    }
    @Test void withdrawalDuringStorageCannotAttachToNewObligation() {
        when(storage.keepPaymentProof(anyLong(), anyString(), any())).thenAnswer(invocation -> {
            context.set(ctx("submitted", 7L, "open")); return 5L;
        });
        assertThrows(ServiceException.class, () -> service.upload(2L, "key", new byte[]{1}));
        verify(mapper, never()).insert(any(SportsRegistrationPaymentProof.class));
    }
    @Test void repeatedRequestDoesNotCreateSecondObject() throws Exception {
        var row = new SportsRegistrationPaymentProof(); row.setId(6L); row.setFileId(5L); row.setObligationId(4L);
        row.setContentDigest(java.util.HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(new byte[]{1})));
        when(mapper.selectOne(any())).thenReturn(row);
        assertEquals(6L, service.upload(2L, "key", new byte[]{1}).id());
        verifyNoInteractions(storage);
    }
    @Test void differentContentCannotReuseUploadRequest() {
        var row = new SportsRegistrationPaymentProof(); row.setContentDigest("different");
        when(mapper.selectOne(any())).thenReturn(row);
        assertThrows(ServiceException.class, () -> service.upload(2L, "key", new byte[]{1}));
        verifyNoInteractions(storage);
    }
    @Test void closedObligationRejectsNewProof() {
        context.set(ctx("approved", 4L, "settled"));
        assertThrows(ServiceException.class, () -> service.upload(2L, "key", new byte[]{1}));
        verifyNoInteractions(storage);
    }
    @Test void proofIdMustBelongToAuthorizedRegistration() {
        var row = new SportsRegistrationPaymentProof(); row.setRegistrationId(99L);
        when(mapper.selectById(6L)).thenReturn(row);
        assertThrows(ServiceException.class, () -> service.image(2L, 6L, false));
        verifyNoInteractions(storage);
    }
}
