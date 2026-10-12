package org.dromara.sports.api;

import java.time.Instant;
import java.util.List;
import java.util.Set;

/**
 * 跨组织日历只返回受限冲突结论，不能公开对方赛事、人员或材料。
 * 实现应合并确定与潜在约束、识别父子事件及整体/半场资源，并核验 caller 对输入对象的权限。
 */
public interface TimeConflictApi {
    ConflictResult check(CallerContext caller, ConflictQuery query);

    /** sourceReference 是当前操作的可信关联号，用于排除本操作已有占用，不是任意排除 ID。 */
    record ConflictQuery(Set<Long> personIds, Set<Long> resourceIds, Instant startsAt,
                         Instant endsAt, String sourceReference) {
        public ConflictQuery {
            personIds = Set.copyOf(personIds);
            resourceIds = Set.copyOf(resourceIds);
            if (startsAt == null || endsAt == null || !endsAt.isAfter(startsAt)) {
                throw new IllegalArgumentException("时间窗口必须为正长度");
            }
        }
    }

    enum Reason { PERSON_BUSY, RESOURCE_BUSY, POTENTIAL_ADVANCEMENT, NEEDS_VERIFICATION }

    /** 无第三方身份、赛事名称或约束原始行；具体解释由当前业务授权范围决定。 */
    record ConflictResult(boolean blocked, List<Reason> reasons) {
        public ConflictResult { reasons = List.copyOf(reasons); }
    }
}
