package org.dromara.sports.api;

/**
 * 业务文件只经这里进出对象存储。换云厂商时改默认对象存储配置，不改调用方。
 * 不返回可长期公开的地址。
 */
public interface StoredObjectApi {

    String PAYMENT_QR = "payment-qr";
    /** 私有付款凭证，不经通用媒体接口访问，也不证明到账。 */
    String PAYMENT_PROOF = "payment-proof";
    /** 本人主动上传的运动头像，展示授权由运动名片服务判断。 */
    String PROFILE_AVATAR = "profile-avatar";
    /** 认证荣誉的私有依据；不能经赛事媒体、头像或普通资料接口访问。 */
    String HONOR_PROOF = "honor-proof";

    long keepHonorProof(long ownerAccountId, byte[] body);

    DocumentBody readHonorProof(long fileId, long ownerAccountId);

    long keepProfileAvatar(long ownerAccountId, byte[] body);

    /** 只接受该账号持有的头像文件；不复用通用组织图片读取。 */
    ImageBody readProfileAvatar(long fileId, long ownerAccountId);

    long keepPaymentProof(long ownerAccountId, String owningTenantId, byte[] body);

    ImageBody readPaymentProof(long fileId, String owningTenantId);
    String EVENT_BANNER = "event-banner";
    String EVENT_RULES = "event-rules";
    String EVENT_NOTICE = "event-notice";
    String EVENT_DECLARATION = "event-declaration";
    String EVENT_ROUTE = "event-route";
    /** 从资料创建赛事的原始文件。不能拿来存收款码。 */
    String AI_SOURCE = "ai-source";

    /**
     * 保存通用业务 JPG、PNG 或 WebP；付款凭证必须使用专用私有接口。
     */
    long keepImage(long ownerAccountId, String owningTenantId, String purpose, byte[] body);

    ImageBody read(long fileId);

    /**
     * 承办方预览自己组织刚上传的图片。
     */
    ImageBody readOwned(long fileId, String owningTenantId);

    /**
     * 文件必须仍有效，用途和归属租户都要对上。
     */
    void requireImage(long fileId, String purpose, String owningTenantId);

    /**
     * 保存办赛资料。用途目前只接受 {@link #AI_SOURCE}。类型按内容判断，不看扩展名。
     */
    long keepDocument(long ownerAccountId, String owningTenantId, String purpose, byte[] body);

    DocumentBody readOwnedDocument(long fileId, String owningTenantId);

    /**
     * 用户放弃任务时删除原始文件。只接受 {@link #AI_SOURCE}。
     */
    void discard(long fileId, String purpose, String owningTenantId);

    record ImageBody(String contentType, byte[] body) {
    }

    record DocumentBody(String contentType, byte[] body) {
    }
}
