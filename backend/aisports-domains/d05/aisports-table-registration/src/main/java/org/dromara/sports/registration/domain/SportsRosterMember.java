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
 * 名单成员快照。审核整单时不逐个改这份快照里的档案。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_roster_member", autoResultMap = true)
public class SportsRosterMember extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long rosterVersionId;

    private Long personId;

    private String role;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String personSnapshot;

    private String qualificationStatus;

    private Integer position;

    @Version
    private Integer version;
}
