package org.dromara.sports.api;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

/**
 * 报名产生的付款义务。确认到账只改变资金状态，不代替资格审核。
 */
public interface FeeApi {

    /**
     * 报名刚进入已提交时调用。没有生效收费版本时失败。免费也返回义务，但不会有付款。
     */
    ObligationView openOnSubmit(String tenantId, Long registrationId, Long unitId);

    /** Freeze the caller's actual submitted roster revision; legacy callers retain an unknown revision. */
    default ObligationView openOnSubmit(String tenantId, Long registrationId, Long unitId, Integer rosterRevision) {
        return openOnSubmit(tenantId, registrationId, unitId);
    }

    /**
     * 报名从已提交撤回或被拒绝时调用。未付款义务作废；已付款则留下资金后续。
     */
    void onEntryClosed(String tenantId, Long registrationId);

    /**
     * 参赛者在模拟付款里点击付款完成。不产生到账，也不改变报名审核。
     */
    void declarePaid(String tenantId, Long registrationId);

    Optional<ObligationView> current(String tenantId, Long registrationId);

    /**
     * New attendance and fixtures recheck the current obligation in the calling business transaction.
     * Locks the obligation until completion so a concurrent reversal cannot pass the same qualification gate.
     * Does not approve a registration or change any receipt, and keeps historical result reads available.
     */
    void requireParticipationReady(String tenantId, Long registrationId);

    /**
     * 建立竞赛项目时写入第一版生效收费。调用方的事务负责一起提交或一起回滚。
     */
    void placeInitialPolicy(String tenantId, Long unitId, BigDecimal amount, String paymentMode, String instruction, Long qrFileId);

    /**
     * 本人有收费权限时，在调用方事务内调整从未发布且没有业务历史的草稿项目整单价。
     * 相同金额不新建版本；其他修改停用旧版并保留历史。零元免费，非零使用赛事收款设置。
     * 不改赛事收款渠道，不产生付款义务、到账或退款。
     */
    void reviseUnusedDraftPolicy(String tenantId, Long eventId, Long unitId, BigDecimal amount);

    /**
     * 删除未发布赛事草稿时清理尚未使用的价格版本与收款设置，加入调用方同一事务。
     * 配置收费不是实际收款；任何报名或付款义务历史都拒绝清理，不删除资金事实。
     */
    void discardUnusedDraftPricing(String tenantId, Long eventId);

    /**
     * 当前生效收费若是承办方二维码，返回那张图的文件编号。
     */
    Optional<Long> activeQrFileId(String tenantId, Long unitId);

    /** 当前赛事收款配置是否可用，仅发布门禁读取就绪状态，不公开银行资料和收款码。 */
    boolean eventPaymentReady(String tenantId, Long eventId);

    /**
     * 发布核对使用的赛事收款设置版本；未设置返回 -1，不返回银行信息或收款码。
     * 调用方持有赛事行锁，设置写入同样先锁赛事；说明或渠道每次保存增版，可拒绝核对后变动。
     */
    int eventPaymentRevision(String tenantId, Long eventId);

    /** 报名管理人授权后读取当次提交的付款快照；二维码只通过受保护的图片接口读取。 */
    PaymentSettings paymentInstructions(String tenantId, Long registrationId);

    record PaymentSettings(int revision, String instruction, List<PaymentChannel> channels) {
    }

    /** 每类最多一个。银行账号受组织及报名用途授权保护，不加入公开赛事/AI事实。 */
    record PaymentChannel(String type, String label, Long qrFileId, String accountName,
                          String bankName, String bankAccount, String instruction) {
    }

    /**
     * 公开页展示各项目当前生效的应付金额。编号与报名使用的竞赛项目是同一条，方便登录后回到该项目。不含收款码。
     */
    /** 包含未配置费用的项目，其金额/方式为 null，调用方展示待确认并拒绝发布。 */
    List<PublicUnitPrice> publicUnitPrices(String tenantId, Long eventId);

    record PublicUnitPrice(Long unitId, String unitName, BigDecimal amount, String paymentMode, String payInstruction) {
    }

    /**
     * 任一提交版本仍有未到账义务、退款待办或未核对异常。只返回待办标记，不暴露资金材料。
     */
    boolean unsettled(String tenantId, Long registrationId);

    /**
     * 赛事取消后的资金收尾。未付款义务改为不再应付；已到账留下退款待处理。不改报名状态。
     */
    void settleCancellation(String tenantId, Long eventId);

    record ObligationView(Long obligationId, Long feePolicyId, BigDecimal amount, String paymentMode,
                          String status, String payInstruction, boolean participantDeclared, Long pendingActionId) {
    }
}
