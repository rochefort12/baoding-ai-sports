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
 * 平台登录账号。后台 sys_user 只是可选登录入口，不是参赛人。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_account")
public class SportsAccount extends BaseEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private String displayName;

    /** 登录密码散列。平台登录只读这一列。 */
    private String passwordHash;

    private Long backendUserId;

    /** 本人档案。空表示尚未建档。一名账号最多一份。 */
    private Long personId;

    private String status;

    private OffsetDateTime closedAt;

    @Version
    private Integer version;
}
