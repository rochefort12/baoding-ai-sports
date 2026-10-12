package org.dromara.sports.organization.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.mybatis.core.domain.BaseEntity;

import java.io.Serial;

/**
 * 平台账号在某个组织租户里的后台用户。有这一行也不能代替成员授权。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_account_tenant_principal")
public class SportsAccountTenantPrincipal extends BaseEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long accountId;

    /**
     * 组织租户编号。这是业务列，不是租户拦截器追加的条件。
     */
    private String tenantId;

    private Long sysUserId;

    private String status;

    @Version
    private Integer version;
}
