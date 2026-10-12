package org.dromara.sports.registration.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;

/**
 * 一个竞赛单元一条 entry 容量。used_count 只做上限，排队在通用锁里。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_capacity_pool")
public class SportsCapacityPool extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long eventId;

    private Long unitId;

    private String capacityUnit;

    private String dedupeScope;

    private Integer limitCount;

    private Integer usedCount;

    private String status;

    @Version
    private Integer version;
}
