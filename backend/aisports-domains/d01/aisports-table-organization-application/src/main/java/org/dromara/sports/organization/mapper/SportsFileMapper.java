package org.dromara.sports.organization.mapper;

import com.baomidou.mybatisplus.annotation.InterceptorIgnore;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.dromara.sports.organization.domain.SportsFile;

/**
 * asp_file 用 owning_tenant_id 表示归属，没有框架租户列。按会话租户拼接 SQL 会对不上表。
 */
@InterceptorIgnore(tenantLine = "true")
public interface SportsFileMapper extends BaseMapper<SportsFile> {
}
