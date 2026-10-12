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
import java.time.OffsetDateTime;

/**
 * 整单审核。roster_member_id 留空，表示不是逐个成员审核。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_qualification_review", autoResultMap = true)
public class SportsQualificationReview extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long registrationId;

    private Long rosterMemberId;

    private String decision;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String basis;

    private Long reviewerId;

    private OffsetDateTime reviewedAt;

    private String reason;

    @Version
    private Integer version;
}
