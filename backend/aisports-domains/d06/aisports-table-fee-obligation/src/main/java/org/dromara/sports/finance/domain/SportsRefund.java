package org.dromara.sports.finance.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

/**
 * 承办方已经在平台外退过的款。原付款仍然保留。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_refund")
public class SportsRefund extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long paymentId;

    private BigDecimal requestedAmount;

    private BigDecimal approvedAmount;

    private BigDecimal completedAmount;

    private String status;

    private String reason;

    /** 实际接收人；与原付款人不同须有核验授权依据。 */
    private String recipientName;
    private String recipientBasis;

    private String requestKey;

    private OffsetDateTime completedAt;

    @Version
    private Integer version;
}
