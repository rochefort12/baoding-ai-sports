package org.dromara.sports.event.domain;

import com.baomidou.mybatisplus.annotation.FieldStrategy;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.mybatis.handler.JsonbTypeHandler;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;
import java.time.OffsetDateTime;

/**
 * 赛事。公开与否看 publicationStatus，不看 visibility 或旧的 status。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_event", autoResultMap = true)
public class SportsEvent extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long organizationId;

    private String name;

    private Long seriesId;

    private OffsetDateTime startsAt;

    private OffsetDateTime endsAt;

    private OffsetDateTime registrationOpensAt;

    private OffsetDateTime registrationClosesAt;

    private String location;

    private String projectName;

    private String feeDescription;

    /** 可空。更新策略保留清空。 */
    @TableField(updateStrategy = FieldStrategy.ALWAYS)
    private Long bannerFileId;

    @TableField(updateStrategy = FieldStrategy.ALWAYS)
    private String rulesText;

    @TableField(updateStrategy = FieldStrategy.ALWAYS)
    private Long rulesFileId;

    @TableField(updateStrategy = FieldStrategy.ALWAYS)
    private String noticeText;

    @TableField(updateStrategy = FieldStrategy.ALWAYS)
    private Long noticeFileId;

    @TableField(updateStrategy = FieldStrategy.ALWAYS)
    private String declarationText;

    @TableField(updateStrategy = FieldStrategy.ALWAYS)
    private Long declarationFileId;

    /** 为 true 时，有声明内容的成员必须本人点击确认。 */
    private Boolean declarationAckRequired;

    @TableField(updateStrategy = FieldStrategy.ALWAYS)
    private String routeText;

    @TableField(updateStrategy = FieldStrategy.ALWAYS)
    private Long routeFileId;

    private String cancelReason;

    private String sportCode;

    private String publicationStatus;

    private String holdingStatus;
    private String closureStatus;

    /** manual 人工审核，none 无需审核。 */
    private String registrationReview;

    /** 首笔正式提交后为 true。 */
    private Boolean registrationReviewLocked;

    /** 后继生命周期。本期写入 draft，不拿它判断公开。 */
    private String status;

    private String registrationStatus;

    private String paymentStatus;

    private String visibility;

    private Integer publishedRevision;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String contactSnapshot;

    @Version
    private Integer version;
}
