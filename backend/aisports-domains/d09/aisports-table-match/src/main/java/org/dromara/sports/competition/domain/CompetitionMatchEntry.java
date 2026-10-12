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

/** 场次的一侧。引用已通过的报名，不引用当前队员。 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_match_entry", autoResultMap = true)
public class CompetitionMatchEntry extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long matchId;

    private Long registrationId;

    private Long rosterVersionId;

    private String slot;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String qualificationSource;

    private String status;

    @Version
    private Integer version;
}
