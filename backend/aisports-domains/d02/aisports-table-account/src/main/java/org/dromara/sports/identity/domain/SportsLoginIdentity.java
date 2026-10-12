package org.dromara.sports.identity.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.mybatis.core.domain.BaseEntity;

import java.io.Serial;
import java.time.OffsetDateTime;

/**
 * 已验证的登录渠道。未通过验证的手机号不写入本表。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_login_identity")
public class SportsLoginIdentity extends BaseEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long accountId;

    private String channel;

    private String subjectHash;

    private String subjectCipher;

    private OffsetDateTime validFrom;

    private OffsetDateTime validUntil;

    private String verificationSource;

    @Version
    private Integer version;
}
