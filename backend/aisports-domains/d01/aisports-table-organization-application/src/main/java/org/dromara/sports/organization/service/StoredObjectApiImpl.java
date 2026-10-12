package org.dromara.sports.organization.service;

import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.oss.core.OssClient;
import org.dromara.common.oss.exception.OssException;
import org.dromara.common.oss.factory.OssFactory;
import org.dromara.sports.api.DocumentKinds;
import org.dromara.sports.api.StoredObjectApi;
import org.dromara.sports.organization.domain.SportsFile;
import org.dromara.sports.organization.mapper.SportsFileMapper;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.io.InputStream;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Set;
import java.util.UUID;

/**
 * 用框架当前默认的 S3 客户端保存业务图片。MinIO 和云对象存储都走同一条配置。
 */
@Service
public class StoredObjectApiImpl implements StoredObjectApi {

    private static final int MAX_BYTES = 5 * 1024 * 1024;
    private static final Set<String> PURPOSES = Set.of(
        PAYMENT_QR, EVENT_BANNER, EVENT_RULES, EVENT_NOTICE, EVENT_DECLARATION, EVENT_ROUTE);

    private final SportsFileMapper fileMapper;

    public StoredObjectApiImpl(SportsFileMapper fileMapper) {
        this.fileMapper = fileMapper;
    }

    @Override
    public long keepImage(long ownerAccountId, String owningTenantId, String purpose, byte[] body) {
        if (!PURPOSES.contains(purpose)) {
            throw new ServiceException("图片用途无效");
        }
        return storeImage(ownerAccountId, owningTenantId, purpose, body);
    }

    @Override
    public long keepPaymentProof(long ownerAccountId, String owningTenantId, byte[] body) {
        return storeImage(ownerAccountId, owningTenantId, PAYMENT_PROOF, body);
    }

    @Override
    public long keepProfileAvatar(long ownerAccountId, byte[] body) {
        // 头像属于平台本人身份；不借组织权限把它变成组织媒体。
        return storeImage(ownerAccountId, "000000", PROFILE_AVATAR, body);
    }

    @Override
    public ImageBody readProfileAvatar(long fileId, long ownerAccountId) {
        SportsFile file = requireRow(fileId);
        if (!PROFILE_AVATAR.equals(file.getPurpose()) || !Long.valueOf(ownerAccountId).equals(file.getOwnerAccountId())) {
            throw new ServiceException("头像不属于该运动名片");
        }
        return body(file);
    }

    @Override
    public ImageBody readPaymentProof(long fileId, String owningTenantId) {
        return body(requireOwned(fileId, owningTenantId, PAYMENT_PROOF));
    }

    @Override
    public long keepHonorProof(long ownerAccountId, byte[] bytes) {
        if (ownerAccountId <= 0 || bytes == null || bytes.length == 0 || bytes.length > MAX_BYTES) {
            throw new ServiceException("请选择不超过5MB的图片或PDF证明");
        }
        DocumentKinds.Kind kind;
        try { kind = DocumentKinds.sniff(bytes); }
        catch (IllegalArgumentException exception) { throw new ServiceException("证明仅支持 JPG、PNG、WebP 或 PDF"); }
        if (!Set.of("image/jpeg", "image/png", "image/webp", "application/pdf").contains(kind.contentType())) {
            throw new ServiceException("证明仅支持 JPG、PNG、WebP 或 PDF");
        }
        return storeDocument(ownerAccountId, "000000", HONOR_PROOF, "result", bytes, kind);
    }

    @Override
    public DocumentBody readHonorProof(long fileId, long ownerAccountId) {
        SportsFile file = requireRow(fileId);
        if (!HONOR_PROOF.equals(file.getPurpose()) || !Long.valueOf(ownerAccountId).equals(file.getOwnerAccountId())
            || !"000000".equals(file.getOwningTenantId())) {
            throw new ServiceException("证明不属于当前认证申请");
        }
        return documentBody(file);
    }

    private long storeImage(long ownerAccountId, String owningTenantId, String purpose, byte[] body) {
        if (owningTenantId == null || owningTenantId.isBlank()) {
            throw new ServiceException("请先进入组织");
        }
        ImageKind kind = sniff(body);
        String key = "sports/" + purpose + "/" + UUID.randomUUID() + kind.extension;
        try {
            OssClient client = OssFactory.instance();
            client.upload(new java.io.ByteArrayInputStream(body), key, (long) body.length, kind.contentType);
        } catch (OssException exception) {
            throw new ServiceException("对象存储暂时不可用");
        }
        SportsFile row = new SportsFile();
        row.setOwnerAccountId(ownerAccountId);
        row.setOwningTenantId(owningTenantId);
        row.setObjectKey(key);
        row.setSha256(sha256(body));
        row.setPurpose(purpose);
        row.setSensitivity(PAYMENT_QR.equals(purpose) || PAYMENT_PROOF.equals(purpose) ? "finance" : PROFILE_AVATAR.equals(purpose) ? "identity" : "ordinary");
        row.setStatus("active");
        row.setVersion(0);
        try {
            fileMapper.insert(row);
        } catch (RuntimeException exception) {
            try {
                OssFactory.instance().delete(key);
            } catch (RuntimeException ignored) {
                // 元数据没写上时尽量删掉对象，删不掉也不把存储异常盖住原错误。
            }
            throw exception;
        }
        return row.getId();
    }

    @Override
    public ImageBody read(long fileId) {
        SportsFile file = requireRow(fileId);
        rejectPrivateProof(file);
        return body(file);
    }

    @Override
    public ImageBody readOwned(long fileId, String owningTenantId) {
        SportsFile file = requireRow(fileId);
        rejectPrivateProof(file);
        if (owningTenantId == null || !owningTenantId.equals(file.getOwningTenantId())) {
            throw new ServiceException("图片不属于当前组织");
        }
        return body(file);
    }

    private void rejectPrivateProof(SportsFile file) {
        if (PAYMENT_PROOF.equals(file.getPurpose())) {
            throw new ServiceException("付款凭证请从报名付款详情查看");
        }
        if (PROFILE_AVATAR.equals(file.getPurpose())) {
            throw new ServiceException("头像请通过运动名片授权入口查看");
        }
        if (HONOR_PROOF.equals(file.getPurpose())) {
            throw new ServiceException("认证证明请从本人申请或平台审核详情查看");
        }
    }

    @Override
    public void requireImage(long fileId, String purpose, String owningTenantId) {
        SportsFile file = requireRow(fileId);
        if (!purpose.equals(file.getPurpose()) || owningTenantId == null || !owningTenantId.equals(file.getOwningTenantId())) {
            throw new ServiceException("图片不属于当前组织或用途不对");
        }
    }

    @Override
    public long keepDocument(long ownerAccountId, String owningTenantId, String purpose, byte[] body) {
        if (!AI_SOURCE.equals(purpose)) {
            throw new ServiceException("资料用途无效");
        }
        if (owningTenantId == null || owningTenantId.isBlank()) {
            throw new ServiceException("请先进入组织");
        }
        DocumentKinds.Kind kind;
        try {
            kind = DocumentKinds.sniff(body);
        } catch (IllegalArgumentException exception) {
            throw new ServiceException(exception.getMessage());
        }
        return storeDocument(ownerAccountId, owningTenantId, purpose, "ordinary", body, kind);
    }

    private long storeDocument(long ownerAccountId, String owningTenantId, String purpose, String sensitivity,
                               byte[] body, DocumentKinds.Kind kind) {
        String key = "sports/" + purpose + "/" + UUID.randomUUID() + kind.extension();
        try {
            OssClient client = OssFactory.instance();
            client.upload(new java.io.ByteArrayInputStream(body), key, (long) body.length, kind.contentType());
        } catch (OssException exception) {
            throw new ServiceException("对象存储暂时不可用");
        }
        SportsFile row = new SportsFile();
        row.setOwnerAccountId(ownerAccountId);
        row.setOwningTenantId(owningTenantId);
        row.setObjectKey(key);
        row.setSha256(sha256(body));
        row.setPurpose(purpose);
        row.setSensitivity(sensitivity);
        row.setStatus("active");
        row.setVersion(0);
        try {
            fileMapper.insert(row);
        } catch (RuntimeException exception) {
            try {
                OssFactory.instance().delete(key);
            } catch (RuntimeException ignored) {
                // 元数据没写上时尽量删掉对象。
            }
            throw exception;
        }
        return row.getId();
    }

    @Override
    public DocumentBody readOwnedDocument(long fileId, String owningTenantId) {
        SportsFile file = requireOwned(fileId, owningTenantId, AI_SOURCE);
        return documentBody(file);
    }

    private DocumentBody documentBody(SportsFile file) {
        try {
            OssClient client = OssFactory.instance();
            try (InputStream input = client.getObjectContent(file.getObjectKey())) {
                return new DocumentBody(contentTypeOf(file.getObjectKey()), input.readAllBytes());
            }
        } catch (OssException | IOException exception) {
            throw new ServiceException("资料暂时读不出来");
        }
    }

    @Override
    public void discard(long fileId, String purpose, String owningTenantId) {
        SportsFile file = requireOwned(fileId, owningTenantId, purpose);
        if (!AI_SOURCE.equals(purpose)) {
            throw new ServiceException("资料用途无效");
        }
        try {
            OssFactory.instance().delete(file.getObjectKey());
        } catch (OssException exception) {
            throw new ServiceException("原始文件还没删掉，请再放弃一次");
        }
        file.setStatus("deleted");
        if (fileMapper.updateById(file) != 1) {
            throw new ServiceException("原始文件还没删掉，请再放弃一次");
        }
    }

    private SportsFile requireOwned(long fileId, String owningTenantId, String purpose) {
        SportsFile file = requireRow(fileId);
        if (owningTenantId == null || !owningTenantId.equals(file.getOwningTenantId()) || !purpose.equals(file.getPurpose())) {
            throw new ServiceException("资料不属于当前组织");
        }
        return file;
    }

    private String contentTypeOf(String key) {
        if (key == null) {
            return "application/octet-stream";
        }
        if (key.endsWith(".png")) {
            return "image/png";
        }
        if (key.endsWith(".webp")) {
            return "image/webp";
        }
        if (key.endsWith(".jpg")) {
            return "image/jpeg";
        }
        if (key.endsWith(".pdf")) {
            return "application/pdf";
        }
        if (key.endsWith(".docx")) {
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
        }
        if (key.endsWith(".xlsx")) {
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
        }
        return "application/octet-stream";
    }

    private ImageBody body(SportsFile file) {
        try {
            OssClient client = OssFactory.instance();
            try (InputStream input = client.getObjectContent(file.getObjectKey())) {
                return new ImageBody(contentType(file.getObjectKey()), input.readAllBytes());
            }
        } catch (OssException | IOException exception) {
            throw new ServiceException("图片暂时读不出来");
        }
    }

    private SportsFile requireRow(long fileId) {
        SportsFile file = fileMapper.selectById(fileId);
        if (file == null || !"active".equals(file.getStatus())) {
            throw new ServiceException("图片不存在");
        }
        return file;
    }

    private ImageKind sniff(byte[] body) {
        if (body == null || body.length == 0) {
            throw new ServiceException("请选择图片");
        }
        if (body.length > MAX_BYTES) {
            throw new ServiceException("请上传不超过5MB的图片");
        }
        if (body.length >= 3 && (body[0] & 0xFF) == 0xFF && (body[1] & 0xFF) == 0xD8 && (body[2] & 0xFF) == 0xFF) {
            return new ImageKind("image/jpeg", ".jpg");
        }
        if (body.length >= 8 && body[0] == (byte) 0x89 && body[1] == 0x50 && body[2] == 0x4E && body[3] == 0x47) {
            return new ImageKind("image/png", ".png");
        }
        if (body.length >= 12 && body[0] == 'R' && body[1] == 'I' && body[2] == 'F' && body[3] == 'F'
            && body[8] == 'W' && body[9] == 'E' && body[10] == 'B' && body[11] == 'P') {
            return new ImageKind("image/webp", ".webp");
        }
        throw new ServiceException("请上传 JPG、PNG 或 WebP 图片");
    }

    private String contentType(String key) {
        if (key != null && key.endsWith(".png")) {
            return "image/png";
        }
        if (key != null && key.endsWith(".webp")) {
            return "image/webp";
        }
        return "image/jpeg";
    }

    private String sha256(byte[] body) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(body));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 不可用", exception);
        }
    }

    private record ImageKind(String contentType, String extension) {
    }
}
