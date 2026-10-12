package org.dromara.sports.registration.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;

/**
 * 已经完成的一次提交。撤回后重放同一请求键时用它挡住再次占用。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_registration_submit_key")
public class SportsRegistrationSubmitKey extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long registrationId;

    private Long submitterAccountId;

    private String requestKey;

    private Integer rosterRevision;

    @Version
    private Integer version;
}
