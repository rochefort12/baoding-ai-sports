package org.dromara.sports.registration.domain;

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
 * 名额调整留下的业务痕迹。摘要只记新旧上限，不记个人材料。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_audit_event", autoResultMap = true)
public class SportsAuditEvent extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long actorAccountId;

    private String action;

    private String objectType;

    private Long objectId;

    private String requestId;

    private OffsetDateTime occurredAt;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String summary;

    @Version
    private Integer version;
}
