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
 * 每次提交冻结的一版。审核只改这一版的状态和理由，不改已经提交的内容。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_organization_application_version", autoResultMap = true)
public class SportsOrganizationApplicationVersion extends BaseEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long applicationId;

    private Integer revision;

    private String name;

    private String contactName;

    private String contactCipher;

    private String statement;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String fileIds;

    private String status;

    private Long reviewerId;

    private String reviewReason;

    @Version
    private Integer version;
}
