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
 * 金额不符或第二笔真实付款。不自动结清。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_payment_exception")
public class SportsPaymentException extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long paymentId;

    private Long obligationId;

    private String exceptionType;

    private String externalReference;

    private BigDecimal reportedAmount;

    private String status;

    @Version
    private Integer version;
}
