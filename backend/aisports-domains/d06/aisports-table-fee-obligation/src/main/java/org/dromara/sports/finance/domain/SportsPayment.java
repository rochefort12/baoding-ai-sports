package org.dromara.sports.finance.domain;

import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.mybatis.handler.JsonbTypeHandler;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

/**
 * 已确认的到账。冲正表示确认错了，不表示退款。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_payment", autoResultMap = true)
public class SportsPayment extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long payerAccountId;

    private String payerName;

    private String payerPresence;

    private String paymentMode;

    private String confirmationSource;

    private String payeeSubject;

    private String transactionId;

    private BigDecimal amount;

    private String currency;

    private String status;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String evidence;

    private OffsetDateTime occurredAt;

    private OffsetDateTime confirmedAt;

    private String requestKey;

    @Version
    private Integer version;
}
