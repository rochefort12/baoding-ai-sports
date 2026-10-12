package org.dromara.sports.team.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.mybatis.core.domain.BaseEntity;

import java.io.Serial;
import java.time.OffsetDateTime;

/**
 * 一段成员关系。结束后不改回有效，再次加入另起一行。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_team_member")
public class SportsTeamMember extends BaseEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long teamId;

    private Long personId;

    private String role;

    private String status;

    private String endReason;

    private String joinSource;

    private OffsetDateTime joinedAt;

    private OffsetDateTime leftAt;

    @Version
    private Integer version;
}
