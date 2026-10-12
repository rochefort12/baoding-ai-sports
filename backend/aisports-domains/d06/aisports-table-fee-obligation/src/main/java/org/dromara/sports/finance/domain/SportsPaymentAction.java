package org.dromara.sports.finance.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;

/**
 * 已付款报名失效后的后续。平台不发起退款。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_payment_action")
public class SportsPaymentAction extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long paymentId;

    private Long obligationId;

    private String status;

    private String note;

    @Version
    private Integer version;
}
