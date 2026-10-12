package org.dromara.sports.organization.service;

import cn.hutool.crypto.SecureUtil;
import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.api.PlatformAccountApi;
import org.dromara.sports.organization.OrganizationSlice;
import org.dromara.sports.organization.domain.SportsAccountTenantPrincipal;
import org.dromara.sports.organization.domain.SportsFile;
import org.dromara.sports.organization.domain.SportsOrganization;
import org.dromara.sports.organization.domain.SportsOrganizationApplication;
import org.dromara.sports.organization.domain.SportsOrganizationApplicationVersion;
import org.dromara.sports.organization.domain.SportsStaffGrant;
import org.dromara.sports.organization.mapper.SportsAccountTenantPrincipalMapper;
import org.dromara.sports.organization.mapper.SportsFileMapper;
import org.dromara.sports.organization.mapper.SportsOrganizationApplicationMapper;
import org.dromara.sports.organization.mapper.SportsOrganizationApplicationVersionMapper;
import org.dromara.sports.organization.mapper.SportsOrganizationMapper;
import org.dromara.sports.organization.mapper.SportsStaffGrantMapper;
import org.dromara.sports.api.OrganizationProvisioningApi.Opening;
import org.dromara.sports.api.OrganizationProvisioningApi;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * 办赛申请。通过前没有组织，也没有租户。通过时在同一事务里开户，最后才把申请改成已通过。
 */
@Service
@RequiredArgsConstructor
public class OrganizationApplicationService {

    private static final ZoneOffset SHANGHAI = ZoneOffset.ofHours(8);
    private static final int MAX_FILES = 10;
    private static final int MAX_UPLOADS = 30;

    private final SportsOrganizationApplicationMapper applicationMapper;
    private final SportsOrganizationApplicationVersionMapper versionMapper;
    private final SportsOrganizationMapper organizationMapper;
    private final SportsStaffGrantMapper grantMapper;
    private final SportsAccountTenantPrincipalMapper principalMapper;
    private final SportsFileMapper fileMapper;
    private final OrganizationFileStore fileStore;
    private final PlatformAccountApi platformAccountApi;
    private final OrganizationSessionApi sessionApi;
    private final OrganizationProvisioningApi tenantService;

    @Value("${participant.phone-pepper:}")
    private String phonePepper;

    public ApplicationView current() {
        SportsOrganizationApplication application = findMine(currentAccountId());
        if (application == null) {
            return ApplicationView.empty();
        }
        return toView(application);
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.organization_application.organization_application_service.save", title="OrganizationApplicationService.save", reads={"asp_account","asp_account_tenant_principal","asp_competition_type","asp_event","asp_event_payment_config","asp_fee_obligation","asp_fee_policy","asp_file","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_material_submission","asp_organization","asp_organization_application","asp_organization_application_version","asp_person","asp_profile_display","asp_registration_payment_proof","asp_roster_member","asp_roster_version","asp_sport","asp_staff_grant","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_account_tenant_principal","asp_competition_type","asp_event","asp_event_payment_config","asp_fee_obligation","asp_fee_policy","asp_file","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_material_submission","asp_organization","asp_organization_application","asp_organization_application_version","asp_person","asp_profile_display","asp_registration_payment_proof","asp_roster_member","asp_roster_version","asp_sport","asp_staff_grant","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional(rollbackFor = Exception.class)
    public ApplicationView save(Draft draft) {
        saveWorking(currentAccountId(), draft);
        return current();
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.organization_application.organization_application_service.submit", title="OrganizationApplicationService.submit", reads={"asp_account","asp_account_tenant_principal","asp_competition_type","asp_event","asp_event_payment_config","asp_fee_obligation","asp_fee_policy","asp_file","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_material_submission","asp_organization","asp_organization_application","asp_organization_application_version","asp_person","asp_profile_display","asp_registration_payment_proof","asp_roster_member","asp_roster_version","asp_sport","asp_staff_grant","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_account_tenant_principal","asp_competition_type","asp_event","asp_event_payment_config","asp_fee_obligation","asp_fee_policy","asp_file","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_material_submission","asp_organization","asp_organization_application","asp_organization_application_version","asp_person","asp_profile_display","asp_registration_payment_proof","asp_roster_member","asp_roster_version","asp_sport","asp_staff_grant","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional(rollbackFor = Exception.class)
    public ApplicationView submit(Draft draft) {
        Long accountId = currentAccountId();
        saveWorking(accountId, draft);
        SportsOrganizationApplication application = findMine(accountId);
        if (!"draft".equals(application.getStatus()) && !"rejected".equals(application.getStatus())) {
            throw new ServiceException("待审或已通过的申请不能再次提交");
        }
        if (blank(application.getName()) || blank(application.getContactName()) || blank(application.getContactCipher())) {
            throw new ServiceException("提交时名称、联系人和联系方式都要填写");
        }
        SportsOrganizationApplicationVersion version = new SportsOrganizationApplicationVersion();
        version.setApplicationId(application.getId());
        version.setRevision(nextRevision(application.getId()));
        version.setName(application.getName());
        version.setContactName(application.getContactName());
        version.setContactCipher(application.getContactCipher());
        version.setStatement(application.getStatement());
        version.setFileIds(application.getFileIds() == null ? FileIdJson.write(List.of()) : application.getFileIds());
        version.setStatus("pending");
        version.setVersion(0);
        versionMapper.insert(version);
        application.setStatus("pending");
        if (applicationMapper.updateById(application) != 1) {
            throw new ServiceException("申请已被更新，请刷新后再提交");
        }
        return toView(application);
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.organization_application.organization_application_service.upload", title="OrganizationApplicationService.upload", reads={"asp_account","asp_account_tenant_principal","asp_competition_type","asp_event","asp_event_payment_config","asp_fee_obligation","asp_fee_policy","asp_file","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_material_submission","asp_organization","asp_organization_application","asp_organization_application_version","asp_person","asp_profile_display","asp_registration_payment_proof","asp_roster_member","asp_roster_version","asp_sport","asp_staff_grant","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_account_tenant_principal","asp_competition_type","asp_event","asp_event_payment_config","asp_fee_obligation","asp_fee_policy","asp_file","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_material_submission","asp_organization","asp_organization_application","asp_organization_application_version","asp_person","asp_profile_display","asp_registration_payment_proof","asp_roster_member","asp_roster_version","asp_sport","asp_staff_grant","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional(rollbackFor = Exception.class)
    public FileItem upload(MultipartFile file) {
        Long accountId = currentAccountId();
        if (file == null || file.isEmpty()) {
            throw new ServiceException("请选择附件");
        }
        byte[] body;
        try {
            body = file.getBytes();
        } catch (IOException exception) {
            throw new ServiceException("附件读取失败");
        }
        if (body.length > 10 * 1024 * 1024) {
            throw new ServiceException("单个附件不超过 10MB");
        }
        String safeName = fileStore.safeName(file.getOriginalFilename());
        Long existing = fileMapper.selectCount(Wrappers.<SportsFile>lambdaQuery()
            .eq(SportsFile::getOwnerAccountId, accountId)
            .eq(SportsFile::getPurpose, OrganizationSlice.FILE_PURPOSE)
            .eq(SportsFile::getStatus, "active"));
        if (existing != null && existing >= MAX_UPLOADS) {
            throw new ServiceException("附件数量已达上限");
        }
        SportsFile row = new SportsFile();
        row.setOwnerAccountId(accountId);
        row.setObjectKey(OrganizationSlice.FILE_PURPOSE + "/" + accountId + "/tmp-" + java.util.UUID.randomUUID());
        row.setSha256(fileStore.sha256(body));
        row.setPurpose(OrganizationSlice.FILE_PURPOSE);
        row.setSensitivity("ordinary");
        row.setStatus("active");
        row.setVersion(0);
        fileMapper.insert(row);
        String objectKey = fileStore.objectKey(accountId, row.getId(), safeName);
        row.setObjectKey(objectKey);
        fileMapper.updateById(row);
        try {
            fileStore.write(objectKey, body);
        } catch (RuntimeException exception) {
            fileStore.deleteQuietly(objectKey);
            throw exception;
        }
        return new FileItem(row.getId(), safeName);
    }

    public StoredFile openOwn(Long fileId) {
        SportsFile file = requireOwnedFile(fileId, currentAccountId());
        return new StoredFile(fileStore.displayName(file), fileStore.read(file));
    }

    public List<PendingItem> pending() {
        requireSuperAdmin();
        List<SportsOrganizationApplication> applications = applicationMapper.selectList(Wrappers.<SportsOrganizationApplication>lambdaQuery()
            .eq(SportsOrganizationApplication::getStatus, "pending")
            .eq(!LoginHelper.isSuperAdmin(), SportsOrganizationApplication::getAssignedReviewerId, LoginHelper.getUserId())
            .orderByDesc(SportsOrganizationApplication::getCreateTime)
            .orderByDesc(SportsOrganizationApplication::getId));
        List<PendingItem> items = new ArrayList<>();
        for (SportsOrganizationApplication application : applications) {
            SportsOrganizationApplicationVersion version = latestVersion(application.getId());
            items.add(new PendingItem(application.getId(), application.getName(), application.getContactName(),
                version == null ? null : version.getRevision()));
        }
        return items;
    }

    public ApplicationView review(Long applicationId) {
        requireSuperAdmin();
        SportsOrganizationApplication application = requireApplication(applicationId);
        requireAssignedReview(application);
        return toView(application);
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.organization_application.organization_application_service.approve", title="OrganizationApplicationService.approve", reads={"asp_account","asp_account_tenant_principal","asp_competition_type","asp_event","asp_event_payment_config","asp_fee_obligation","asp_fee_policy","asp_file","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_material_submission","asp_organization","asp_organization_application","asp_organization_application_version","asp_person","asp_profile_display","asp_registration_payment_proof","asp_roster_member","asp_roster_version","asp_sport","asp_staff_grant","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_account_tenant_principal","asp_competition_type","asp_event","asp_event_payment_config","asp_fee_obligation","asp_fee_policy","asp_file","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_material_submission","asp_organization","asp_organization_application","asp_organization_application_version","asp_person","asp_profile_display","asp_registration_payment_proof","asp_roster_member","asp_roster_version","asp_sport","asp_staff_grant","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional(rollbackFor = Exception.class)
    public void approve(Long applicationId) {
        requireSuperAdmin();
        SportsOrganizationApplication application = requireApplication(applicationId);
        requireAssignedReview(application);
        if (!"pending".equals(application.getStatus())) {
            throw new ServiceException("只有待审申请可以通过");
        }
        SportsOrganizationApplicationVersion version = pendingVersion(application.getId());
        // 组织表的租户号不能为空，所以先开户拿到编号。失败时这一笔事务一起回滚，申请仍是待审。
        Opening opening = tenantService.open(version.getName(), version.getContactName(),
            OrganizationSlice.PACKAGE_ID, application.getApplicantAccountId());
        SportsOrganization organization = new SportsOrganization();
        organization.setTenantId(opening.tenantId());
        organization.setName(version.getName());
        organization.setStatus("certified");
        organization.setContactCipher(version.getContactCipher());
        organization.setVersion(0);
        TenantHelper.dynamic(opening.tenantId(), () -> organizationMapper.insert(organization));

        SportsAccountTenantPrincipal principal = new SportsAccountTenantPrincipal();
        principal.setAccountId(application.getApplicantAccountId());
        principal.setTenantId(opening.tenantId());
        principal.setSysUserId(opening.sysUserId());
        principal.setStatus("active");
        principal.setVersion(0);
        principalMapper.insert(principal);

        SportsStaffGrant grant = new SportsStaffGrant();
        grant.setTenantId(opening.tenantId());
        grant.setOrganizationId(organization.getId());
        grant.setAccountId(application.getApplicantAccountId());
        grant.setPermissions(GrantJson.organize());
        grant.setStatus("active");
        grant.setValidFrom(OffsetDateTime.now(SHANGHAI));
        grant.setVersion(0);
        TenantHelper.dynamic(opening.tenantId(), () -> grantMapper.insert(grant));

        for (Long fileId : FileIdJson.read(version.getFileIds())) {
            SportsFile file = requireOwnedFile(fileId, application.getApplicantAccountId());
            file.setOwningTenantId(opening.tenantId());
            fileMapper.updateById(file);
        }

        version.setStatus("approved");
        version.setReviewerId(org.dromara.sports.platform.core.BusinessIdentity.getUserId());
        if (versionMapper.updateById(version) != 1) {
            throw new ServiceException("申请已被处理，请刷新后再看");
        }
        application.setOrganizationId(organization.getId());
        application.setOrganizationTenantId(opening.tenantId());
        application.setStatus("approved");
        if (applicationMapper.updateById(application) != 1) {
            throw new ServiceException("申请已被处理，请刷新后再看");
        }
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.organization_application.organization_application_service.reject", title="OrganizationApplicationService.reject", reads={"asp_account","asp_account_tenant_principal","asp_competition_type","asp_event","asp_event_payment_config","asp_fee_obligation","asp_fee_policy","asp_file","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_material_submission","asp_organization","asp_organization_application","asp_organization_application_version","asp_person","asp_profile_display","asp_registration_payment_proof","asp_roster_member","asp_roster_version","asp_sport","asp_staff_grant","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_account_tenant_principal","asp_competition_type","asp_event","asp_event_payment_config","asp_fee_obligation","asp_fee_policy","asp_file","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_material_submission","asp_organization","asp_organization_application","asp_organization_application_version","asp_person","asp_profile_display","asp_registration_payment_proof","asp_roster_member","asp_roster_version","asp_sport","asp_staff_grant","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional(rollbackFor = Exception.class)
    public void reject(Long applicationId, String reason) {
        requireSuperAdmin();
        String reviewReason = required(reason, 1000, "拒绝理由");
        SportsOrganizationApplication application = requireApplication(applicationId);
        requireAssignedReview(application);
        if (!"pending".equals(application.getStatus())) {
            throw new ServiceException("只有待审申请可以拒绝");
        }
        SportsOrganizationApplicationVersion version = pendingVersion(application.getId());
        version.setStatus("rejected");
        version.setReviewerId(org.dromara.sports.platform.core.BusinessIdentity.getUserId());
        version.setReviewReason(reviewReason);
        if (versionMapper.updateById(version) != 1) {
            throw new ServiceException("申请已被处理，请刷新后再看");
        }
        application.setStatus("rejected");
        if (applicationMapper.updateById(application) != 1) {
            throw new ServiceException("申请已被处理，请刷新后再看");
        }
    }

    public StoredFile openForReview(Long applicationId, Long fileId) {
        requireSuperAdmin();
        SportsOrganizationApplication application = requireApplication(applicationId);
        requireAssignedReview(application);
        boolean attached = FileIdJson.read(application.getFileIds()).contains(fileId);
        if (!attached) {
            List<SportsOrganizationApplicationVersion> versions = versionMapper.selectList(Wrappers.<SportsOrganizationApplicationVersion>lambdaQuery()
                .eq(SportsOrganizationApplicationVersion::getApplicationId, applicationId));
            attached = versions.stream().anyMatch(version -> FileIdJson.read(version.getFileIds()).contains(fileId));
        }
        if (!attached) {
            throw new ServiceException("这个附件不属于该申请");
        }
        SportsFile file = requireOwnedFile(fileId, application.getApplicantAccountId());
        return new StoredFile(fileStore.displayName(file), fileStore.read(file));
    }

    private SportsOrganizationApplication saveWorking(Long accountId, Draft draft) {
        SportsOrganizationApplication application = findMine(accountId);
        if (application == null) {
            application = new SportsOrganizationApplication();
            application.setApplicantAccountId(accountId);
            application.setStatus("draft");
            application.setFileIds(FileIdJson.write(List.of()));
            application.setVersion(0);
            try {
                applicationMapper.insert(application);
            } catch (DuplicateKeyException exception) {
                throw new ServiceException("已经有一份办赛申请");
            }
        }
        if (!"draft".equals(application.getStatus()) && !"rejected".equals(application.getStatus())) {
            throw new ServiceException("待审或已通过的申请不能修改");
        }
        application.setName(optional(draft == null ? null : draft.name(), 200, "名称"));
        application.setContactName(optional(draft == null ? null : draft.contactName(), 100, "联系人"));
        String method = optional(draft == null ? null : draft.contactMethod(), 50, "联系方式");
        application.setContactCipher(method == null ? null : encrypt(method));
        application.setStatement(optional(draft == null ? null : draft.statement(), 1000, "申请说明"));
        application.setFileIds(FileIdJson.write(validateFiles(accountId, draft == null ? null : draft.fileIds())));
        if (applicationMapper.updateById(application) != 1) {
            throw new ServiceException("申请已被更新，请刷新后再保存");
        }
        return application;
    }

    private List<Long> validateFiles(Long accountId, List<Long> fileIds) {
        if (fileIds == null || fileIds.isEmpty()) {
            return List.of();
        }
        Set<Long> unique = new LinkedHashSet<>();
        for (Long fileId : fileIds) {
            if (fileId != null) {
                unique.add(fileId);
            }
        }
        if (unique.size() > MAX_FILES) {
            throw new ServiceException("一份申请最多 " + MAX_FILES + " 个附件");
        }
        for (Long fileId : unique) {
            requireOwnedFile(fileId, accountId);
        }
        return new ArrayList<>(unique);
    }

    private SportsFile requireOwnedFile(Long fileId, Long accountId) {
        SportsFile file = fileMapper.selectById(fileId);
        if (file == null || !accountId.equals(file.getOwnerAccountId())
            || !OrganizationSlice.FILE_PURPOSE.equals(file.getPurpose())
            || !"active".equals(file.getStatus())) {
            throw new ServiceException("附件不存在");
        }
        return file;
    }

    private ApplicationView toView(SportsOrganizationApplication application) {
        List<SportsOrganizationApplicationVersion> versions = versionMapper.selectList(Wrappers.<SportsOrganizationApplicationVersion>lambdaQuery()
            .eq(SportsOrganizationApplicationVersion::getApplicationId, application.getId())
            .orderByAsc(SportsOrganizationApplicationVersion::getRevision));
        String reason = null;
        if (!versions.isEmpty()) {
            reason = versions.get(versions.size() - 1).getReviewReason();
        }
        boolean canEnter = "approved".equals(application.getStatus())
            && sessionApi.entryFor(application.getApplicantAccountId()).isPresent();
        List<VersionItem> items = new ArrayList<>();
        for (SportsOrganizationApplicationVersion version : versions) {
            items.add(new VersionItem(version.getRevision(), version.getStatus(), version.getName(), version.getContactName(),
                decrypt(version.getContactCipher()), version.getStatement(), filesOf(version.getFileIds()), version.getReviewReason()));
        }
        return new ApplicationView(application.getId(), application.getStatus(), application.getName(), application.getContactName(),
            decrypt(application.getContactCipher()), application.getStatement(), filesOf(application.getFileIds()), reason,
            application.getOrganizationId(), canEnter, items);
    }

    private List<FileItem> filesOf(String json) {
        List<FileItem> items = new ArrayList<>();
        for (Long fileId : FileIdJson.read(json)) {
            SportsFile file = fileMapper.selectById(fileId);
            items.add(new FileItem(fileId, file == null ? "附件已缺失" : fileStore.displayName(file)));
        }
        return items;
    }

    private SportsOrganizationApplication findMine(Long accountId) {
        return applicationMapper.selectOne(Wrappers.<SportsOrganizationApplication>lambdaQuery()
            .eq(SportsOrganizationApplication::getApplicantAccountId, accountId));
    }

    private SportsOrganizationApplication requireApplication(Long applicationId) {
        SportsOrganizationApplication application = applicationMapper.selectById(applicationId);
        if (application == null) {
            throw new ServiceException("申请不存在");
        }
        return application;
    }

    private SportsOrganizationApplicationVersion pendingVersion(Long applicationId) {
        SportsOrganizationApplicationVersion version = versionMapper.selectOne(Wrappers.<SportsOrganizationApplicationVersion>lambdaQuery()
            .eq(SportsOrganizationApplicationVersion::getApplicationId, applicationId)
            .eq(SportsOrganizationApplicationVersion::getStatus, "pending")
            .orderByDesc(SportsOrganizationApplicationVersion::getRevision)
            .last("limit 1"));
        if (version == null) {
            throw new ServiceException("没有待审版本");
        }
        return version;
    }

    private SportsOrganizationApplicationVersion latestVersion(Long applicationId) {
        return versionMapper.selectOne(Wrappers.<SportsOrganizationApplicationVersion>lambdaQuery()
            .eq(SportsOrganizationApplicationVersion::getApplicationId, applicationId)
            .orderByDesc(SportsOrganizationApplicationVersion::getRevision)
            .last("limit 1"));
    }

    private int nextRevision(Long applicationId) {
        SportsOrganizationApplicationVersion latest = latestVersion(applicationId);
        return latest == null || latest.getRevision() == null ? 1 : latest.getRevision() + 1;
    }

    private Long currentAccountId() {
        return platformAccountApi.currentAccountId().orElseThrow(() -> new ServiceException("请使用平台账号登录后再申请办赛"));
    }

    private void requireAssignedReview(SportsOrganizationApplication application) {
        if (!LoginHelper.isSuperAdmin() && !java.util.Objects.equals(application.getAssignedReviewerId(), LoginHelper.getUserId()))
            throw new ServiceException("该申请未分配给当前审核岗位",403);
    }

    private void requireSuperAdmin() {
        if (!org.dromara.sports.platform.core.BusinessIdentity.isLogin() || org.dromara.sports.platform.core.BusinessIdentity.getUserType() != UserType.SYS_USER ||
            (!org.dromara.sports.platform.core.BusinessIdentity.isSuperAdmin() && !cn.dev33.satoken.stp.StpUtil.hasPermission("sports:organization:review"))) {
            throw new ServiceException("请由获授权的政府准入审核岗位办理");
        }
    }

    private String optional(String value, int max, String label) {
        if (value == null || value.isBlank()) {
            return null;
        }
        String trimmed = value.trim();
        if (trimmed.length() > max) {
            throw new ServiceException(label + "不超过" + max + "字");
        }
        return trimmed;
    }

    private String required(String value, int max, String label) {
        String trimmed = optional(value, max, label);
        if (trimmed == null) {
            throw new ServiceException("请填写" + label);
        }
        return trimmed;
    }

    private boolean blank(String value) {
        return value == null || value.isBlank();
    }

    private String encrypt(String plain) {
        return SecureUtil.aes(aesKey()).encryptBase64(plain);
    }

    private String decrypt(String cipher) {
        if (cipher == null || cipher.isBlank()) {
            return null;
        }
        try {
            return SecureUtil.aes(aesKey()).decryptStr(cipher);
        } catch (RuntimeException exception) {
            throw new ServiceException("联系方式无法读取");
        }
    }

    private byte[] aesKey() {
        if (phonePepper == null || phonePepper.isBlank()) {
            throw new IllegalStateException("缺少联系方式加密配置");
        }
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(phonePepper.getBytes(StandardCharsets.UTF_8));
            return Arrays.copyOf(digest, 16);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 不可用", exception);
        }
    }

    public record Draft(String name, String contactName, String contactMethod, String statement, List<Long> fileIds) {
    }

    public record FileItem(Long fileId, String fileName) {
    }

    public record VersionItem(Integer revision, String status, String name, String contactName, String contactMethod,
                              String statement, List<FileItem> files, String reviewReason) {
    }

    public record ApplicationView(Long applicationId, String status, String name, String contactName, String contactMethod,
                                  String statement, List<FileItem> files, String reviewReason, Long organizationId,
                                  boolean canEnter, List<VersionItem> versions) {
        static ApplicationView empty() {
            return new ApplicationView(null, null, null, null, null, null, List.of(), null, null, false, List.of());
        }
    }

    public record PendingItem(Long applicationId, String name, String contactName, Integer revision) {
    }

    public record StoredFile(String fileName, byte[] body) {
    }
}
