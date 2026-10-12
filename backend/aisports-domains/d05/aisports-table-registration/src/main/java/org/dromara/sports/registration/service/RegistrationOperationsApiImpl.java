package org.dromara.sports.registration.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import lombok.RequiredArgsConstructor;
import org.dromara.sports.api.FeeApi;
import org.dromara.sports.api.RegistrationOperationsApi;
import org.dromara.sports.registration.domain.SportsRegistration;
import org.dromara.sports.registration.mapper.SportsRegistrationMapper;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.LinkedHashMap;
import java.util.Map;

/** 复用项目授权与费用契约，不跨模块读取赛事或资金表。读失败由调用方整体报错，不填估算零值。 */
@Service
@RequiredArgsConstructor
public class RegistrationOperationsApiImpl implements RegistrationOperationsApi {
    private final RegistrationService registrationService;
    private final SportsRegistrationMapper registrationMapper;
    private final FeeApi feeApi;

    @Override
    public Summary summarize(Long eventId) {
        var units = registrationService.listManagedUnits(eventId);
        long current=0, pending=0, unpaid=0, declared=0, funds=0, occupied=0, capacity=0;
        ZoneId zone = ZoneId.of("Asia/Shanghai");
        LocalDate today = LocalDate.now(zone);
        Map<LocalDate, Long> daily = new LinkedHashMap<>();
        for (int offset=6; offset>=0; offset--) daily.put(today.minusDays(offset), 0L);
        for (var unit : units) {
            occupied += unit.usedCount();
            capacity += unit.limitCount();
            var rows = registrationMapper.selectList(Wrappers.<SportsRegistration>lambdaQuery()
                .eq(SportsRegistration::getUnitId, unit.id()));
            for (var row : rows) {
                boolean active = "submitted".equals(row.getStatus()) || "approved".equals(row.getStatus());
                if (active) current++;
                if ("submitted".equals(row.getStatus())) pending++;
                // 当前付款义务状态用于数量；不向运营概览暴露付款人、流水和金额。
                var fee = feeApi.current(row.getTenantId(), row.getId()).orElse(null);
                if (fee != null) {
                    if (fee.pendingActionId() != null) funds++;
                    if (active && "open".equals(fee.status()) && fee.amount() != null && fee.amount().signum()>0) {
                        unpaid++;
                        if (fee.participantDeclared()) declared++;
                    }
                }
                // 这是每条报名最近一次正式提交的日期分布，不宣称包含历史重提次数。
                if (row.getSubmittedAt() != null) {
                    LocalDate day = row.getSubmittedAt().atZoneSameInstant(zone).toLocalDate();
                    daily.computeIfPresent(day, (key, value) -> value+1);
                }
            }
        }
        return new Summary(current, pending, unpaid, declared, funds, occupied, capacity,
            daily.entrySet().stream().map(e -> new DailyCount(e.getKey(), e.getValue())).toList());
    }
}
