package org.dromara.sports.registration.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.tenant.core.TenantEntity;
import java.time.OffsetDateTime;

/** 可选私有凭证，只引用一次提交的义务，不作为实际收款事实。 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_registration_payment_proof")
public class SportsRegistrationPaymentProof extends TenantEntity {
    @TableId private Long id;
    private Long registrationId;
    private Long obligationId;
    private Long uploadedByAccountId;
    private Long fileId;
    private String requestKey;
    private String contentDigest;
    private OffsetDateTime uploadedAt;
    @Version private Integer version;
}
