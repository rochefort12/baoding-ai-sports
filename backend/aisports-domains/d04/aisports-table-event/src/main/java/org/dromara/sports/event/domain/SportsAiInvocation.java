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

/**
 * 一次模型或工具调用。摘要里不放资料正文。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_ai_invocation", autoResultMap = true)
public class SportsAiInvocation extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long taskId;

    private String kind;

    private String toolName;

    private String modelName;

    private String status;

    private Integer attemptNo;

    private String errorCode;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String summary;

    @Version
    private Integer version;
}
