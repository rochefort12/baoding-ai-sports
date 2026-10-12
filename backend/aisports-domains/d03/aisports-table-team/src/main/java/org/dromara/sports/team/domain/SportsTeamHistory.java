package org.dromara.sports.team.domain;

import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.mybatis.core.domain.BaseEntity;
import org.dromara.common.mybatis.handler.JsonbTypeHandler;

import java.io.Serial;
import java.time.OffsetDateTime;

/**
 * 队名、队长和解散的快照。不代替成员终止行，也不回写报名。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_team_history", autoResultMap = true)
public class SportsTeamHistory extends BaseEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long teamId;

    private String action;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String beforeSnapshot;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String afterSnapshot;

    private String reason;

    private OffsetDateTime effectiveAt;

    @Version
    private Integer version;
}
