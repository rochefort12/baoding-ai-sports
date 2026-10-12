package org.dromara.sports.event.domain;

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
 * 发给某个平台账号的一条业务通知。已读时间留在本行。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_notification", autoResultMap = true)
public class SportsNotification extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long recipientAccountId;

    private String businessType;

    private Long businessId;

    private Integer businessRevision;

    private String purpose;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String content;

    private String dedupeKey;

    private OffsetDateTime readAt;

    @Version
    private Integer version;
}
