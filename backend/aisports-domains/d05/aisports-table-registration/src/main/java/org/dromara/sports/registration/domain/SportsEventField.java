package org.dromara.sports.registration.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;

/**
 * 一场赛事选用的组织字段。首笔正式提交后整套不再改。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_event_field")
public class SportsEventField extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long eventId;

    private Long orgFieldId;

    private Boolean required;

    private Integer sortOrder;

    private String note;

    @Version
    private Integer version;
}
