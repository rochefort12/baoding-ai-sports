package org.dromara.sports.competition.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.io.Serial;
import java.io.Serializable;
import java.time.OffsetDateTime;

/** 录分页只读赛事名称和组织归属。 */
@Data
@TableName("asp_event")
public class CompetitionEvent implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private String tenantId;

    private Long organizationId;

    private String name;

    private String holdingStatus;

    /** 首次正式赛果及新赛事荣誉不得早于已公告开赛时间。 */
    private OffsetDateTime startsAt;

    /** 新增报到、建场的结束时间门禁；不限制已有场次赛果整理。 */
    private OffsetDateTime endsAt;
}
