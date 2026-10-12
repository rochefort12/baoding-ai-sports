package org.dromara.sports.finance.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.dromara.sports.finance.domain.BillingEvent;

public interface BillingEventMapper extends BaseMapper<BillingEvent> {
    /** 与首笔正式报名锁定赛事的 UPDATE 串行，避免配置与提交快照交错。租户拦截器仍生效。 */
    @org.apache.ibatis.annotations.Select("SELECT id, tenant_id, organization_id, name, publication_status, holding_status, registration_review_locked, published_revision, ends_at FROM asp_event WHERE id = #{eventId} FOR UPDATE")
    BillingEvent lock(@org.apache.ibatis.annotations.Param("eventId") Long eventId);

    /** 空草稿检查覆盖整个赛事；阶段存在即覆盖其外键绑定的场次和结果历史。 */
    @org.apache.ibatis.annotations.Select("""
        SELECT EXISTS (SELECT 1 FROM asp_event_command c
            WHERE c.tenant_id = #{tenantId} AND c.event_id = #{eventId} AND c.action = 'publish')
        OR EXISTS (SELECT 1 FROM asp_registration r JOIN asp_competition_unit u ON u.id = r.unit_id
            WHERE r.tenant_id = #{tenantId} AND u.tenant_id = #{tenantId} AND u.event_id = #{eventId})
        OR EXISTS (SELECT 1 FROM asp_capacity_pool p
            WHERE p.tenant_id = #{tenantId} AND p.event_id = #{eventId} AND p.used_count <> 0)
        OR EXISTS (SELECT 1 FROM asp_fee_obligation o
            JOIN asp_fee_policy f ON f.id = o.fee_policy_id JOIN asp_competition_unit u ON u.id = f.unit_id
            WHERE o.tenant_id = #{tenantId} AND f.tenant_id = #{tenantId}
                AND u.tenant_id = #{tenantId} AND u.event_id = #{eventId})
        OR EXISTS (SELECT 1 FROM asp_checkin c
            WHERE c.tenant_id = #{tenantId} AND c.event_id = #{eventId})
        OR EXISTS (SELECT 1 FROM asp_stage s JOIN asp_competition_unit u ON u.id = s.unit_id
            WHERE s.tenant_id = #{tenantId} AND u.tenant_id = #{tenantId} AND u.event_id = #{eventId})
        """)
    boolean hasDraftBusinessHistory(@org.apache.ibatis.annotations.Param("tenantId") String tenantId,
                                   @org.apache.ibatis.annotations.Param("eventId") Long eventId);
}
