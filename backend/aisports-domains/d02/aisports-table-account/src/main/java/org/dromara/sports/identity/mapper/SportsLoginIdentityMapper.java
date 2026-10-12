package org.dromara.sports.identity.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.dromara.sports.identity.domain.SportsLoginIdentity;

/**
 * 登录渠道。手机号判重只看尚未解绑的记录。
 */
public interface SportsLoginIdentityMapper extends BaseMapper<SportsLoginIdentity> {
}
