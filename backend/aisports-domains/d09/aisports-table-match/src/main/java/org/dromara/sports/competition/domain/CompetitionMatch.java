package org.dromara.sports.competition.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;
import java.time.OffsetDateTime;

/** 手工场次。阶段只是内部挂靠，不表示淘汰赛或小组赛。 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_match")
public class CompetitionMatch extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long stageId;

    private String code;

    private Integer roundNumber;

    private String status;

    /** 原场次排期；只对首次正式确认增加时间前置，不改既有结果历史。 */
    private OffsetDateTime scheduledStart;

    @Version
    private Integer version;
}
