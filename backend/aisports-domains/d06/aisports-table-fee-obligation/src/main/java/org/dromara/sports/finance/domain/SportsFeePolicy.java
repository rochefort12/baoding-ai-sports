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

/**
 * 竞赛单元的一版收费。生效后不改金额和收款方式。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_fee_policy", autoResultMap = true)
public class SportsFeePolicy extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long unitId;

    private Integer revision;

    private String pricingUnit;

    private BigDecimal amount;

    private String paymentMode;

    private String payInstruction;

    private Long qrFileId;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String pricingRules;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String payerModes;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String collectionPaths;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String refundTerms;

    private String status;

    @Version
    private Integer version;
}
