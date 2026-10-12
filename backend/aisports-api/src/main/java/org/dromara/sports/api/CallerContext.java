package org.dromara.sports.api;

/**
 * 由服务端认证上下文构造的调用身份；不得直接信任客户端提交的同名字段。
 *
 * @param tenantId 当前处理业务的租户
 * @param accountId 公众账号，不等同于后台 sys_user.user_id
 * @param traceId 请求或任务链路标识
 */
public record CallerContext(String tenantId, Long accountId, String traceId) {
    public CallerContext {
        if (tenantId == null || tenantId.isBlank() || accountId == null || traceId == null || traceId.isBlank()) {
            throw new IllegalArgumentException("完整调用身份不能为空");
        }
    }
}
