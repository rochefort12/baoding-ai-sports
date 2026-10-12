package org.dromara.sports.event.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;

/**
 * 一次已经生效的发布请求。重复的键不再次改变发布状态。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_event_command")
public class SportsEventCommand extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long eventId;

    private String action;

    private String requestKey;

    @Version
    private Integer version;
}
