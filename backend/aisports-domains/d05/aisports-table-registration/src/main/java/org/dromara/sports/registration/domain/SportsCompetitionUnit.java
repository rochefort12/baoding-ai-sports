package org.dromara.sports.registration.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;

/**
 * 竞赛单元。报名窗口不在这里，名额在容量池。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_competition_unit")
public class SportsCompetitionUnit extends TenantEntity {
    private Long competitionTypeId;

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long eventId;

    private Long sportId;

    private String name;

    private String entryType;

    private Integer minMembers;

    private Integer maxMembers;

    private String status;

    @Version
    private Integer version;
}
