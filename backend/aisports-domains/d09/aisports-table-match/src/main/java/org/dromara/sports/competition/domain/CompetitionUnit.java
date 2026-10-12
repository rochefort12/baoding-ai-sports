package org.dromara.sports.competition.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.io.Serial;
import java.io.Serializable;

/** 录分页只读竞赛单元名称。 */
@Data
@TableName("asp_competition_unit")
public class CompetitionUnit implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private String tenantId;

    private Long eventId;

    private String name;
}
