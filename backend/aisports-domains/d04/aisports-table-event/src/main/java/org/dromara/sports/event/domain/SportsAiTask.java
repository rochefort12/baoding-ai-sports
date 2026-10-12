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

/**
 * 通用 AI 任务。确认前不代表赛事已经建立。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_ai_task", autoResultMap = true)
public class SportsAiTask extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private String scene;

    private String businessObject;

    private Long organizationId;

    private Long initiatorAccountId;

    private String status;

    private Boolean bailianConsent;
    private Boolean providerConsent;
    private String providerName;
    private String consentVersion;

    @TableField(typeHandler = JsonbTypeHandler.class, updateStrategy = FieldStrategy.ALWAYS)
    private String extraction;

    @TableField(typeHandler = JsonbTypeHandler.class, updateStrategy = FieldStrategy.ALWAYS)
    private String proposal;

    @TableField(updateStrategy = FieldStrategy.ALWAYS)
    private String errorCode;

    @TableField(updateStrategy = FieldStrategy.ALWAYS)
    private String errorMessage;

    private Integer attemptCount;

    @TableField(updateStrategy = FieldStrategy.ALWAYS)
    private Long resultObjectId;

    @TableField(updateStrategy = FieldStrategy.ALWAYS)
    private String confirmKey;

    @Version
    private Integer version;
}
