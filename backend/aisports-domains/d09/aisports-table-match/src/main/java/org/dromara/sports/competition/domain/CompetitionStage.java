package org.dromara.sports.competition.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;

/**
 * 手工场次挂靠的内部阶段。format 为 SYSTEM_MANUAL，没有规则版本。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_stage")
public class CompetitionStage extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long unitId;

    private Long ruleVersionId;

    private String name;

    private String format;

    private Integer sequence;

    private String status;

    @Version
    private Integer version;
}
