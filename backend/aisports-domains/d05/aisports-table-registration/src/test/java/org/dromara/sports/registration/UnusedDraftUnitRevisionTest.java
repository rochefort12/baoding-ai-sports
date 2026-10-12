package org.dromara.sports.registration;

import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.api.*;
import org.dromara.sports.platform.core.BusinessIdentity;
import org.dromara.sports.registration.domain.*;
import org.dromara.sports.registration.mapper.*;
import org.dromara.sports.registration.service.SportsRegistrationPlaceFreeUnitService;
import org.junit.jupiter.api.*;
import org.mockito.ArgumentCaptor;

import java.util.*;
import java.util.function.Supplier;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 模拟仅验证草稿归属、历史拒绝及稳定编号；真实数据库事务和普通角色另验。 */
@Tag("local")
class UnusedDraftUnitRevisionTest {
    private final EventRegistrationApi events = mock(EventRegistrationApi.class);
    private final FeeApi fees = mock(FeeApi.class);
    private final SportsCompetitionUnitMapper units = mock(SportsCompetitionUnitMapper.class);
    private final SportsCapacityPoolMapper pools = mock(SportsCapacityPoolMapper.class);
    private final CompetitionTypeApi types = mock(CompetitionTypeApi.class);
    private final SportsRegistrationPlaceFreeUnitService service = new SportsRegistrationPlaceFreeUnitService(
        events, fees, units, pools, mock(SportsSportMapper.class), mock(SportsRegistrationMapper.class),
        mock(SportsEventFieldMapper.class), mock(SportsEntryFieldValueMapper.class), types);
    private final DraftRevisionEvent event = new DraftRevisionEvent();
    private final SportsCompetitionUnit unit = new SportsCompetitionUnit();
    private final SportsCapacityPool pool = new SportsCapacityPool();

    @BeforeEach void setup() {
        event.setId(91L); event.setTenantId("fixture"); event.setOrganizationId(61L);
        event.setPublicationStatus("draft"); event.setHoldingStatus("normal");
        event.setRegistrationReviewLocked(false); event.setPublishedRevision(0);
        when(events.managedGate(91L)).thenReturn(Optional.of(new EventRegistrationApi.EventRegistrationGate(
            91L, "fixture", 61L, "合成赛事", "draft", "normal", null, null, null, null, "none", false)));
        when(units.lockDraftEvent("fixture", 91L)).thenReturn(event);
        unit.setId(51L); unit.setTenantId("fixture"); unit.setEventId(91L); unit.setSportId(101L);
        unit.setName("原项目"); unit.setEntryType("individual"); unit.setMinMembers(1); unit.setMaxMembers(1);
        unit.setCompetitionTypeId(401L); unit.setStatus("open"); unit.setVersion(2);
        when(units.selectOne(any())).thenReturn(unit); when(units.selectList(any())).thenReturn(List.of(unit));
        when(units.selectCount(any())).thenReturn(0L); when(units.updateById(any(SportsCompetitionUnit.class))).thenReturn(1);
        pool.setId(71L); pool.setTenantId("fixture"); pool.setEventId(91L); pool.setUnitId(51L);
        pool.setCapacityUnit("entry"); pool.setDedupeScope("entry"); pool.setLimitCount(8);
        pool.setUsedCount(0); pool.setStatus("active"); pool.setVersion(3);
        when(pools.selectOne(any())).thenReturn(pool); when(pools.updateById(any(SportsCapacityPool.class))).thenReturn(1);
        when(types.supported(101L, "individual", 1, 1)).thenReturn(Optional.of(401L));
        when(types.supported(101L, "pair", 2, 2)).thenReturn(Optional.of(402L));
    }

    private <T> T owned(Supplier<T> work) {
        try (var identity = mockStatic(BusinessIdentity.class)) {
            identity.when(BusinessIdentity::getTenantId).thenReturn("fixture");
            return work.get();
        }
    }
    private void revise(String name, String type, int limit) {
        owned(() -> { service.updateUnusedDraftUnit(91L, 51L, name, type, 99, 99, limit); return null; });
        verify(units, never()).insert(any(SportsCompetitionUnit.class));
        verify(pools, never()).insert(any(SportsCapacityPool.class));
        verify(units, never()).deleteById(anyLong()); verify(pools, never()).delete(any());
        verifyNoInteractions(fees);
    }
    private void rejected() {
        owned(() -> assertThrows(ServiceException.class,
            () -> service.updateUnusedDraftUnit(91L, 51L, "新项目", "individual", 1, 1, 32)));
        verify(units, never()).updateById(any(SportsCompetitionUnit.class));
        verify(pools, never()).updateById(any(SportsCapacityPool.class));
        verifyNoInteractions(fees);
    }
    @Test void revisionPreservesUnitAndCapacityIdsAndUsesFixedDoublesBounds() {
        revise(" 男双 ", "pair", 32);
        var savedUnit = ArgumentCaptor.forClass(SportsCompetitionUnit.class);
        var savedPool = ArgumentCaptor.forClass(SportsCapacityPool.class);
        verify(units).updateById(savedUnit.capture()); verify(pools).updateById(savedPool.capture());
        assertEquals(51L, savedUnit.getValue().getId()); assertEquals("男双", unit.getName());
        assertEquals(2, unit.getMinMembers()); assertEquals(2, unit.getMaxMembers()); assertEquals(402L, unit.getCompetitionTypeId());
        assertEquals(71L, savedPool.getValue().getId()); assertEquals(32, pool.getLimitCount()); assertEquals(0, pool.getUsedCount());
        var order = inOrder(units, pools);
        order.verify(units).lockDraftEvent("fixture", 91L);
        order.verify(units).hasDraftBusinessHistory("fixture", 91L);
        order.verify(units).selectOne(any()); order.verify(pools).selectOne(any());
        order.verify(units).selectCount(any()); order.verify(units).updateById(any(SportsCompetitionUnit.class));
        order.verify(pools).updateById(any(SportsCapacityPool.class));
    }
    @Test void unchangedRevisionDoesNotWriteVersions() {
        revise("原项目", "individual", 8);
        verify(units, never()).updateById(any(SportsCompetitionUnit.class));
        verify(pools, never()).updateById(any(SportsCapacityPool.class));
    }
    @Test void currentCatalogCarriesActualIdsAndCapacity() {
        assertEquals(List.of(new CompetitionSetupApi.DraftUnit(51L, "原项目", "individual", 1, 1, 8, "open", "active")),
            owned(() -> service.currentDraftUnits(91L)));
    }
    @Test void historyAlsoBlocksCatalogBeforeAnyEventFieldCanBeSaved() {
        when(units.hasDraftBusinessHistory("fixture", 91L)).thenReturn(true);
        owned(() -> assertThrows(ServiceException.class, () -> service.currentDraftUnits(91L)));
        verify(units, never()).selectList(any()); rejected();
    }
    @Test void pastPublishedRevisionAndSubmissionLockEachRejectChanges() {
        event.setPublishedRevision(1); rejected();
        event.setPublishedRevision(0); event.setRegistrationReviewLocked(true); rejected();
    }
    @Test void offlinePublishedOrCancelledEventCannotBeRevised() {
        event.setPublicationStatus("published"); rejected();
        event.setPublicationStatus("offline"); rejected();
        event.setPublicationStatus("draft"); event.setHoldingStatus("cancelled"); rejected();
    }
    @Test void organizationAndTenantAreCheckedAgainUnderEventLock() {
        event.setOrganizationId(999L); rejected();
        event.setOrganizationId(61L); event.setTenantId("other"); rejected();
    }
    @Test void anotherEventsUnitAndAnotherTenantsUnitEachRejectChanges() {
        unit.setEventId(92L); rejected(); unit.setEventId(91L); unit.setTenantId("other"); rejected();
    }
    @Test void evenEmptyUnitCannotChangeAnOccupiedOrMissingCapacity() {
        pool.setUsedCount(1); rejected();
        pool.setUsedCount(0); when(pools.selectOne(any())).thenReturn(null); rejected();
    }
    @Test void unsupportedTeamDuplicateNameAndInvalidCapacityCannotWrite() {
        owned(() -> assertThrows(ServiceException.class,
            () -> service.updateUnusedDraftUnit(91L, 51L, "团体", "team", 3, 4, 32)));
        owned(() -> assertThrows(ServiceException.class,
            () -> service.updateUnusedDraftUnit(91L, 51L, "新项目", "individual", 1, 1, 0)));
        when(units.selectCount(any())).thenReturn(1L); rejected();
    }
    @Test void staleUnitWritePreventsCapacityWrite() {
        when(units.updateById(any(SportsCompetitionUnit.class))).thenReturn(0);
        owned(() -> assertThrows(ServiceException.class,
            () -> service.updateUnusedDraftUnit(91L, 51L, "新项目", "individual", 1, 1, 32)));
        verify(pools, never()).updateById(any(SportsCapacityPool.class));
    }
    @Test void publicationCatalogIncludesExistingOccupationAndHistoryWithoutDraftEditPermission() {
        event.setPublicationStatus("published"); event.setPublishedRevision(3); event.setRegistrationReviewLocked(true);
        when(units.hasDraftBusinessHistory("fixture", 91L)).thenReturn(true); pool.setUsedCount(5);
        assertEquals(List.of(new CompetitionSetupApi.DraftUnit(51L, "原项目", "individual", 1, 1, 8, "open", "active")),
            owned(() -> service.publicationUnits(91L)));
        verify(units, never()).hasDraftBusinessHistory(anyString(), anyLong());
        verify(units, never()).updateById(any(SportsCompetitionUnit.class));
        verify(pools, never()).updateById(any(SportsCapacityPool.class));
        verifyNoInteractions(fees);
    }
    @Test void publicationCatalogRetainsClosedUnitsAndInactiveCapacityForItsFingerprint() {
        event.setPublicationStatus("offline"); unit.setStatus("closed"); pool.setStatus("inactive");
        assertEquals(51L, owned(() -> service.publicationUnits(91L)).get(0).unitId());
        assertEquals(8, owned(() -> service.publicationUnits(91L)).get(0).limitCount());
        assertEquals("closed", owned(() -> service.publicationUnits(91L)).get(0).status());
        assertEquals("inactive", owned(() -> service.publicationUnits(91L)).get(0).capacityStatus());
    }
    @Test void publicationCatalogRejectsOtherOrganizationsCancelledEventsAndMissingCapacity() {
        event.setOrganizationId(999L);
        owned(() -> assertThrows(ServiceException.class, () -> service.publicationUnits(91L)));
        event.setOrganizationId(61L); event.setHoldingStatus("cancelled");
        owned(() -> assertThrows(ServiceException.class, () -> service.publicationUnits(91L)));
        event.setHoldingStatus("normal"); when(pools.selectOne(any())).thenReturn(null);
        owned(() -> assertThrows(ServiceException.class, () -> service.publicationUnits(91L)));
    }
    @Test void statusOnlyChangesAreVisibleInPublicationSnapshotEquality() {
        var open = owned(() -> service.publicationUnits(91L)).get(0);
        unit.setStatus("closed");
        var closed = owned(() -> service.publicationUnits(91L)).get(0);
        assertNotEquals(open, closed); assertEquals(open.unitId(), closed.unitId());
        assertEquals(open.name(), closed.name()); assertEquals(open.limitCount(), closed.limitCount());
        pool.setStatus("inactive");
        var inactive = owned(() -> service.publicationUnits(91L)).get(0);
        assertNotEquals(closed, inactive); assertEquals(closed.status(), inactive.status());
        assertEquals("inactive", inactive.capacityStatus());
    }
}
