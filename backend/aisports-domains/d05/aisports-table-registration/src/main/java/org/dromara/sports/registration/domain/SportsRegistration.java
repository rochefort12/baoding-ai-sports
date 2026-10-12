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
 * 报名。编号就是后续费用和场次引用的 registration id。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_registration")
public class SportsRegistration extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long unitId;

    private Long ruleVersionId;

    /** 最近一次提交使用的收费版本。历史义务另记在义务行上。 */
    private Long feePolicyId;

    /** 空表示个人或临时双打。有值时办理权看当前队长。 */
    private Long teamId;

    /** 提交成功时的队名。草稿阶段不作为历史展示。 */
    private String teamNameSnapshot;

    private Long submitterAccountId;

    /** Stable responsible account; review operators and current team captains do not replace it. */
    private Long managerAccountId;

    private Long operatorAccountId;

    private String requestKey;

    private String status;

    private Integer rosterRevision;

    private OffsetDateTime submittedAt;

    @Version
    private Integer version;
}
