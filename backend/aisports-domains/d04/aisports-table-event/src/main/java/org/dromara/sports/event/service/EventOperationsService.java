package org.dromara.sports.event.service;

import lombok.RequiredArgsConstructor;
import org.dromara.sports.api.RegistrationOperationsApi;
import org.dromara.sports.api.RegistrationOperationsApi.Summary;
import org.dromara.sports.api.RegistrationOperationsApi.DailyCount;
import org.springframework.stereotype.Service;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;

/** 当前组织全局运营快照。赛事服务验证会话和组织，每场统计再次验证归属。 */
@Service
@RequiredArgsConstructor
public class EventOperationsService {
    private final EventPublicationService eventService;
    private final RegistrationOperationsApi registrationOperationsApi;

    public Snapshot snapshot() {
        var events = eventService.listManaged();
        var rows = events.stream().map(event -> {
            Summary s = registrationOperationsApi.summarize(event.id());
            boolean active = "normal".equals(event.holdingStatus()) && !"finished".equals(event.phase());
            // 无需审核的收费报名可能仍在等付款，不能误列为资格待审。
            boolean reviewable = active && !"ongoing".equals(event.phase()) && "manual".equals(event.registrationReview());
            return new EventSummary(event.id(), event.name(), event.projectName(), event.phase(), event.publicationStatus(), event.holdingStatus(), s.currentEntries(), reviewable ? s.pendingReview() : 0,
                s.unpaidEntries(), s.declaredEntries(), s.pendingFunds(), s.occupied(), s.capacity(), s.trend());
        }).toList();
        return new Snapshot(OffsetDateTime.now(ZoneOffset.ofHours(8)), rows);
    }

    public record EventSummary(Long eventId, String name, String projectName, String phase, String publicationStatus, String holdingStatus, long currentEntries, long pendingReview, long unpaidEntries,
                               long declaredEntries, long pendingFunds, long occupied, long capacity, List<DailyCount> trend) { }
    public record Snapshot(OffsetDateTime refreshedAt, List<EventSummary> events) { }
}
