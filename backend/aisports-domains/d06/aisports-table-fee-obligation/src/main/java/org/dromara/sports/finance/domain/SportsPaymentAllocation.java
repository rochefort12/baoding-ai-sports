package org.dromara.sports.finance.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;
import java.math.BigDecimal;

/**
 * 一笔确认付款对应一条义务。一期只做全额。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_payment_allocation")
public class SportsPaymentAllocation extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long paymentId;

    private Long obligationId;

    private Long shareId;

    private BigDecimal amount;

    private String status;

    private String requestKey;

    @Version
    private Integer version;
}
