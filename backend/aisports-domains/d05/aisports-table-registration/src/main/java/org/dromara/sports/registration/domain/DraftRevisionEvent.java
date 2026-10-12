package org.dromara.sports.registration.domain;

import lombok.Data;

/** 草稿项目同步动作私有的赛事行锁投影，不引用赛事表工程实体。 */
@Data
public class DraftRevisionEvent {
    private Long id;
    private String tenantId;
    private Long organizationId;
    private String publicationStatus;
    private String holdingStatus;
    private Boolean registrationReviewLocked;
    private Integer publishedRevision;
    private java.time.OffsetDateTime endsAt;
}
