package org.dromara.sports.organization.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.OrganizationQualificationApi;
import org.dromara.sports.api.OrganizationQualificationApi.OrganizerContact;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.organization.OrganizationSlice;
import cn.hutool.crypto.SecureUtil;
import org.dromara.sports.organization.domain.SportsAccountTenantPrincipal;
import org.dromara.sports.organization.domain.SportsOrganization;
import org.dromara.sports.organization.domain.SportsOrganizationApplication;
import org.dromara.sports.organization.domain.SportsStaffGrant;
import org.dromara.sports.organization.mapper.SportsAccountTenantPrincipalMapper;
import org.dromara.sports.organization.mapper.SportsOrganizationApplicationMapper;
import org.dromara.sports.organization.mapper.SportsOrganizationMapper;
import org.dromara.sports.organization.mapper.SportsStaffGrantMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

/**
 * 组织是否已开放办赛、成员是否有动作，以及进入组织前的事实。查询租户表时自己写条件，不用登录租户代替授权。
 */
@Service
@RequiredArgsConstructor
public class OrganizationQueryService implements OrganizationQualificationApi, OrganizationSessionApi {

    private static final ZoneOffset SHANGHAI = ZoneOffset.ofHours(8);

    private final SportsOrganizationMapper organizationMapper;
    private final SportsStaffGrantMapper grantMapper;
    private final SportsAccountTenantPrincipalMapper principalMapper;
    private final SportsOrganizationApplicationMapper applicationMapper;

    @Value("${participant.phone-pepper:}")
    private String phonePepper;

    private String decrypt(String cipher) {
        if (cipher == null || cipher.isBlank() || phonePepper == null || phonePepper.isBlank()) {
            return null;
        }
        try {
            byte[] digest = java.security.MessageDigest.getInstance("SHA-256")
                .digest(phonePepper.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            return SecureUtil.aes(java.util.Arrays.copyOf(digest, 16)).decryptStr(cipher);
        } catch (RuntimeException | java.security.NoSuchAlgorithmException exception) {
            return null;
        }
    }

    @Override
    public OrganizerContact publicContact(String tenantId, Long organizationId) {
        if (tenantId == null || tenantId.isBlank() || organizationId == null) {
            return new OrganizerContact(null, null, null);
        }
        SportsOrganization organization = TenantHelper.ignore(() -> organizationMapper.selectOne(Wrappers.<SportsOrganization>lambdaQuery()
            .eq(SportsOrganization::getTenantId, tenantId)
            .eq(SportsOrganization::getId, organizationId)));
        if (organization == null) {
            return new OrganizerContact(null, null, null);
        }
        SportsOrganizationApplication application = applicationMapper.selectOne(Wrappers.<SportsOrganizationApplication>lambdaQuery()
            .eq(SportsOrganizationApplication::getOrganizationId, organizationId)
            .eq(SportsOrganizationApplication::getStatus, "approved")
            .orderByDesc(SportsOrganizationApplication::getId)
            .last("limit 1"));
        String contactName = application == null ? null : application.getContactName();
        String contactMethod = decrypt(organization.getContactCipher());
        return new OrganizerContact(organization.getName(), contactName, contactMethod);
    }

    @Override
    public boolean isCertified(String tenantId, Long organizationId) {
        if (tenantId == null || tenantId.isBlank() || organizationId == null) {
            return false;
        }
        Long count = TenantHelper.ignore(() -> organizationMapper.selectCount(Wrappers.<SportsOrganization>lambdaQuery()
            .eq(SportsOrganization::getTenantId, tenantId)
            .eq(SportsOrganization::getId, organizationId)
            .eq(SportsOrganization::getStatus, "certified")));
        return count != null && count > 0;
    }

    @Override
    public boolean hasStaffAction(String tenantId, Long organizationId, Long accountId, String action) {
        if (tenantId == null || organizationId == null || accountId == null || action == null || action.isBlank()) {
            return false;
        }
        List<SportsStaffGrant> grants = TenantHelper.ignore(() -> grantMapper.selectList(Wrappers.<SportsStaffGrant>lambdaQuery()
            .eq(SportsStaffGrant::getTenantId, tenantId)
            .eq(SportsStaffGrant::getOrganizationId, organizationId)
            .eq(SportsStaffGrant::getAccountId, accountId)
            .eq(SportsStaffGrant::getStatus, "active")
            .isNull(SportsStaffGrant::getEventId)));
        return grants.stream().anyMatch(grant -> activeNow(grant) && GrantJson.contains(grant.getPermissions(), action));
    }

    @Override
    public boolean isMappedPrincipal(Long sysUserId) {
        if (sysUserId == null) {
            return false;
        }
        return principalMapper.exists(Wrappers.<SportsAccountTenantPrincipal>lambdaQuery()
            .eq(SportsAccountTenantPrincipal::getSysUserId, sysUserId));
    }

    @Override
    public Optional<OrganizationEntry> entryFor(Long accountId) {
        if (accountId == null) {
            return Optional.empty();
        }
        List<SportsStaffGrant> grants = TenantHelper.ignore(() -> grantMapper.selectList(Wrappers.<SportsStaffGrant>lambdaQuery()
            .eq(SportsStaffGrant::getAccountId, accountId)
            .eq(SportsStaffGrant::getStatus, "active")
            .isNull(SportsStaffGrant::getEventId)));
        List<OrganizationEntry> entries = new ArrayList<>();
        Set<Long> seen = new LinkedHashSet<>();
        for (SportsStaffGrant grant : grants) {
            if (!activeNow(grant) || !GrantJson.contains(grant.getPermissions(), OrganizationSlice.ACTION_ORGANIZE)) {
                continue;
            }
            if (!seen.add(grant.getOrganizationId())) {
                continue;
            }
            SportsOrganization organization = TenantHelper.ignore(() -> organizationMapper.selectOne(Wrappers.<SportsOrganization>lambdaQuery()
                .eq(SportsOrganization::getTenantId, grant.getTenantId())
                .eq(SportsOrganization::getId, grant.getOrganizationId())
                .in(SportsOrganization::getStatus, "certified", "restricted")));
            if (organization == null) {
                continue;
            }
            SportsAccountTenantPrincipal principal = principalMapper.selectOne(Wrappers.<SportsAccountTenantPrincipal>lambdaQuery()
                .eq(SportsAccountTenantPrincipal::getAccountId, accountId)
                .eq(SportsAccountTenantPrincipal::getTenantId, grant.getTenantId())
                .eq(SportsAccountTenantPrincipal::getStatus, "active"));
            if (principal == null) {
                continue;
            }
            entries.add(new OrganizationEntry(organization.getId(), organization.getName(), grant.getTenantId(), principal.getSysUserId()));
        }
        if (entries.isEmpty()) {
            return Optional.empty();
        }
        if (entries.size() > 1) {
            throw new ServiceException("本期一个账号只能进入一个组织");
        }
        return Optional.of(entries.get(0));
    }

    @Override
    public Optional<ManagedOrganization> managedOrganization(Long sysUserId) {
        if (sysUserId == null) {
            return Optional.empty();
        }
        SportsAccountTenantPrincipal principal = principalMapper.selectOne(Wrappers.<SportsAccountTenantPrincipal>lambdaQuery()
            .eq(SportsAccountTenantPrincipal::getSysUserId, sysUserId)
            .eq(SportsAccountTenantPrincipal::getStatus, "active"));
        if (principal == null) {
            return Optional.empty();
        }
        Optional<OrganizationEntry> entry = entryFor(principal.getAccountId());
        if (entry.isEmpty()) {
            return Optional.empty();
        }
        OrganizationEntry found = entry.get();
        if (!principal.getTenantId().equals(found.tenantId()) || !sysUserId.equals(found.sysUserId())) {
            return Optional.empty();
        }
        return Optional.of(new ManagedOrganization(found.organizationId(), found.organizationName(), found.tenantId(), principal.getAccountId()));
    }

    @Override
    public Set<String> organizerTenantIds() {
        List<Object> tenantIds = TenantHelper.ignore(() -> organizationMapper.selectObjs(Wrappers.<SportsOrganization>lambdaQuery()
            .select(SportsOrganization::getTenantId)));
        Set<String> result = new LinkedHashSet<>();
        if (tenantIds == null) {
            return result;
        }
        for (Object tenantId : tenantIds) {
            if (tenantId != null && !tenantId.toString().isBlank()) {
                result.add(tenantId.toString());
            }
        }
        return result;
    }

    @Override
    public List<String> soleOrganizerNames(Long accountId) {
        if (accountId == null) {
            return List.of();
        }
        List<SportsStaffGrant> mine = TenantHelper.ignore(() -> grantMapper.selectList(Wrappers.<SportsStaffGrant>lambdaQuery()
            .eq(SportsStaffGrant::getAccountId, accountId)
            .eq(SportsStaffGrant::getStatus, "active")
            .isNull(SportsStaffGrant::getEventId)));
        List<String> names = new ArrayList<>();
        Set<Long> seen = new LinkedHashSet<>();
        for (SportsStaffGrant grant : mine) {
            if (!activeNow(grant) || !GrantJson.contains(grant.getPermissions(), OrganizationSlice.ACTION_ORGANIZE) || !seen.add(grant.getOrganizationId())) {
                continue;
            }
            List<SportsStaffGrant> peers = TenantHelper.ignore(() -> grantMapper.selectList(Wrappers.<SportsStaffGrant>lambdaQuery()
                .eq(SportsStaffGrant::getTenantId, grant.getTenantId())
                .eq(SportsStaffGrant::getOrganizationId, grant.getOrganizationId())
                .eq(SportsStaffGrant::getStatus, "active")
                .isNull(SportsStaffGrant::getEventId)));
            long organizers = peers.stream().filter(peer -> activeNow(peer) && GrantJson.contains(peer.getPermissions(), OrganizationSlice.ACTION_ORGANIZE))
                .map(SportsStaffGrant::getAccountId).distinct().count();
            if (organizers == 1) {
                SportsOrganization organization = TenantHelper.ignore(() -> organizationMapper.selectOne(Wrappers.<SportsOrganization>lambdaQuery()
                    .eq(SportsOrganization::getTenantId, grant.getTenantId())
                    .eq(SportsOrganization::getId, grant.getOrganizationId())));
                names.add(organization == null ? "组织" : organization.getName());
            }
        }
        return names;
    }

    private boolean activeNow(SportsStaffGrant grant) {
        OffsetDateTime now = OffsetDateTime.now(SHANGHAI);
        if (grant.getValidFrom() != null && grant.getValidFrom().isAfter(now)) {
            return false;
        }
        return grant.getValidUntil() == null || grant.getValidUntil().isAfter(now);
    }
}
