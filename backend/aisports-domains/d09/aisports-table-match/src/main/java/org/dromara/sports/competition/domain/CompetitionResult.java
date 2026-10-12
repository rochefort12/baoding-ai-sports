package org.dromara.sports.competition.domain;

import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.mybatis.handler.JsonbTypeHandler;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;
import java.time.OffsetDateTime;

/** 一场一条结果。draft 可改，confirmed 本期不可改。 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_result_version", autoResultMap = true)
public class CompetitionResult extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long matchId;

    private Integer revision;

    private Long previousId;

    private String status;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String rawPerformance;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String decision;

    private Long confirmerId;

    private OffsetDateTime confirmedAt;

    @Version
    private Integer version;
}
