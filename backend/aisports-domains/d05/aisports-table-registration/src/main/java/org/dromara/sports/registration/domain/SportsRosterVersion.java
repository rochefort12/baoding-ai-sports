package org.dromara.sports.registration.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;
import java.time.OffsetDateTime;

/**
 * 提交成功时冻结的名单版本。本期不挂规则版本。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_roster_version")
public class SportsRosterVersion extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long registrationId;

    private Integer revision;

    private Long ruleVersionId;

    private String status;

    private OffsetDateTime effectiveAt;

    private String changeReason;

    @Version
    private Integer version;
}
