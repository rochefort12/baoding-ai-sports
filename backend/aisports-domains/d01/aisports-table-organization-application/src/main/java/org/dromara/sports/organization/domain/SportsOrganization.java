package org.dromara.sports.organization.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;

/**
 * 通过后才存在的承办组织。主体类型和摘要本期不填。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_organization")
public class SportsOrganization extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private String name;

    private String subjectType;

    private String subjectHash;

    private String status;

    private String contactCipher;

    private Long currentQualificationId;

    @Version
    private Integer version;
}
