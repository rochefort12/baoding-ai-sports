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
 * 成员确认。提交成功后才把快照抄进名单。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_registration_member", autoResultMap = true)
public class SportsRegistrationMember extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long registrationId;

    private Long unitId;

    private Long accountId;

    private Long personId;

    private String status;

    private Boolean selfMember;

    private String inviteToken;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String personSnapshot;

    private Boolean occupying;

    @Version
    private Integer version;
}
