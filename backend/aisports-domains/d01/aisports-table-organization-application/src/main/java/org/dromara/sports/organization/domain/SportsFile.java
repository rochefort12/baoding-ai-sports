package org.dromara.sports.organization.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.mybatis.core.domain.BaseEntity;

import java.io.Serial;

/**
 * 共享文件元数据。办赛附件在通过前没有归属租户。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_file")
public class SportsFile extends BaseEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long ownerAccountId;

    private String owningTenantId;

    private String objectKey;

    private String sha256;

    private String purpose;

    private String sensitivity;

    private String status;

    @Version
    private Integer version;
}
