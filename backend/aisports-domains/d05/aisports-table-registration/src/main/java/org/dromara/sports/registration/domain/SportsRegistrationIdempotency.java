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
 * 已有的请求去重表。建立项目用它记住第一次成功的项目，避免收费失败后重试再插一条。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_idempotency", autoResultMap = true)
public class SportsRegistrationIdempotency extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long accountId;

    private String operation;

    private String requestKey;

    private String payloadHash;

    private String status;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String resultReference;

    private OffsetDateTime expiresAt;

    @Version
    private Integer version;
}
