package org.dromara.sports.registration;
import org.dromara.sports.api.*;
import org.dromara.sports.registration.domain.*;
import org.dromara.sports.registration.mapper.*;
import org.dromara.sports.registration.service.SportsRegistrationPlaceFreeUnitService;
import org.junit.jupiter.api.*;
import java.time.OffsetDateTime;
import java.util.Optional;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;
/** AI候选费用必须人工确认，不能从文字说明自动生成有效免费规则。 */
@Tag("local")
class AiUnpricedUnitTest {
    @Test void aiUnitDoesNotInstallAFreeFeePolicy() {
        var events=mock(EventRegistrationApi.class);var fees=mock(FeeApi.class);
        var units=mock(SportsCompetitionUnitMapper.class);var pools=mock(SportsCapacityPoolMapper.class);var sports=mock(SportsSportMapper.class);
        var sport=new SportsSport();sport.setId(101L);when(sports.selectOne(any())).thenReturn(sport);
        var types=mock(CompetitionTypeApi.class);when(types.supported(101L,"individual",1,1)).thenReturn(Optional.of(401L));
        when(events.managedGate(901L)).thenReturn(Optional.of(new EventRegistrationApi.EventRegistrationGate(901L,"fixture",601L,"赛事","draft","normal",null,null,null,OffsetDateTime.now().plusDays(1),"manual",false)));
        when(units.lockDraftEvent("fixture", 901L)).thenReturn(lockedEvent());
        doAnswer(call->{((SportsCompetitionUnit)call.getArgument(0)).setId(501L);return 1;}).when(units).insert(any(SportsCompetitionUnit.class));
        var service=new SportsRegistrationPlaceFreeUnitService(events,fees,units,pools,sports,mock(SportsRegistrationMapper.class),mock(SportsEventFieldMapper.class),mock(SportsEntryFieldValueMapper.class),types);
        assertEquals(501L,service.placeUnpricedUnit(901L,"候选项目","individual",1,1,8));
        verifyNoInteractions(fees);verify(pools).insert(any(SportsCapacityPool.class));
        verify(units).insert(argThat((SportsCompetitionUnit u)->u.getCompetitionTypeId().equals(401L)));
    }
    @Test void unsupportedTypeCannotLeaveAUnitOrCapacity() {
        var events=mock(EventRegistrationApi.class);var fees=mock(FeeApi.class);var types=mock(CompetitionTypeApi.class);
        var units=mock(SportsCompetitionUnitMapper.class);var pools=mock(SportsCapacityPoolMapper.class);var sports=mock(SportsSportMapper.class);
        var sport=new SportsSport();sport.setId(101L);when(sports.selectOne(any())).thenReturn(sport);
        when(events.managedGate(901L)).thenReturn(Optional.of(new EventRegistrationApi.EventRegistrationGate(901L,"fixture",601L,"赛事","draft","normal",null,null,null,OffsetDateTime.now().plusDays(1),"manual",false)));
        when(units.lockDraftEvent("fixture", 901L)).thenReturn(lockedEvent());
        when(types.supported(101L,"team",3,5)).thenReturn(Optional.empty());
        var service=new SportsRegistrationPlaceFreeUnitService(events,fees,units,pools,sports,mock(SportsRegistrationMapper.class),mock(SportsEventFieldMapper.class),mock(SportsEntryFieldValueMapper.class),types);
        assertThrows(org.dromara.common.core.exception.ServiceException.class,()->service.placeUnpricedUnit(901L,"未开放团体","team",3,5,8));
        verify(units,never()).insert(any(SportsCompetitionUnit.class));verifyNoInteractions(pools,fees);
    }
    private DraftRevisionEvent lockedEvent() {
        var event = new DraftRevisionEvent(); event.setId(901L); event.setTenantId("fixture");
        event.setOrganizationId(601L); event.setPublicationStatus("draft"); event.setHoldingStatus("normal");
        event.setEndsAt(OffsetDateTime.now().plusDays(1)); return event;
    }
}
