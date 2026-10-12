package org.dromara.sports.finance.domain;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.mybatis.handler.JsonbTypeHandler;
import org.dromara.common.tenant.core.TenantEntity;

/** 赛事统一收款指引，仅资金授权可维护。提交报名时复制到应付义务，不把指引当到账。 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_event_payment_config", autoResultMap = true)
public class SportsEventPaymentConfig extends TenantEntity {
    @TableId private Long id;
    private Long eventId;
    @TableField(typeHandler = JsonbTypeHandler.class) private String settings;
    @Version private Integer version;
}
