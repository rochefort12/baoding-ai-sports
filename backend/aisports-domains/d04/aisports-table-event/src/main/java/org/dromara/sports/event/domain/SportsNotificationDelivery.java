package org.dromara.sports.event.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;
import java.time.OffsetDateTime;

/**
 * 一条通知在某个渠道上的投递结果。站内信送达不等于短信送达。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_notification_delivery")
public class SportsNotificationDelivery extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long notificationId;

    private String channel;

    private Integer attempt;

    private String status;

    private OffsetDateTime deliveredAt;

    private String failureReason;

    @Version
    private Integer version;
}
