package org.dromara.sports.team.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.mybatis.core.domain.BaseEntity;

import java.io.Serial;

/**
 * 入队申请。待处理不是成员。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_team_join_request")
public class SportsTeamJoinRequest extends BaseEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long teamId;

    private Long personId;

    private String status;

    private Long reviewerAccountId;

    private String reason;

    @Version
    private Integer version;
}
