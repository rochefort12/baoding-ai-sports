package org.dromara.sports.registration;

import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.api.*;
import org.dromara.sports.registration.domain.*;
import org.dromara.sports.registration.mapper.*;
import org.dromara.sports.registration.service.SportsRegistrationPlaceFreeUnitService;
import org.junit.jupiter.api.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 清理顺序及拒绝报名、名额、采集值历史；事务和真实资金另验。 */
@Tag("local")
class DraftUnitDeletionTest {
    final EventRegistrationApi events = mock(EventRegistrationApi.class);
    final FeeApi fees = mock(FeeApi.class);
    final SportsCompetitionUnitMapper units = mock(SportsCompetitionUnitMapper.class);
    final SportsCapacityPoolMapper pools = mock(SportsCapacityPoolMapper.class);
    final SportsRegistrationMapper registrations = mock(SportsRegistrationMapper.class);
    final SportsEventFieldMapper fields = mock(SportsEventFieldMapper.class);
    final SportsEntryFieldValueMapper values = mock(SportsEntryFieldValueMapper.class);
    final SportsRegistrationPlaceFreeUnitService service = new SportsRegistrationPlaceFreeUnitService(
        events, fees, units, pools, mock(SportsSportMapper.class), registrations, fields, values, mock(CompetitionTypeApi.class));
    @BeforeEach void setup() {
        when(events.managedGate(91L)).thenReturn(Optional.of(new EventRegistrationApi.EventRegistrationGate(
            91L, "fixture", 61L, "合成赛事", "draft", "normal", null, null, null, null, "none", false)));
        var unit = new SportsCompetitionUnit(); unit.setId(51L); unit.setEventId(91L);
        when(units.selectList(any())).thenReturn(List.of(unit));
        when(registrations.selectCount(any())).thenReturn(0L);
        var pool = new SportsCapacityPool(); pool.setUsedCount(0);
        when(pools.selectOne(any())).thenReturn(pool);
        var field = new SportsEventField(); field.setId(81L);
        when(fields.selectList(any())).thenReturn(List.of(field));
        when(values.selectCount(any())).thenReturn(0L);
    }
    private void rejected() {
        assertThrows(ServiceException.class, () -> service.discardEmptyDraftUnits(91L));
        verifyNoInteractions(fees);
        verify(fields, never()).deleteById(anyLong());
        verify(pools, never()).delete(any());
        verify(units, never()).deleteById(anyLong());
    }
    @Test void unusedPricingIsCleanedBeforeDeletingConfigurationAndUnitForeignKeys() {
        service.discardEmptyDraftUnits(91L);
        var order = inOrder(fees, fields, pools, units);
        order.verify(fees).discardUnusedDraftPricing("fixture", 91L);
        order.verify(fields).deleteById(81L);
        order.verify(pools).delete(any());
        order.verify(units).deleteById(51L);
        verify(fees, never()).publicUnitPrices(anyString(), anyLong());
    }
    @Test void registrationHistoryPreventsAllCleanup() {
        when(registrations.selectCount(any())).thenReturn(1L); rejected();
    }
    @Test void occupiedCapacityPreventsAllCleanup() {
        var used = new SportsCapacityPool(); used.setUsedCount(1);
        when(pools.selectOne(any())).thenReturn(used); rejected();
    }
    @Test void collectedParticipantDataPreventsAllCleanup() {
        when(values.selectCount(any())).thenReturn(1L); rejected();
    }
}
