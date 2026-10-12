package org.dromara.sports.competition.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;

/** 请求键幂等。相同键不同内容是冲突，不能当成新的修改。 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_execution_command")
public class ExecutionCommand extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private String action;

    private String requestKey;

    private String payloadHash;

    private String subjectType;

    private Long subjectId;

    @Version
    private Integer version;
}
