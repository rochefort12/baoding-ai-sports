package org.dromara.sports.identity.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.identity.PlatformSession;
import org.dromara.sports.identity.domain.SportsProfileTrace;
import org.dromara.sports.identity.mapper.SportsProfileTraceMapper;
import org.springframework.stereotype.Service;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * 给后台留档案修改和反馈记录。不保存证件全文。
 */
@Service
@RequiredArgsConstructor
public class ProfileTraceService {

    private static final ZoneOffset SHANGHAI = ZoneOffset.ofHours(8);

    private final SportsProfileTraceMapper traceMapper;
    private final ObjectMapper objectMapper;

    public void profileChanged(Long accountId, Long personId, List<String> fields) {
        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("personId", personId);
        summary.put("fields", fields);
        write(accountId, "profile-update", "person", personId, summary);
    }

    public void feedback(Long accountId, String topic, String detail) {
        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("topic", topic);
        summary.put("detail", detail);
        summary.put("handled", false);
        write(accountId, "feedback", "account", accountId, summary);
    }

    public void identityLinked(Long operatorAccountId, Long accountId, Long personId, String reason) {
        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("accountId", accountId);
        summary.put("personId", personId);
        summary.put("reason", reason);
        write(operatorAccountId == null ? accountId : operatorAccountId, "identity-link", "account", accountId, summary);
    }

    public List<TraceCard> recent() {
        List<SportsProfileTrace> rows = traceMapper.selectList(Wrappers.<SportsProfileTrace>lambdaQuery()
            .in(SportsProfileTrace::getAction, "profile-update", "feedback", "identity-link")
            .orderByDesc(SportsProfileTrace::getId)
            .last("limit 50"));
        return rows.stream().map(row -> new TraceCard(row.getId(), row.getAction(), row.getObjectType(), row.getObjectId(),
            row.getOccurredAt() == null ? null : row.getOccurredAt().toString(), row.getSummary())).toList();
    }

    private void write(Long actorAccountId, String action, String objectType, Long objectId, Map<String, Object> summary) {
        SportsProfileTrace row = new SportsProfileTrace();
        row.setTenantId(PlatformSession.TENANT_ID);
        row.setActorAccountId(actorAccountId);
            row.setAction(action);
            row.setObjectType(objectType);
            row.setObjectId(objectId);
            row.setRequestId(UUID.randomUUID().toString());
            row.setOccurredAt(OffsetDateTime.now(SHANGHAI));
            try {
                row.setSummary(objectMapper.writeValueAsString(summary));
            } catch (JsonProcessingException exception) {
                throw new ServiceException("记录无法保存");
            }
        row.setVersion(0);
        traceMapper.insert(row);
    }

    public record TraceCard(Long id, String action, String objectType, Long objectId, String occurredAt, String summary) {
    }
}
