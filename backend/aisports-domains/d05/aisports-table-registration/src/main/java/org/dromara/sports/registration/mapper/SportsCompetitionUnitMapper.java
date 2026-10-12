package org.dromara.sports.registration.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.dromara.sports.registration.domain.SportsCompetitionUnit;
import org.dromara.sports.registration.domain.DraftRevisionEvent;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

public interface SportsCompetitionUnitMapper extends BaseMapper<SportsCompetitionUnit> {

    /** 本动作先锁赛事，和发布、首次报名、价格修改共用同一数据库锁。 */
    @Select("""
        SELECT id, tenant_id, organization_id, publication_status, holding_status, registration_review_locked, published_revision, ends_at
        FROM asp_event WHERE id = #{eventId} AND tenant_id = #{tenantId} FOR UPDATE
        """)
    DraftRevisionEvent lockDraftEvent(@Param("tenantId") String tenantId, @Param("eventId") Long eventId);

    /** 任意状态的报名、历史义务、占用和曾发布均拒绝，收费配置本身不是付款历史。 */
    @Select("""
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
    boolean hasDraftBusinessHistory(@Param("tenantId") String tenantId, @Param("eventId") Long eventId);
}
