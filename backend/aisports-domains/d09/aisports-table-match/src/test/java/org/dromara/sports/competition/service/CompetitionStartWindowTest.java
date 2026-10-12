package org.dromara.sports.competition.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.core.lock.MutualLock;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.*;
import org.dromara.sports.competition.domain.*;
import org.dromara.sports.competition.mapper.*;
import org.junit.jupiter.api.*;
import org.springframework.transaction.*;
import java.time.OffsetDateTime;
import java.util.*;
import java.util.function.Supplier;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** Future planning is allowed; the first official outcome must not establish a future completed match. */
@Tag("local")
class CompetitionStartWindowTest {
    private final Map<Class<?>, Object> dependencies = new HashMap<>();
    private final CompetitionService service = create();
    private final CompetitionEvent event = new CompetitionEvent();
    private final CompetitionMatch match = new CompetitionMatch();
    private final CompetitionResult result = new CompetitionResult();
    private <T> T dep(Class<T> type) { return type.cast(dependencies.get(type)); }
    private CompetitionService create() {
        try {
            var constructor = CompetitionService.class.getDeclaredConstructors()[0];
            return (CompetitionService) constructor.newInstance(Arrays.stream(constructor.getParameterTypes()).map(type -> {
                Object value = type == ObjectMapper.class ? new ObjectMapper() : mock(type);
                dependencies.put(type, value); return value;
            }).toArray());
        } catch (ReflectiveOperationException error) { throw new AssertionError(error); }
    }
    private void session(Runnable test) {
        var current = OffsetDateTime.now();
        event.setId(901L); event.setOrganizationId(601L); event.setTenantId("fixture");
        event.setHoldingStatus("normal"); event.setStartsAt(current.plusHours(1)); event.setEndsAt(current.plusHours(2));
        var unit = new CompetitionUnit(); unit.setId(501L); unit.setEventId(901L);
        var stage = new CompetitionStage(); stage.setId(6011L); stage.setUnitId(501L); stage.setFormat("SYSTEM_MANUAL");
        match.setId(7011L); match.setStageId(6011L); match.setStatus("published");
        result.setId(8011L); result.setMatchId(7011L); result.setStatus("draft"); result.setRevision(1);
        result.setRawPerformance("{\"summary\":\"synthetic score\",\"outcomeA\":\"win\",\"outcomeB\":\"loss\"}");
        when(dep(CompetitionEventMapper.class).selectById(901L)).thenReturn(event);
        when(dep(CompetitionUnitMapper.class).selectById(501L)).thenReturn(unit);
        when(dep(CompetitionStageMapper.class).selectById(6011L)).thenReturn(stage);
        when(dep(CompetitionMatchMapper.class).selectById(7011L)).thenReturn(match);
        when(dep(CompetitionResultMapper.class).selectOne(any())).thenReturn(result);
        when(dep(CompetitionResultMapper.class).updateById(any(CompetitionResult.class))).thenReturn(1);
        when(dep(OrganizationSessionApi.class).managedOrganization(201L)).thenReturn(Optional.of(
            new OrganizationSessionApi.ManagedOrganization(601L, "Fixture", "fixture", 301L)));
        when(dep(OrganizationQualificationApi.class).hasStaffAction("fixture", 601L, 301L, "organize")).thenReturn(true);
        when(dep(PlatformTransactionManager.class).getTransaction(any(TransactionDefinition.class))).thenReturn(mock(TransactionStatus.class));
        when(dep(MutualLock.class).execute(anyString(), anyLong(), anyLong(), any(Supplier.class)))
            .thenAnswer(call -> ((Supplier<?>) call.getArgument(3)).get());
        try (var login = mockStatic(LoginHelper.class); var tenant = mockStatic(TenantHelper.class)) {
            login.when(LoginHelper::getUserId).thenReturn(201L);
            tenant.when(() -> TenantHelper.dynamic(eq("fixture"), any(Supplier.class)))
                .thenAnswer(call -> ((Supplier<?>) call.getArgument(1)).get());
            test.run();
        }
    }
    private RegistrationRosterApi.RosterView roster() {
        return new RegistrationRosterApi.RosterView(701L, 801L, 501L, 901L, "Pair",
            List.of(new RegistrationRosterApi.RosterPerson(401L, "Fixture")));
    }
    private void noFormalWrite() {
        assertEquals("draft", result.getStatus());
        verify(dep(CompetitionResultMapper.class), never()).updateById(any(CompetitionResult.class));
        verify(dep(ExecutionCommandMapper.class), never()).insert(any(ExecutionCommand.class));
        verifyNoInteractions(dep(GrowthFactApi.class));
    }
    @Test void futureEventRejectsFirstResultWithoutFormalWriteOrGrowth() {
        session(() -> {
            assertTrue(assertThrows(ServiceException.class, () -> service.finalizeResult(7011L, "first-future")).getMessage().contains("尚未开赛"));
            noFormalWrite();
        });
    }
    @Test void futureFixtureRejectsFirstResultEvenWhenEventHasStarted() {
        session(() -> {
            event.setStartsAt(OffsetDateTime.now().minusHours(1)); match.setScheduledStart(OffsetDateTime.now().plusHours(1));
            assertTrue(assertThrows(ServiceException.class, () -> service.finalizeResult(7011L, "future-fixture")).getMessage().contains("本场安排"));
            noFormalWrite();
        });
    }
    @Test void missingEventStartCannotCreateOfficialResult() {
        session(() -> { event.setStartsAt(null); assertThrows(ServiceException.class, () -> service.finalizeResult(7011L, "missing-start")); noFormalWrite(); });
    }
    @Test void ongoingEventCanConfirmResultsBeforePlannedEnd() {
        session(() -> {
            event.setStartsAt(OffsetDateTime.now().minusHours(1)); match.setScheduledStart(OffsetDateTime.now().minusMinutes(1));
            service.finalizeResult(7011L, "ongoing-result"); assertEquals("confirmed", result.getStatus());
            verify(dep(GrowthFactApi.class)).reconcileEvent(901L);
        });
    }
    @Test void endedEventCanStillArrangeExistingResultHistory() {
        session(() -> {
            event.setStartsAt(OffsetDateTime.now().minusHours(3)); event.setEndsAt(OffsetDateTime.now().minusHours(1));
            service.finalizeResult(7011L, "late-result"); assertEquals("confirmed", result.getStatus());
        });
    }
    @Test void alreadyConfirmedHistoryIsNotReclassifiedByNewTimeGuard() {
        session(() -> {
            result.setStatus("confirmed"); service.finalizeResult(7011L, "existing-result");
            verify(dep(CompetitionResultMapper.class), never()).updateById(any(CompetitionResult.class));
        });
    }
    @Test void futureEventRejectsNewAwardWithoutHonorOrCommandWrite() {
        session(() -> {
            when(dep(RegistrationRosterApi.class).approvedRoster("fixture", 701L)).thenReturn(Optional.of(roster()));
            when(dep(CompetitionHonorMapper.class).selectList(any())).thenReturn(List.of());
            assertTrue(assertThrows(ServiceException.class, () -> service.grant(701L, "Champion", "Synthetic confirmed basis", "new-award")).getMessage().contains("尚未开赛"));
            verify(dep(CompetitionHonorMapper.class), never()).insert(any(CompetitionHonor.class));
            verify(dep(ExecutionCommandMapper.class), never()).insert(any(ExecutionCommand.class));
        });
    }
    @Test void existingAwardIsNotHiddenByTheNewStartGuard() {
        session(() -> {
            var honor = new CompetitionHonor(); honor.setId(8111L); honor.setTenantId("fixture");
            honor.setRegistrationId(701L); honor.setPersonId(401L); honor.setAwardKey("existing"); honor.setTitle("Champion");
            when(dep(RegistrationRosterApi.class).approvedRoster("fixture", 701L)).thenReturn(Optional.of(roster()));
            when(dep(CompetitionHonorMapper.class).selectList(any())).thenReturn(List.of(honor));
            assertEquals("existing", service.grant(701L, "Champion", "Original synthetic basis", "existing-award").awardKey());
            verify(dep(CompetitionHonorMapper.class), never()).insert(any(CompetitionHonor.class));
        });
    }
    @Test void ongoingEventCanGrantNewAwardBeforePlannedEnd() {
        session(() -> {
            event.setStartsAt(OffsetDateTime.now().minusHours(1));
            when(dep(RegistrationRosterApi.class).approvedRoster("fixture", 701L)).thenReturn(Optional.of(roster()));
            // MyBatis returns a mutable result list; grant appends newly persisted honor rows.
            when(dep(CompetitionHonorMapper.class).selectList(any())).thenReturn(new ArrayList<>());
            when(dep(org.dromara.sports.platform.core.ScopedJdbc.class).list(anyString(), any(Object[].class)))
                .thenReturn(List.of(Map.of("match_id",7011L,"result_id",8011L,"revision",1L,"status","confirmed")));
            service.grant(701L, "Champion", "Synthetic confirmed basis", "ongoing-award");
            verify(dep(CompetitionHonorMapper.class)).insert(any(CompetitionHonor.class));
        });
    }
    @Test void exactStartAndEquivalentOffsetsAreAllowed() {
        var start = OffsetDateTime.parse("2026-10-11T18:30:00+08:00");
        assertDoesNotThrow(() -> CompetitionService.requireStartWindow(start, start, start.withOffsetSameInstant(java.time.ZoneOffset.UTC)));
    }
    @Test void immediatelyBeforeEitherStartIsRejected() {
        var start = OffsetDateTime.parse("2026-10-11T18:30:00+08:00");
        assertThrows(ServiceException.class, () -> CompetitionService.requireStartWindow(start, null, start.minusNanos(1)));
        assertThrows(ServiceException.class, () -> CompetitionService.requireStartWindow(start.minusHours(1), start, start.minusNanos(1)));
    }
}
