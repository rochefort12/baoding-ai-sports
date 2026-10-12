package org.dromara.sports.identity.mapper;

import com.baomidou.mybatisplus.annotation.InterceptorIgnore;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.dromara.sports.identity.domain.SportsProfileTrace;

/**
 * 档案痕迹写在平台参赛者租户。平台管理员的会话在另一个租户，
 * 按会话租户过滤会把这些记录全部挡住。查询和写入都按行上的租户编号，不按当前会话租户。
 */
@InterceptorIgnore(tenantLine = "true")
public interface SportsProfileTraceMapper extends BaseMapper<SportsProfileTrace> {
}
