package org.dromara.sports.organization.domain;

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
 * 进入组织的权威。不保存后台用户号。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_staff_grant", autoResultMap = true)
public class SportsStaffGrant extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long organizationId;

    private Long accountId;

    private Long eventId;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String permissions;

    private String status;

    private OffsetDateTime validFrom;

    private OffsetDateTime validUntil;

    @Version
    private Integer version;
}
