package org.dromara.sports.finance.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;

/**
 * 只读取报名状态，用来判断冲正后义务要不要重新打开。不改报名。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_registration")
public class BillingRegistration extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long unitId;

    private String status;
}
