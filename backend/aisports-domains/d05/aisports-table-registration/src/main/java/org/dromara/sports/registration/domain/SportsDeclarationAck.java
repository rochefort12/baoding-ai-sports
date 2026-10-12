package org.dromara.sports.registration.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;
import java.time.OffsetDateTime;

/** 成员本人点击确认当时的参赛声明。 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_declaration_ack")
public class SportsDeclarationAck extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long registrationMemberId;

    private Long accountId;

    private Long eventId;

    private String contentDigest;

    private OffsetDateTime acknowledgedAt;

    @Version
    private Integer version;
}
