package org.dromara.sports.organization.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.dromara.sports.organization.domain.SportsFile;
import org.dromara.sports.organization.mapper.SportsFileMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Date;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * 满 7 天仍没有被收费、赛事或办赛申请引用的文件，删掉对象存储里的内容，元数据改为 deleted。
 * 不另建归档桶。已引用的文件，包括已经停用的收费版本，继续保留。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class UnreferencedFileCleanup {

    private static final ZoneOffset SHANGHAI = ZoneOffset.ofHours(8);

    private final SportsFileMapper fileMapper;
    private final OrganizationFileStore fileStore;
    private final JdbcTemplate jdbcTemplate;

    @Scheduled(cron = "0 30 3 * * *", zone = "Asia/Shanghai")
    public void cleanupNightly() {
        int removed = cleanup(OffsetDateTime.now(SHANGHAI).minusDays(7));
        if (removed > 0) {
            log.info("未引用文件已清理 {} 个", removed);
        }
    }

    /**
     * 删除创建时间早于 cutoff、且当前没有任何引用的有效文件。
     */
    public int cleanup(OffsetDateTime cutoff) {
        Set<Long> referenced = referencedIds();
        List<SportsFile> candidates = fileMapper.selectList(com.baomidou.mybatisplus.core.toolkit.Wrappers.<SportsFile>lambdaQuery()
            .eq(SportsFile::getStatus, "active")
            .lt(SportsFile::getCreateTime, Date.from(cutoff.toInstant())));
        int removed = 0;
        for (SportsFile file : candidates) {
            if (file.getId() == null || referenced.contains(file.getId())) {
                continue;
            }
            fileStore.deleteQuietly(file.getObjectKey());
            file.setStatus("deleted");
            if (fileMapper.updateById(file) == 1) {
                removed++;
            }
        }
        return removed;
    }

    private Set<Long> referencedIds() {
        Set<Long> ids = new HashSet<>();
        addColumn(ids, "SELECT banner_file_id FROM asp_event WHERE banner_file_id IS NOT NULL");
        addColumn(ids, "SELECT rules_file_id FROM asp_event WHERE rules_file_id IS NOT NULL");
        addColumn(ids, "SELECT notice_file_id FROM asp_event WHERE notice_file_id IS NOT NULL");
        addColumn(ids, "SELECT declaration_file_id FROM asp_event WHERE declaration_file_id IS NOT NULL");
        addColumn(ids, "SELECT route_file_id FROM asp_event WHERE route_file_id IS NOT NULL");
        addColumn(ids, "SELECT qr_file_id FROM asp_fee_policy WHERE qr_file_id IS NOT NULL");
        // 统一收款二维码既保留当前配置引用，也保留历史义务快照，变更配置不会清掉已提交报名的材料。
        addColumn(ids, "SELECT (channel->>'qrFileId')::bigint FROM asp_event_payment_config CROSS JOIN LATERAL jsonb_array_elements(settings->'channels') channel WHERE channel->>'qrFileId' IS NOT NULL");
        addColumn(ids, "SELECT (channel->>'qrFileId')::bigint FROM asp_fee_obligation CROSS JOIN LATERAL jsonb_array_elements(COALESCE(quote_snapshot->'paymentSettings'->'channels', '[]'::jsonb)) channel WHERE channel->>'qrFileId' IS NOT NULL");
        addColumn(ids, "SELECT file_id FROM asp_registration_payment_proof");
        addColumn(ids, "SELECT file_id FROM asp_material_submission WHERE file_id IS NOT NULL");
        addColumn(ids, "SELECT avatar_file_id FROM asp_profile_display WHERE avatar_file_id IS NOT NULL");
        // Certification evidence remains required after correction, rejection or revocation; history is not garbage.
        addColumn(ids, "SELECT proof::text::bigint FROM asp_honor CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(certification_details->'proofFileIds','[]'::jsonb)) proof WHERE certification_status IS NOT NULL");
        addColumn(ids, "SELECT proof::text::bigint FROM asp_honor CROSS JOIN LATERAL jsonb_array_elements(certification_history) history CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(history->'details'->'proofFileIds','[]'::jsonb)) proof WHERE certification_status IS NOT NULL");
        for (String json : jdbcTemplate.queryForList("SELECT file_ids::text FROM asp_organization_application WHERE file_ids IS NOT NULL", String.class)) {
            ids.addAll(FileIdJson.read(json));
        }
        for (String json : jdbcTemplate.queryForList("SELECT file_ids::text FROM asp_organization_application_version WHERE file_ids IS NOT NULL", String.class)) {
            ids.addAll(FileIdJson.read(json));
        }
        return ids;
    }

    private void addColumn(Set<Long> ids, String sql) {
        ids.addAll(jdbcTemplate.queryForList(sql, Long.class));
    }
}
