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

/** 按赛事项目记录实际到场；旧赛事级记录的项目未知，保留为空等待核对。 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_checkin", autoResultMap = true)
public class CompetitionCheckin extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long eventId;

    private Long unitId;

    private Long personId;

    private Long matchId;

    private String checkType;

    private String status;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String verification;

    private OffsetDateTime occurredAt;

    private String requestKey;

    @Version
    private Integer version;
}
