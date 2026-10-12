package org.dromara.sports.registration;

import org.dromara.sports.api.EventRegistrationApi;
import org.dromara.sports.api.EventRegistrationApi.EventRegistrationGate;
import org.dromara.sports.api.FeeApi;
import org.dromara.sports.api.CompetitionTypeApi;
import org.dromara.sports.registration.domain.SportsCompetitionUnit;
import org.dromara.sports.registration.domain.SportsSport;
import org.dromara.sports.registration.domain.DraftRevisionEvent;
import org.dromara.sports.registration.mapper.SportsCapacityPoolMapper;
import org.dromara.sports.registration.mapper.SportsCompetitionUnitMapper;
import org.dromara.sports.registration.mapper.SportsEntryFieldValueMapper;
import org.dromara.sports.registration.mapper.SportsEventFieldMapper;
import org.dromara.sports.registration.mapper.SportsRegistrationMapper;
import org.dromara.sports.registration.mapper.SportsSportMapper;
import org.dromara.sports.registration.service.SportsRegistrationPlaceFreeUnitService;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@Tag("local")
class FreeUnitFromDocumentTest {

    @Test
    void documentUnitIsFreeAndIgnoresCallerPrice() {
        EventRegistrationApi events = mock(EventRegistrationApi.class);
        FeeApi fees = mock(FeeApi.class);
        SportsCompetitionUnitMapper units = mock(SportsCompetitionUnitMapper.class);
        SportsCapacityPoolMapper pools = mock(SportsCapacityPoolMapper.class);
        SportsSportMapper sports = mock(SportsSportMapper.class);
        SportsSport sport = new SportsSport();
        sport.setId(7L);
        when(sports.selectOne(any())).thenReturn(sport);
        when(units.selectCount(any())).thenReturn(0L);
        when(units.insert(any(SportsCompetitionUnit.class))).thenAnswer(invocation -> {
            SportsCompetitionUnit unit = invocation.getArgument(0);
            unit.setId(88L);
            assertEquals("individual", unit.getEntryType());
            assertEquals(1, unit.getMinMembers());
            assertEquals(1, unit.getMaxMembers());
            return 1;
        });
        OffsetDateTime later = OffsetDateTime.now(ZoneOffset.ofHours(8)).plusDays(2);
        when(events.managedGate(4L)).thenReturn(java.util.Optional.of(new EventRegistrationGate(
            4L, "100", 3L, "赛", "draft", "normal", null, null, later, later.plusDays(1), "manual", false)));
        var lockedEvent = new DraftRevisionEvent(); lockedEvent.setId(4L); lockedEvent.setTenantId("100");
        lockedEvent.setOrganizationId(3L); lockedEvent.setHoldingStatus("normal"); lockedEvent.setEndsAt(later.plusDays(1));
        when(units.lockDraftEvent("100", 4L)).thenReturn(lockedEvent);
        var types = mock(CompetitionTypeApi.class);
        when(types.supported(7L, "individual", 1, 1)).thenReturn(java.util.Optional.of(71L));
        SportsRegistrationPlaceFreeUnitService service = new SportsRegistrationPlaceFreeUnitService(events, fees, units, pools, sports, mock(SportsRegistrationMapper.class), mock(SportsEventFieldMapper.class), mock(SportsEntryFieldValueMapper.class), types);
        long unitId = service.placeFreeUnit(4L, "男子单打", "individual", 9, 9, 32);
        assertEquals(88L, unitId);
        verify(fees).placeInitialPolicy(eq("100"), eq(88L), eq(new BigDecimal("0.00")), eq("free"), isNull(), isNull());
    }
}
