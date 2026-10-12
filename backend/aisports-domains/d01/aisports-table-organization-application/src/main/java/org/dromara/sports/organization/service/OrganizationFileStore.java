package org.dromara.sports.organization.service;

import lombok.extern.slf4j.Slf4j;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.oss.exception.OssException;
import org.dromara.common.oss.factory.OssFactory;
import org.dromara.sports.organization.OrganizationSlice;
import org.dromara.sports.organization.domain.SportsFile;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Locale;
import java.util.Set;

/**
 * 办赛申请附件写入当前默认对象存储。早期落在本地目录的文件仍可从磁盘读出。对象键不能当成公开地址。
 */
@Slf4j
@Service
public class OrganizationFileStore {

    private static final Set<String> ALLOWED = Set.of(
        "pdf", "png", "jpg", "jpeg", "webp", "doc", "docx", "xls", "xlsx", "zip", "txt"
    );

    private final Path root;

    public OrganizationFileStore(@Value("${sports.organization.file-dir:../.local/organization-files}") String fileDir) {
        this.root = Path.of(fileDir).toAbsolutePath().normalize();
    }

    public String safeName(String original) {
        String name = original == null ? "" : original.replace('\\', '/');
        int slash = name.lastIndexOf('/');
        if (slash >= 0) {
            name = name.substring(slash + 1);
        }
        name = name.replaceAll("[^\\p{L}\\p{N}._-]", "_");
        if (name.isBlank() || ".".equals(name) || "..".equals(name)) {
            name = "attachment";
        }
        int dot = name.lastIndexOf('.');
        String extension = dot < 0 ? "" : name.substring(dot + 1).toLowerCase(Locale.ROOT);
        if (!ALLOWED.contains(extension)) {
            throw new ServiceException("附件只接受 pdf、图片、Office 文档、zip 或 txt");
        }
        if (name.length() > 80) {
            name = name.substring(name.length() - 80);
        }
        return name;
    }

    public String sha256(byte[] body) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(body));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 不可用", exception);
        }
    }

    public void write(String objectKey, byte[] body) {
        try {
            OssFactory.instance().upload(new ByteArrayInputStream(body), objectKey, (long) body.length, contentType(objectKey));
        } catch (OssException exception) {
            log.warn("办赛附件写入对象存储失败: {}", exception.getMessage());
            throw new ServiceException("附件保存失败");
        }
    }

    public void deleteQuietly(String objectKey) {
        try {
            OssFactory.instance().delete(objectKey);
        } catch (RuntimeException ignored) {
            // 对象存储删不掉时，下面的本地残留同样不提供下载入口。
        }
        try {
            Files.deleteIfExists(resolve(objectKey));
        } catch (IOException ignored) {
            // 数据库事务会回滚元数据。磁盘残留不提供下载入口。
        }
    }

    public byte[] read(SportsFile file) {
        try (InputStream input = OssFactory.instance().getObjectContent(file.getObjectKey())) {
            return input.readAllBytes();
        } catch (OssException | IOException ossFailure) {
            try {
                return Files.readAllBytes(resolve(file.getObjectKey()));
            } catch (IOException exception) {
                throw new ServiceException("附件不存在或无法读取");
            }
        }
    }

    private String contentType(String objectKey) {
        String lower = objectKey == null ? "" : objectKey.toLowerCase(Locale.ROOT);
        if (lower.endsWith(".png")) {
            return "image/png";
        }
        if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) {
            return "image/jpeg";
        }
        if (lower.endsWith(".webp")) {
            return "image/webp";
        }
        if (lower.endsWith(".pdf")) {
            return "application/pdf";
        }
        if (lower.endsWith(".txt")) {
            return "text/plain";
        }
        return "application/octet-stream";
    }

    public String displayName(SportsFile file) {
        String key = file.getObjectKey();
        int slash = key.lastIndexOf('/');
        return slash < 0 ? key : key.substring(slash + 1);
    }

    public String objectKey(Long accountId, Long fileId, String safeName) {
        return OrganizationSlice.FILE_PURPOSE + "/" + accountId + "/" + fileId + "/" + safeName;
    }

    private Path resolve(String objectKey) {
        Path target = root.resolve(objectKey).normalize();
        if (!target.startsWith(root)) {
            throw new ServiceException("附件路径无效");
        }
        return target;
    }
}
