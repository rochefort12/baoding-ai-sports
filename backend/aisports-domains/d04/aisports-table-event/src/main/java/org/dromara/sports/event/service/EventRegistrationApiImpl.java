package org.dromara.sports.event.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.EventRegistrationApi;
import org.dromara.sports.api.EventRegistrationApi.DeclarationNotice;
import org.dromara.sports.api.EventRegistrationApi.EventRegistrationGate;
import org.dromara.sports.api.EventRegistrationApi.ManagedEventOption;
import org.dromara.sports.api.OrganizationQualificationApi;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.api.OrganizationSessionApi.ManagedOrganization;
import org.dromara.sports.event.domain.SportsEvent;
import org.dromara.sports.event.mapper.SportsEventMapper;
import org.springframework.stereotype.Service;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

/**
 * 给报名模块的赛事门禁。公开与否和 M1.3 相同：已发布且组织仍准入。
 */
@Service
@RequiredArgsConstructor
public class EventRegistrationApiImpl implements EventRegistrationApi {

    private static final ZoneOffset SHANGHAI = ZoneOffset.ofHours(8);

    private final SportsEventMapper eventMapper;
    private final OrganizationQualificationApi qualificationApi;
    private final OrganizationSessionApi sessionApi;

    @Override
    public Optional<EventRegistrationGate> publicGate(Long eventId) {
        SportsEvent event = TenantHelper.ignore(() -> eventMapper.selectById(eventId));
        if (event == null || !"published".equals(event.getPublicationStatus())
            || !qualificationApi.isCertified(event.getTenantId(), event.getOrganizationId())) {
            return Optional.empty();
        }
        return Optional.of(toGate(event));
    }

    @Override
    public Optional<EventRegistrationGate> findEvent(Long eventId) {
        SportsEvent event = TenantHelper.ignore(() -> eventMapper.selectById(eventId));
        if (event == null) {
            return Optional.empty();
        }
        return Optional.of(toGate(event));
    }

    @Override
    public Optional<EventRegistrationGate> managedGate(Long eventId) {
        ManagedOrganization organization = requireOrganizer();
        SportsEvent event = eventMapper.selectById(eventId);
        if (event == null || !organization.organizationId().equals(event.getOrganizationId())
            || !organization.tenantId().equals(event.getTenantId())) {
            return Optional.empty();
        }
        return Optional.of(toGate(event));
    }

    @Override
    public void lockRegistrationReview(String tenantId, Long eventId) {
        TenantHelper.dynamic(tenantId, () -> {
            SportsEvent event = eventMapper.selectById(eventId);
            if (event == null || Boolean.TRUE.equals(event.getRegistrationReviewLocked())) {
                return null;
            }
            event.setRegistrationReviewLocked(true);
            if (eventMapper.updateById(event) != 1) {
                throw new ServiceException("赛事已被更新，请再提交一次");
            }
            return null;
        });
    }

    @Override
    public List<ManagedEventOption> listManaged() {
        ManagedOrganization organization = requireOrganizer();
        OffsetDateTime now = OffsetDateTime.now(SHANGHAI);
        return eventMapper.selectList(Wrappers.<SportsEvent>lambdaQuery()
                .eq(SportsEvent::getOrganizationId, organization.organizationId())
                .orderByDesc(SportsEvent::getCreateTime)
                .orderByDesc(SportsEvent::getId))
            .stream()
            .map(event -> new ManagedEventOption(event.getId(), event.getName(), event.getPublicationStatus(),
                event.getHoldingStatus(), unitOpen(event, now)))
            .toList();
    }

    private boolean unitOpen(SportsEvent event, OffsetDateTime now) {
        return "normal".equals(event.getHoldingStatus())
            && (event.getClosureStatus() == null || "open".equals(event.getClosureStatus()))
            && qualificationApi.isCertified(event.getTenantId(),event.getOrganizationId())
            && (event.getEndsAt() == null || now.isBefore(event.getEndsAt()));
    }

    @Override public boolean acceptsNewBusiness(Long id) {
        SportsEvent event=TenantHelper.ignore(()->eventMapper.selectById(id));
        return event!=null&&unitOpen(event,OffsetDateTime.now(SHANGHAI));
    }
    @Override public boolean fullyClosed(Long id) {
        SportsEvent event=TenantHelper.ignore(()->eventMapper.selectById(id));
        return event!=null&&"closed".equals(event.getClosureStatus());
    }

    @Override
    public Optional<DeclarationNotice> declaration(Long eventId) {
        SportsEvent event = TenantHelper.ignore(() -> eventMapper.selectById(eventId));
        if (event == null) {
            return Optional.empty();
        }
        return Optional.of(new DeclarationNotice(Boolean.TRUE.equals(event.getDeclarationAckRequired()),
            event.getDeclarationText(), event.getDeclarationFileId()));
    }

    private EventRegistrationGate toGate(SportsEvent event) {
        return new EventRegistrationGate(event.getId(), event.getTenantId(), event.getOrganizationId(), event.getName(),
            event.getPublicationStatus(), event.getHoldingStatus(), event.getRegistrationOpensAt(),
            event.getRegistrationClosesAt(), event.getStartsAt(), event.getEndsAt(),
            event.getRegistrationReview() == null ? "manual" : event.getRegistrationReview(),
            Boolean.TRUE.equals(event.getRegistrationReviewLocked()));
    }

    private ManagedOrganization requireOrganizer() {
        if (!org.dromara.sports.platform.core.BusinessIdentity.isLogin() || org.dromara.sports.platform.core.BusinessIdentity.getUserType() != UserType.SYS_USER) {
            throw new ServiceException("请先进入组织");
        }
        ManagedOrganization organization = sessionApi.managedOrganization(org.dromara.sports.platform.core.BusinessIdentity.getUserId())
            .orElseThrow(() -> new ServiceException("当前账号不能管理这个组织的报名"));
        if (!organization.tenantId().equals(org.dromara.sports.platform.core.BusinessIdentity.getTenantId())) {
            throw new ServiceException("请先进入该组织");
        }
        return organization;
    }
}
