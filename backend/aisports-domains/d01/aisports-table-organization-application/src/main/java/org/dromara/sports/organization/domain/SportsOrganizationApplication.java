package org.dromara.sports.organization.domain;

import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.mybatis.core.domain.BaseEntity;
import org.dromara.common.mybatis.handler.JsonbTypeHandler;

import java.io.Serial;

/**
 * 平台级办赛申请。没有业务租户，一个人本期只有一份。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_organization_application", autoResultMap = true)
public class SportsOrganizationApplication extends BaseEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long applicantAccountId;
    private Long assignedReviewerId;

    private String status;

    private String name;

    private String contactName;

    private String contactCipher;

    private String statement;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String fileIds;

    private Long organizationId;

    private String organizationTenantId;

    @Version
    private Integer version;
}
