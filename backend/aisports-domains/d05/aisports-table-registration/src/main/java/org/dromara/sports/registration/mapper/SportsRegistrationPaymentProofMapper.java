package org.dromara.sports.registration.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.dromara.sports.registration.domain.SportsRegistrationPaymentProof;

/** 凭证按报名和付款义务隔离；不可用文件编号代替授权。 */
public interface SportsRegistrationPaymentProofMapper extends BaseMapper<SportsRegistrationPaymentProof> { }
