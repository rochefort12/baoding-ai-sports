package org.dromara.sports.event.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.sports.api.*;
import org.dromara.sports.platform.core.ScopedJdbc;
import org.junit.jupiter.api.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** A human closure flag cannot turn a future normal event into a finished competition. */
@Tag("local")
class EventClosureTimeTest {
    private final Map<String, Object> event = new LinkedHashMap<>();
    private long matches = 1, missingResults;
    private int writes;
    private List<Map<String,Object>> honors = List.of();
    private final ObjectMapper json = new ObjectMapper();
    private final ScopedJdbc db = mock(ScopedJdbc.class, call -> {
        return switch (call.getMethod().getName()) {
            case "one" -> event;
            case "list" -> honors;
            case "count" -> {
                String sql = call.getArgument(0);
                yield sql.startsWith("SELECT count(*) FROM asp_match") ? (sql.contains("NOT EXISTS") ? missingResults : matches) : 0L;
            }
            case "update" -> { writes++; yield 1; }
            default -> null;
        };
    });
    private final OrganizationSessionApi organizations = mock(OrganizationSessionApi.class);
    private final OrganizationQualificationApi qualifications = mock(OrganizationQualificationApi.class);
    private final EventClosureService service = new EventClosureService(db, json, organizations, qualifications);
    private void session(Runnable test) {
        event.put("id", 901L); event.put("name", "Synthetic future event"); event.put("version", 3);
        event.put("holding_status", "normal"); event.put("closure_status", "open");
        event.put("starts_at", "2026-10-11T18:30:00+08:00"); event.put("has_started", false);
        when(organizations.managedOrganization(201L)).thenReturn(Optional.of(new OrganizationSessionApi.ManagedOrganization(601L, "Fixture", "fixture", 301L)));
        when(qualifications.hasStaffAction("fixture", 601L, 301L, "organize")).thenReturn(true);
        try (var login = mockStatic(LoginHelper.class)) { login.when(LoginHelper::getUserId).thenReturn(201L); test.run(); }
    }
    private com.fasterxml.jackson.databind.JsonNode input() { return json.createObjectNode().put("eventId", "901").put("expectedVersion", 3); }
    @Test void futureNormalEventCannotWrapupDespiteCompleteScores() {
        session(() -> { assertTrue(assertThrows(ServiceException.class, () -> service.execute("event.wrapup", input())).getMessage().contains("尚未开赛")); assertEquals(0, writes); });
    }
    @Test void futureNormalEventCannotCloseDespitePriorWrapupFlag() {
        session(() -> { event.put("closure_status", "wrap_up"); assertFalse(service.summary(901L).path("competitionEnded").asBoolean()); assertThrows(ServiceException.class, () -> service.execute("event.close", input())); assertEquals(0, writes); });
    }
    @Test void missingStartDoesNotPermitNormalClosure() {
        session(() -> { event.remove("starts_at"); event.remove("has_started"); assertThrows(ServiceException.class, () -> service.execute("event.wrapup", input())); assertEquals(0, writes); });
    }
    @Test void begunEventMayWrapupWhenAllRecordedMatchesHaveFormalResults() {
        session(() -> { event.put("has_started", true); service.execute("event.wrapup", input()); assertEquals(1, writes); });
    }
    @Test void begunEventStillCannotWrapupWithMissingFormalResults() {
        session(() -> { event.put("has_started", true); missingResults = 1; assertTrue(assertThrows(ServiceException.class, () -> service.execute("event.wrapup", input())).getMessage().contains("各场次正式结果")); assertEquals(0, writes); });
    }
    @Test void begunAndCompletedEventMayCloseBeforePlannedEnd() {
        session(() -> { event.put("has_started", true); event.put("closure_status", "wrap_up"); service.execute("event.close", input()); assertEquals(1, writes); });
    }
    @Test void cancelledFutureEventMayFinishItsIndependentAftercare() {
        session(() -> {
            event.put("holding_status", "cancelled"); matches = 0;
            assertTrue(service.summary(901L).path("competitionEnded").asBoolean());
            service.execute("event.wrapup", input()); service.execute("event.close", input()); assertEquals(2, writes);
        });
    }
    private Map<String,Object> honor(long id,String title,String state) { return Map.of("id",id,"registration_id",10L,"person_id",7L,"award_key","award-"+id,"title",title,"status",state,"source_text","{}"); }
    @Test void repeatedPlacingCorrectionsCountOneReviewClaim() {
        session(() -> {honors=List.of(honor(1,"第一名","suspended"),honor(2,"第三名","suspended"));assertEquals(1,service.summary(901).path("proofsAwaitingReview").asInt());});
    }
    @Test void olderPendingClaimDoesNotBlockANewerVerifiedReplacement() {
        session(() -> {honors=List.of(honor(1,"第一名","suspended"),honor(2,"第二名","verified"));assertEquals(0,service.summary(901).path("proofsAwaitingReview").asInt());});
    }
}
