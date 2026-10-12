package org.dromara.sports.team.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.mybatis.core.domain.BaseEntity;

import java.io.Serial;

/**
 * 长期队伍。平台共享，没有租户列。解散后保留这一行。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_team")
public class SportsTeam extends BaseEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private String name;

    private Long sportId;

    private Long captainPersonId;

    private Long creatorAccountId;

    private String joinPolicy;

    private String visibility;

    private String status;

    @Version
    private Integer version;
}
