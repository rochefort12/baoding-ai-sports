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

/**
 * 个人证明投影。同一 award_key 的多行属于同一条报名获奖事实。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_honor", autoResultMap = true)
public class CompetitionHonor extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long eventId;

    private Long registrationId;

    private Long personId;

    private Long teamId;

    private String awardKey;

    private String category;

    private String title;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String source;

    private String status;

    private OffsetDateTime awardedAt;

    @Version
    private Integer version;
}
