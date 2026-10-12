package org.dromara.sports.event.ai;

import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.api.DocumentKinds;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;
import java.io.ByteArrayOutputStream;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

@Tag("local")
class AiDocumentPolicyTest {

    @Test
    void extensionDoesNotDecideTypeAndLegacyDocIsRejected() throws Exception {
        byte[] docx = zip("word/document.xml", "<w:document/>");
        assertEquals("docx", DocumentKinds.sniff(docx).media());
        byte[] xlsx = zip("xl/workbook.xml", "<workbook/>");
        assertEquals("xlsx", DocumentKinds.sniff(xlsx).media());
        byte[] jpegNamedLikeDoc = new byte[] {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, 0, 1};
        assertEquals("jpeg", DocumentKinds.sniff(jpegNamedLikeDoc).media());
        byte[] ole = new byte[] {(byte) 0xD0, (byte) 0xCF, 0x11, (byte) 0xE0, 0, 0, 0, 0};
        ServiceException rejected = assertThrows(ServiceException.class, () -> {
            try {
                DocumentKinds.sniff(ole);
            } catch (IllegalArgumentException exception) {
                throw new ServiceException(exception.getMessage());
            }
        });
        assertTrue(rejected.getMessage().contains(".doc"));
    }

    @Test
    void consentQuotaPagesAndTools() {
        assertThrows(ServiceException.class, () -> AiTaskPolicy.requireConsent(false));
        AiTaskPolicy.requireConsent(true);
        assertThrows(ServiceException.class, () -> AiTaskPolicy.requireDaily(20, 20));
        AiTaskPolicy.requireDaily(19, 20);
        assertThrows(ServiceException.class, () -> AiTaskPolicy.requireScanPages(16, 15));
        AiTaskPolicy.requireScanPages(15, 15);
        assertEquals("NEED_KEY", AiTaskPolicy.plan(false));
        assertEquals("MODEL", AiTaskPolicy.plan(true));
        assertEquals("REFUSE", AiTaskPolicy.toolDecision("publish_event"));
        assertEquals("REFUSE", AiTaskPolicy.toolDecision("refund"));
        assertEquals("ALLOW", AiTaskPolicy.toolDecision("validate_event_proposal"));
        assertEquals("RETURN", AiTaskPolicy.confirmDecision("CREATED"));
        assertEquals("APPLY", AiTaskPolicy.confirmDecision("PENDING_CONFIRMATION"));
        assertEquals("REJECT", AiTaskPolicy.confirmDecision("FAILED"));
        assertEquals(false, AiTaskPolicy.sameOrganization(2L, 9L));
        assertThrows(ServiceException.class, () -> AiTaskPolicy.requireFree(new BigDecimal("1.00"), "organizer_qr"));
        AiTaskPolicy.requireFree(new BigDecimal("0.00"), "free");
    }

    private byte[] zip(String name, String content) throws Exception {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try (ZipOutputStream zip = new ZipOutputStream(out)) {
            zip.putNextEntry(new ZipEntry(name));
            zip.write(content.getBytes(StandardCharsets.UTF_8));
            zip.closeEntry();
        }
        return out.toByteArray();
    }
}
