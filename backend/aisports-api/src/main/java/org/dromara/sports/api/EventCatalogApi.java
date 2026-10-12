package org.dromara.sports.api;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

/**
 * 赛事公开页和报名所需的单元快照。公开结果不包含联系电话、证件和成绩。
 */
public interface EventCatalogApi {

    List<PublicEventView> listPublic();

    Optional<PublicEventView> findPublic(Long eventId);

    Optional<UnitRegistrationContext> findOpenUnit(Long unitId);

    record PublicUnitView(Long unitId, String name, String entryType, String sportName, String feeMode) {
    }

    record PublicEventView(Long eventId, String name, String organizationName, String place,
                            OffsetDateTime startsAt, OffsetDateTime endsAt,
                            OffsetDateTime registrationOpensAt, OffsetDateTime registrationClosesAt,
                            String registrationStatus, List<PublicUnitView> units) {
    }

    record UnitRegistrationContext(String tenantId, Long eventId, Long organizationId, Long unitId,
                                   String entryType, int minMembers, int maxMembers,
                                   Long ruleVersionId, Long feePolicyId, String feeMode,
                                   BigDecimal amount, String payee, Long unitPoolId,
                                   Long eventPersonPoolId, boolean registrationOpen) {
    }
}
