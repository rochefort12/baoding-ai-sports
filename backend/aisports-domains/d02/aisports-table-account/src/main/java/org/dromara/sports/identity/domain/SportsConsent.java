package org.dromara.sports.identity.domain;

import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.mybatis.core.domain.BaseEntity;
import org.dromara.common.mybatis.handler.JsonbTypeHandler;

import java.io.Serial;
import java.time.OffsetDateTime;

/**
 * 一次具体行为的同意。一条记录只覆盖一个用途。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_consent", autoResultMap = true)
public class SportsConsent extends BaseEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long personId;

    private Long actorAccountId;

    private String purpose;

    private String documentVersion;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String scope;

    private OffsetDateTime acceptedAt;

    private OffsetDateTime revokedAt;

    private String evidenceHash;

    @Version
    private Integer version;
}
