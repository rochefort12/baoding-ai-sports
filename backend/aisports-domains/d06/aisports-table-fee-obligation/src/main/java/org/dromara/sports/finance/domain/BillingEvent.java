package org.dromara.sports.finance.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.io.Serial;
import java.io.Serializable;

/**
 * 收费页用来显示赛事名称。
 */
@Data
@TableName("asp_event")
public class BillingEvent implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private String tenantId;

    private Long organizationId;

    private String name;
    private String publicationStatus;
    private String holdingStatus;
    private Boolean registrationReviewLocked;
    private Integer publishedRevision;
    private java.time.OffsetDateTime endsAt;
}
