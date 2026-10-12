package org.dromara.sports.registration;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

/** 参赛声明的本人点击确认。摘要变化后旧确认不再有效。不是证件核验，也不是电子签章。 */
public final class DeclarationAckRules {
    private DeclarationAckRules() { }

    public static boolean required(Boolean flag, String text, Long fileId) {
        if (!Boolean.TRUE.equals(flag)) {
            return false;
        }
        return (text != null && !text.isBlank()) || fileId != null;
    }

    public static String digest(String text, Long fileId) {
        String raw = (text == null ? "" : text.trim()) + "\n" + (fileId == null ? "" : fileId);
        try {
            byte[] hash = MessageDigest.getInstance("SHA-256").digest(raw.getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder(hash.length * 2);
            for (byte item : hash) {
                hex.append(String.format("%02x", item));
            }
            return hex.toString();
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 不可用");
        }
    }
}
