package org.dromara.sports.identity.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.mybatis.core.domain.BaseEntity;

import java.io.Serial;
import java.time.LocalDate;

/**
 * 现实参赛人。同名不合并，身份摘要不替代证件。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_person")
public class SportsPerson extends BaseEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private String legalName;

    private String displayName;

    private LocalDate birthDate;

    private String gender;

    private String mobile;

    private String idDocType;

    private String identityHash;

    private String identityCipher;

    private String city;

    private String addressDetail;

    private String bloodType;

    private String clothingSize;

    private String emergencyContactName;

    private String emergencyContactPhone;

    private String verificationStatus;

    private String status;

    private Long mergedIntoId;

    @Version
    private Integer version;
}
