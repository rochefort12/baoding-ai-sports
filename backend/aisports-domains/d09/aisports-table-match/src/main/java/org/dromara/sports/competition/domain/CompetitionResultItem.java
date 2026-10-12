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

/** 一侧的胜负记录。不根据比分推断是否合法。 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_result_item", autoResultMap = true)
public class CompetitionResultItem extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long resultVersionId;

    private Long matchEntryId;

    private String performanceStatus;

    private String unit;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String components;

    @Version
    private Integer version;
}
