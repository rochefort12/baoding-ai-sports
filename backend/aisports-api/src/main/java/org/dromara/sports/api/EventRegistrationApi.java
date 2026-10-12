package org.dromara.sports.api;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

/**
 * 报名要读的赛事事实。报名模块不直接查赛事表。
 */
public interface EventRegistrationApi {

    /**
     * 已发布且组织仍准入的赛事。未公开时为空。已取消仍返回，由调用方拒绝报名。
     */
    Optional<EventRegistrationGate> publicGate(Long eventId);

    /**
     * 按编号读取赛事名称和时间。只供已经是该赛事报名成员的人查看，不是公开查询。
     */
    Optional<EventRegistrationGate> findEvent(Long eventId);

    /**
     * 当前组织管理会话拥有的赛事。
     */
    Optional<EventRegistrationGate> managedGate(Long eventId);

    /**
     * 当前组织可挂竞赛单元的赛事。
     */
    List<ManagedEventOption> listManaged();

    /**
     * 首笔正式提交后锁定审核方式。已经锁定时不再改。
     */
    void lockRegistrationReview(String tenantId, Long eventId);

    /** 报名要展示和核对的参赛声明。没有声明内容时 confirmRequired 仍可能为 true，由调用方判断是否真的需要点击。 */
    Optional<DeclarationNotice> declaration(Long eventId);

    /** New business stops during wrap-up; historical reads and aftercare stay available. */
    default boolean acceptsNewBusiness(Long eventId) { return true; }
    /** Account closure may release finished history only after all event responsibilities close. */
    default boolean fullyClosed(Long eventId) { return false; }

    record DeclarationNotice(boolean confirmRequired, String text, Long fileId) {
    }

    record EventRegistrationGate(Long eventId, String tenantId, Long organizationId, String name,
                                 String publicationStatus, String holdingStatus,
                                 OffsetDateTime registrationOpensAt, OffsetDateTime registrationClosesAt,
                                 OffsetDateTime startsAt, OffsetDateTime endsAt,
                                 String registrationReview, boolean registrationReviewLocked) {
    }

    record ManagedEventOption(Long eventId, String name, String publicationStatus, String holdingStatus,
                              boolean unitOpen) {
    }
}
