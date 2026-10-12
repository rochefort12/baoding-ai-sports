package org.dromara.sports.identity.domain;

import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.mybatis.core.domain.BaseEntity;
import org.dromara.common.mybatis.handler.JsonbTypeHandler;

import java.io.Serial;
import java.time.OffsetDateTime;

/**
 * 档案修改和反馈的最小痕迹。摘要不保存证件号码或密码。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_audit_event", autoResultMap = true)
public class SportsProfileTrace extends BaseEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private String tenantId;

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
