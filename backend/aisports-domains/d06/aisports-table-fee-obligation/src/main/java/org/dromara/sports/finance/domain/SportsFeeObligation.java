package org.dromara.sports.finance.domain;

import com.baomidou.mybatisplus.annotation.FieldStrategy;
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
 * 一次正式提交产生的义务。再次提交另起一行。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_fee_obligation", autoResultMap = true)
public class SportsFeeObligation extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long registrationId;

    private Long feePolicyId;

    private BigDecimal totalAmount;

    private String currency;

    private String status;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String quoteSnapshot;

    private String requestKey;

    /**
     * 参赛者点击模拟付款完成的时间。到账仍要组织方确认。
     * 冲正后义务回到待付款时要把这一列写回空，全局更新策略会丢掉 null。
     */
    @TableField(updateStrategy = FieldStrategy.ALWAYS)
    private OffsetDateTime declaredAt;

    @Version
    private Integer version;
}
