package org.dromara.sports.api;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.Locale;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * 按文件内容判断资料类型。扩展名不参与判断。
 * 旧版 doc 直接拒绝。pdf 在这里只表示有文字层容器，扫描页由解析方再区分。
 */
public final class DocumentKinds {

    public static final int MAX_BYTES = 15 * 1024 * 1024;

    private DocumentKinds() {
    }

    public static void requireSize(byte[] body) {
        if (body == null || body.length == 0) {
            throw new IllegalArgumentException("请选择文件");
        }
        if (body.length > MAX_BYTES) {
            throw new IllegalArgumentException("单个文件不能超过15MB");
        }
    }

    public static Kind sniff(byte[] body) {
        requireSize(body);
        if (isOle(body)) {
            throw new IllegalArgumentException("不支持旧版 Word（.doc），请另存为 docx");
        }
        if (isJpeg(body)) {
            return new Kind("jpeg", "image/jpeg", ".jpg");
        }
        if (isPng(body)) {
            return new Kind("png", "image/png", ".png");
        }
        if (isWebp(body)) {
            return new Kind("webp", "image/webp", ".webp");
        }
        if (isPdf(body)) {
            return new Kind("pdf", "application/pdf", ".pdf");
        }
        if (isZip(body)) {
            return office(body);
        }
        throw new IllegalArgumentException("文件类型无法识别");
    }

    public static boolean image(String media) {
        return "jpeg".equals(media) || "png".equals(media) || "webp".equals(media);
    }

    private static Kind office(byte[] body) {
        boolean word = false;
        boolean excel = false;
        try (ZipInputStream zip = new ZipInputStream(new ByteArrayInputStream(body))) {
            ZipEntry entry;
            int seen = 0;
            while ((entry = zip.getNextEntry()) != null && seen < 80) {
                seen++;
                String name = entry.getName().replace('\\', '/').toLowerCase(Locale.ROOT);
                if (name.startsWith("word/")) {
                    word = true;
                }
                if (name.startsWith("xl/")) {
                    excel = true;
                }
            }
        } catch (IOException exception) {
            throw new IllegalArgumentException("文件类型无法识别");
        }
        if (word && !excel) {
            return new Kind("docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", ".docx");
        }
        if (excel && !word) {
            return new Kind("xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", ".xlsx");
        }
        throw new IllegalArgumentException("文件类型无法识别");
    }

    private static boolean isOle(byte[] body) {
        return body.length >= 8
            && (body[0] & 0xFF) == 0xD0 && (body[1] & 0xFF) == 0xCF
            && (body[2] & 0xFF) == 0x11 && (body[3] & 0xFF) == 0xE0;
    }

    private static boolean isJpeg(byte[] body) {
        return body.length >= 3 && (body[0] & 0xFF) == 0xFF && (body[1] & 0xFF) == 0xD8 && (body[2] & 0xFF) == 0xFF;
    }

    private static boolean isPng(byte[] body) {
        return body.length >= 8 && body[0] == (byte) 0x89 && body[1] == 0x50 && body[2] == 0x4E && body[3] == 0x47;
    }

    private static boolean isWebp(byte[] body) {
        return body.length >= 12 && body[0] == 'R' && body[1] == 'I' && body[2] == 'F' && body[3] == 'F'
            && body[8] == 'W' && body[9] == 'E' && body[10] == 'B' && body[11] == 'P';
    }

    private static boolean isPdf(byte[] body) {
        return body.length >= 5 && body[0] == '%' && body[1] == 'P' && body[2] == 'D' && body[3] == 'F' && body[4] == '-';
    }

    private static boolean isZip(byte[] body) {
        return body.length >= 4 && body[0] == 'P' && body[1] == 'K';
    }

    public record Kind(String media, String contentType, String extension) {
    }
}
