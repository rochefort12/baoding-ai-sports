package org.dromara.sports.registration.domain;

import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.mybatis.handler.JsonbTypeHandler;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;

/**
 * 组织自己的采集字段。停用代替删除；被赛事选用后不能改类型和选项。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_org_field", autoResultMap = true)
public class SportsOrgField extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long organizationId;

    private String code;

    private String label;

    private String valueType;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String options;

    private String status;

    @Version
    private Integer version;
}
