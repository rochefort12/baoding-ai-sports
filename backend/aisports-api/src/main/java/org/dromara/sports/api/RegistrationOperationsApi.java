package org.dromara.sports.api;

import java.time.LocalDate;
import java.util.List;

/** 组织运营只读统计契约。仅整单计数，不返回成员档案、手机号或资金明细。 */
public interface RegistrationOperationsApi {
    /** 调用时重新验证当前组织对赛事的办理权限。 */
    Summary summarize(Long eventId);

    record DailyCount(LocalDate date, long count) { }
    record Summary(long currentEntries, long pendingReview, long unpaidEntries, long declaredEntries,
                   long pendingFunds, long occupied, long capacity, List<DailyCount> trend) { }
}
