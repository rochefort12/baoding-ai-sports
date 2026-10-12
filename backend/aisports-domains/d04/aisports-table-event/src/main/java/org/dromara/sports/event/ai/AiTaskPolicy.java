package org.dromara.sports.event.ai;

import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.api.DocumentKinds;

import java.math.BigDecimal;
import java.util.Set;

/**
 * 从资料创建赛事的限额、确认和工具边界。不访问数据库。
 */
public final class AiTaskPolicy {

    public static final String SCENE = "event.create_from_document";
    public static final String BUSINESS_OBJECT = "event";
    public static final String NEED_API_KEY = "NEED_API_KEY";
    public static final BigDecimal FREE_AMOUNT = new BigDecimal("0.00");
    public static final String FREE_MODE = "free";
    public static final int MAX_UPLOAD_FILES = 15;

    public static final Set<String> TOOLS = Set.of(
        "read_document_block", "describe_event_constraints", "validate_event_proposal");
    public static final Set<String> DENIED = Set.of(
        "publish_event", "cancel_event", "offline_event", "confirm_payment", "refund", "write_table", "place_fee");

    private AiTaskPolicy() {
    }

    public static void requireConsent(boolean consent) {
        if (!consent) {
            throw new ServiceException("请先同意把资料发送到当前配置的模型服务");
        }
    }

    /** 解析/读取文件正文之前拒绝超预算批次，不能只依赖浏览器限制。 */
    public static void requireUpload(long[] sizes) {
        if (sizes == null || sizes.length == 0 || sizes.length > MAX_UPLOAD_FILES) throw new ServiceException("请选择1至" + MAX_UPLOAD_FILES + "份赛事资料");
        long total = 0;
        for (long size : sizes) {
            if (size <= 0 || size > 15L * 1024 * 1024) throw new ServiceException("单份赛事资料需非空且不超过15MB");
            total += size;
        }
        if (total > 40L * 1024 * 1024) throw new ServiceException("赛事资料合计不超过40MB");
    }

    public static void requireDaily(long createdToday, int limit) {
        if (createdToday >= limit) {
            throw new ServiceException("本组织今日的资料建赛次数已用完");
        }
    }

    public static void requireScanPages(int scanPages, int maxScanPages) {
        if (scanPages > maxScanPages) {
            throw new ServiceException("扫描版 PDF 最多" + maxScanPages + "页");
        }
    }

    public static boolean needsModel(String mediaKind) {
        return DocumentKinds.image(mediaKind) || "pdf-scan".equals(mediaKind);
    }

    public static String plan(boolean keyConfigured) {
        return keyConfigured ? "MODEL" : "NEED_KEY";
    }

    public static String confirmDecision(String status) {
        if ("CREATED".equals(status)) {
            return "RETURN";
        }
        if ("PENDING_CONFIRMATION".equals(status)) {
            return "APPLY";
        }
        return "REJECT";
    }

    public static String toolDecision(String name) {
        if (name != null && TOOLS.contains(name)) {
            return "ALLOW";
        }
        return "REFUSE";
    }

    public static boolean sameOrganization(Long taskOrganizationId, Long callerOrganizationId) {
        return taskOrganizationId != null && taskOrganizationId.equals(callerOrganizationId);
    }

    public static void requireFree(BigDecimal amount, String mode) {
        if (amount == null || amount.compareTo(BigDecimal.ZERO) != 0 || !FREE_MODE.equals(mode)) {
            throw new ServiceException("从资料创建的竞赛项目只能免费");
        }
    }
}
