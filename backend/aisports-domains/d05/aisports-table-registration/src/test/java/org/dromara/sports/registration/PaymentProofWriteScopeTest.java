package org.dromara.sports.registration;

import org.dromara.sports.platform.core.SportsAction;
import org.dromara.sports.registration.service.PaymentProofService;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.util.Set;
import static org.junit.jupiter.api.Assertions.*;

/** The participant upload transaction also stores private file metadata through the public file API. */
@Tag("local")
class PaymentProofWriteScopeTest {
    @Test
    void uploadDeclaresItsPrivateFileMetadataAccess() throws Exception {
        var scope = PaymentProofService.class.getMethod("upload", Long.class, String.class, byte[].class)
            .getAnnotation(SportsAction.class);
        assertNotNull(scope);
        assertTrue(Set.of(scope.reads()).contains("asp_file"));
        assertTrue(Set.of(scope.writes()).contains("asp_file"));
        assertTrue(Set.of(scope.writes()).contains("asp_registration_payment_proof"));
    }
}
