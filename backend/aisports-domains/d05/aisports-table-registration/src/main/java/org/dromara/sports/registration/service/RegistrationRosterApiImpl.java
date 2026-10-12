package org.dromara.sports.registration.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.RegistrationRosterApi;
import org.dromara.sports.registration.domain.SportsCompetitionUnit;
import org.dromara.sports.registration.domain.SportsRegistration;
import org.dromara.sports.registration.domain.SportsRosterMember;
import org.dromara.sports.registration.domain.SportsRosterVersion;
import org.dromara.sports.registration.mapper.SportsCompetitionUnitMapper;
import org.dromara.sports.registration.mapper.SportsRegistrationMapper;
import org.dromara.sports.registration.mapper.SportsRosterMemberMapper;
import org.dromara.sports.registration.mapper.SportsRosterVersionMapper;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * 只有已通过审核、名单已冻结的报名才能被后续录分引用。
 */
@Service
@RequiredArgsConstructor
public class RegistrationRosterApiImpl implements RegistrationRosterApi {

    private final SportsRegistrationMapper registrationMapper;
    private final SportsRosterVersionMapper rosterVersionMapper;
    private final SportsRosterMemberMapper rosterMemberMapper;
    private final SportsCompetitionUnitMapper unitMapper;
    private final ObjectMapper objectMapper;

    @Override
    public Optional<RosterSnapshot> findValidRoster(String tenantId, Long registrationId) {
        if (tenantId == null || tenantId.isBlank() || registrationId == null) {
            return Optional.empty();
        }
        return TenantHelper.dynamic(tenantId, () -> {
            SportsRegistration registration = registrationMapper.selectById(registrationId);
            if (registration == null || !"approved".equals(registration.getStatus()) || registration.getRosterRevision() == null) {
                return Optional.empty();
            }
            SportsRosterVersion version = rosterVersionMapper.selectOne(Wrappers.<SportsRosterVersion>lambdaQuery()
                .eq(SportsRosterVersion::getRegistrationId, registrationId)
                .eq(SportsRosterVersion::getRevision, registration.getRosterRevision())
                .eq(SportsRosterVersion::getStatus, "frozen"));
            if (version == null) {
                return Optional.empty();
            }
            SportsCompetitionUnit unit = unitMapper.selectById(registration.getUnitId());
            if (unit == null) {
                return Optional.empty();
            }
            List<Long> personIds = rosterMemberMapper.selectList(Wrappers.<SportsRosterMember>lambdaQuery()
                    .eq(SportsRosterMember::getRosterVersionId, version.getId())
                    .orderByAsc(SportsRosterMember::getPosition))
                .stream()
                .map(SportsRosterMember::getPersonId)
                .toList();
            return Optional.of(new RosterSnapshot(registration.getId(), version.getId(), unit.getId(), unit.getEventId(),
                personIds, registration.getStatus()));
        });
    }

    @Override
    public Optional<RosterView> approvedRoster(String tenantId, Long registrationId) {
        if (tenantId == null || tenantId.isBlank() || registrationId == null) {
            return Optional.empty();
        }
        return TenantHelper.dynamic(tenantId, () -> Optional.ofNullable(viewOf(registrationMapper.selectById(registrationId))));
    }

    @Override
    public List<RosterView> approvedRosters(String tenantId, Long eventId) {
        if (tenantId == null || tenantId.isBlank() || eventId == null) {
            return List.of();
        }
        return TenantHelper.dynamic(tenantId, () -> {
            List<RosterView> views = new ArrayList<>();
            for (SportsRegistration registration : registrationMapper.selectList(Wrappers.<SportsRegistration>lambdaQuery()
                .eq(SportsRegistration::getStatus, "approved"))) {
                RosterView view = viewOf(registration);
                if (view != null && eventId.equals(view.eventId())) {
                    views.add(view);
                }
            }
            return views;
        });
    }

    @Override
    public List<RosterView> approvedRostersForUnit(String tenantId, Long unitId) {
        if (tenantId == null || tenantId.isBlank() || unitId == null) {
            return List.of();
        }
        return TenantHelper.dynamic(tenantId, () -> {
            List<RosterView> views = new ArrayList<>();
            for (SportsRegistration registration : registrationMapper.selectList(Wrappers.<SportsRegistration>lambdaQuery()
                .eq(SportsRegistration::getStatus, "approved")
                .eq(SportsRegistration::getUnitId, unitId))) {
                RosterView view = viewOf(registration);
                if (view != null) {
                    views.add(view);
                }
            }
            return views;
        });
    }

    private RosterView viewOf(SportsRegistration registration) {
        if (registration == null || !"approved".equals(registration.getStatus()) || registration.getRosterRevision() == null) {
            return null;
        }
        SportsRosterVersion version = rosterVersionMapper.selectOne(Wrappers.<SportsRosterVersion>lambdaQuery()
            .eq(SportsRosterVersion::getRegistrationId, registration.getId())
            .eq(SportsRosterVersion::getRevision, registration.getRosterRevision())
            .eq(SportsRosterVersion::getStatus, "frozen"));
        if (version == null) {
            return null;
        }
        SportsCompetitionUnit unit = unitMapper.selectById(registration.getUnitId());
        if (unit == null) {
            return null;
        }
        List<RosterPerson> people = rosterMemberMapper.selectList(Wrappers.<SportsRosterMember>lambdaQuery()
                .eq(SportsRosterMember::getRosterVersionId, version.getId())
                .orderByAsc(SportsRosterMember::getPosition))
            .stream()
            .map(member -> new RosterPerson(member.getPersonId(), legalName(member.getPersonSnapshot())))
            .toList();
        return new RosterView(registration.getId(), version.getId(), unit.getId(), unit.getEventId(), unit.getName(), people);
    }

    @Override
    public List<Long> registrationIdsForPerson(Long personId) {
        if (personId == null) {
            return List.of();
        }
        return TenantHelper.ignore(() -> {
            List<SportsRosterMember> members = rosterMemberMapper.selectList(Wrappers.<SportsRosterMember>lambdaQuery()
                .eq(SportsRosterMember::getPersonId, personId));
            List<Long> ids = new ArrayList<>();
            for (SportsRosterMember member : members) {
                SportsRosterVersion version = rosterVersionMapper.selectById(member.getRosterVersionId());
                if (version != null && "frozen".equals(version.getStatus()) && !ids.contains(version.getRegistrationId())) {
                    ids.add(version.getRegistrationId());
                }
            }
            return ids;
        });
    }

    private String legalName(String snapshot) {
        if (snapshot == null || snapshot.isBlank()) {
            return "";
        }
        try {
            JsonNode name = objectMapper.readTree(snapshot).get("legalName");
            return name == null || name.isNull() ? "" : name.asText();
        } catch (Exception exception) {
            return "";
        }
    }
}
