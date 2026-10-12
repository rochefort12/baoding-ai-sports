package org.dromara.sports.registration;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.core.lock.MutualLock;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.*;
import org.dromara.sports.platform.core.BusinessIdentity;
import org.dromara.sports.registration.domain.*;
import org.dromara.sports.registration.mapper.*;
import org.dromara.sports.registration.service.RegistrationService;
import org.dromara.sports.registration.service.SportsRegistrationPlaceFreeUnitService;
import org.junit.jupiter.api.*;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionStatus;

import java.time.OffsetDateTime;
import java.util.*;
import java.util.function.Supplier;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 模拟入口证明每次目录/容量写入先取赛事锁；不替代真实 PostgreSQL 并发验证。 */
@Tag("local")
class CatalogMutationEventLockTest {
    private final Map<Class<?>, Object> dependencies = new HashMap<>();
    private final RegistrationService service = create();
    private final DraftRevisionEvent event = new DraftRevisionEvent();
    private final SportsCompetitionUnit unit = new SportsCompetitionUnit();
    private final SportsCapacityPool pool = new SportsCapacityPool();
    private <T> T dep(Class<T> type) { return type.cast(dependencies.get(type)); }
    private RegistrationService create() {
        try {
            var constructor = RegistrationService.class.getDeclaredConstructors()[0];
            return (RegistrationService) constructor.newInstance(Arrays.stream(constructor.getParameterTypes()).map(type -> {
                Object value = type == ObjectMapper.class ? new ObjectMapper() : mock(type);
                dependencies.put(type, value); return value;
            }).toArray());
        } catch (ReflectiveOperationException failure) { throw new AssertionError(failure); }
    }
    @BeforeEach void setup() {
        event.setId(91L); event.setTenantId("fixture"); event.setOrganizationId(61L);
        event.setPublicationStatus("draft"); event.setHoldingStatus("normal"); event.setPublishedRevision(0);
        event.setRegistrationReviewLocked(false); event.setEndsAt(OffsetDateTime.now().plusDays(2));
        unit.setId(51L); unit.setEventId(91L); unit.setTenantId("fixture"); unit.setSportId(101L);
        unit.setName("原项目"); unit.setEntryType("individual"); unit.setMinMembers(1); unit.setMaxMembers(1);
        unit.setCompetitionTypeId(401L); unit.setStatus("open"); unit.setVersion(0);
        pool.setId(71L); pool.setTenantId("fixture"); pool.setEventId(91L); pool.setUnitId(51L);
        pool.setCapacityUnit("entry"); pool.setDedupeScope("entry"); pool.setStatus("active");
        pool.setLimitCount(8); pool.setUsedCount(0); pool.setVersion(0);
        when(dep(EventRegistrationApi.class).managedGate(91L)).thenReturn(Optional.of(
            new EventRegistrationApi.EventRegistrationGate(91L, "fixture", 61L, "合成赛事", "draft", "normal",
                null, null, null, OffsetDateTime.now().plusDays(2), "none", false)));
        when(dep(EventRegistrationApi.class).acceptsNewBusiness(91L)).thenReturn(true);
        when(dep(OrganizationSessionApi.class).managedOrganization(9L)).thenReturn(Optional.of(
            new OrganizationSessionApi.ManagedOrganization(61L, "合成组织", "fixture", 8L)));
        when(dep(SportsCompetitionUnitMapper.class).lockDraftEvent("fixture", 91L)).thenReturn(event);
        when(dep(SportsCompetitionUnitMapper.class).selectById(51L)).thenReturn(unit);
        when(dep(SportsCompetitionUnitMapper.class).selectCount(any())).thenReturn(0L);
        when(dep(SportsCompetitionUnitMapper.class).updateById(any(SportsCompetitionUnit.class))).thenReturn(1);
        when(dep(SportsCompetitionUnitMapper.class).insert(any(SportsCompetitionUnit.class)))
            .thenAnswer(call -> { ((SportsCompetitionUnit) call.getArgument(0)).setId(52L); return 1; });
        when(dep(SportsCapacityPoolMapper.class).selectOne(any())).thenReturn(pool);
        when(dep(SportsCapacityPoolMapper.class).selectById(71L)).thenReturn(pool);
        when(dep(SportsCapacityPoolMapper.class).updateById(any(SportsCapacityPool.class))).thenReturn(1);
        when(dep(SportsCapacityPoolMapper.class).insert(any(SportsCapacityPool.class)))
            .thenAnswer(call -> { ((SportsCapacityPool) call.getArgument(0)).setId(72L); return 1; });
        when(dep(SportsRegistrationMapper.class).selectCount(any())).thenReturn(0L);
        var sport = new SportsSport(); sport.setId(101L);
        when(dep(SportsSportMapper.class).selectOne(any())).thenReturn(sport);
        when(dep(CompetitionTypeApi.class).supported(101L, "individual", 1, 1)).thenReturn(Optional.of(401L));
        when(dep(PlatformTransactionManager.class).getTransaction(any())).thenReturn(mock(TransactionStatus.class));
        when(dep(MutualLock.class).execute(anyString(), anyLong(), anyLong(), any(Supplier.class)))
            .thenAnswer(call -> ((Supplier<?>) call.getArgument(3)).get());
    }
    private <T> T owned(Supplier<T> work) {
        try (var identity = mockStatic(BusinessIdentity.class); var tenant = mockStatic(TenantHelper.class)) {
            identity.when(BusinessIdentity::getUserId).thenReturn(9L);
            identity.when(BusinessIdentity::getTenantId).thenReturn("fixture");
            tenant.when(() -> TenantHelper.dynamic(eq("fixture"), any(Supplier.class)))
                .thenAnswer(call -> ((Supplier<?>) call.getArgument(1)).get());
            return work.get();
        }
    }
    private RegistrationService.UnitDraft draft() {
        return new RegistrationService.UnitDraft(91L, "新项目", "individual", 1, 1, 32,
            "synthetic-request", false, null, null, null, null);
    }
    private SportsRegistrationPlaceFreeUnitService bridge() {
        return new SportsRegistrationPlaceFreeUnitService(dep(EventRegistrationApi.class), dep(FeeApi.class),
            dep(SportsCompetitionUnitMapper.class), dep(SportsCapacityPoolMapper.class), dep(SportsSportMapper.class),
            dep(SportsRegistrationMapper.class), mock(SportsEventFieldMapper.class), mock(SportsEntryFieldValueMapper.class), dep(CompetitionTypeApi.class));
    }
    private void noCatalogWrites() {
        verify(dep(SportsCompetitionUnitMapper.class), never()).insert(any(SportsCompetitionUnit.class));
        verify(dep(SportsCompetitionUnitMapper.class), never()).updateById(any(SportsCompetitionUnit.class));
        verify(dep(SportsCapacityPoolMapper.class), never()).insert(any(SportsCapacityPool.class));
        verify(dep(SportsCapacityPoolMapper.class), never()).updateById(any(SportsCapacityPool.class));
        verifyNoInteractions(dep(FeeApi.class));
    }
    @Test void workspaceCreateLocksEventBeforeIdempotencyAndAllUnitCapacityPriceWrites() {
        assertEquals(52L, owned(() -> service.createUnit(draft())).id());
        var order = inOrder(dep(SportsCompetitionUnitMapper.class), dep(SportsRegistrationIdempotencyMapper.class),
            dep(SportsCapacityPoolMapper.class), dep(FeeApi.class));
        order.verify(dep(SportsCompetitionUnitMapper.class)).lockDraftEvent("fixture", 91L);
        order.verify(dep(SportsRegistrationIdempotencyMapper.class)).selectOne(any());
        order.verify(dep(SportsCompetitionUnitMapper.class)).selectCount(any());
        order.verify(dep(SportsCompetitionUnitMapper.class)).insert(any(SportsCompetitionUnit.class));
        order.verify(dep(SportsCapacityPoolMapper.class)).insert(any(SportsCapacityPool.class));
        order.verify(dep(FeeApi.class)).placeInitialPolicy(eq("fixture"), eq(52L), any(), eq("free"), any(), isNull());
    }
    @Test void workspaceUpdateLocksEventBeforeReReadingAndChangingCurrentUnit() {
        owned(() -> service.updateUnit(51L, "新名称", "individual", 1, 1, false));
        var order = inOrder(dep(SportsCompetitionUnitMapper.class));
        order.verify(dep(SportsCompetitionUnitMapper.class)).selectById(51L);
        order.verify(dep(SportsCompetitionUnitMapper.class)).lockDraftEvent("fixture", 91L);
        order.verify(dep(SportsCompetitionUnitMapper.class)).selectById(51L);
        order.verify(dep(SportsCompetitionUnitMapper.class)).selectCount(any());
        order.verify(dep(SportsCompetitionUnitMapper.class)).updateById(unit);
        assertEquals("新名称", unit.getName());
    }
    @Test void workspaceLimitLocksEventBeforeCapacityAndRetainsAudit() {
        owned(() -> service.adjustLimit(51L, 32));
        var order = inOrder(dep(SportsCompetitionUnitMapper.class), dep(SportsCapacityPoolMapper.class), dep(SportsAuditEventMapper.class));
        order.verify(dep(SportsCompetitionUnitMapper.class)).lockDraftEvent("fixture", 91L);
        order.verify(dep(SportsCapacityPoolMapper.class)).selectOne(any());
        order.verify(dep(SportsCapacityPoolMapper.class)).updateById(pool);
        order.verify(dep(SportsAuditEventMapper.class)).insert(any(SportsAuditEvent.class));
        assertEquals(32, pool.getLimitCount());
    }
    @Test void unpricedCreationLocksEventBeforeAnyUnitOrCapacityInsert() {
        assertEquals(52L, bridge().placeUnpricedUnit(91L, "AI项目", "individual", 1, 1, 32));
        var order = inOrder(dep(SportsCompetitionUnitMapper.class), dep(SportsCapacityPoolMapper.class));
        order.verify(dep(SportsCompetitionUnitMapper.class)).lockDraftEvent("fixture", 91L);
        order.verify(dep(SportsCompetitionUnitMapper.class)).selectCount(any());
        order.verify(dep(SportsCompetitionUnitMapper.class)).insert(any(SportsCompetitionUnit.class));
        order.verify(dep(SportsCapacityPoolMapper.class)).insert(any(SportsCapacityPool.class));
        verifyNoInteractions(dep(FeeApi.class));
    }
    @Test void freeCreationLocksEventBeforeInitialPriceAndCreatesNoStandaloneTransaction() {
        assertEquals(52L, bridge().placeFreeUnit(91L, "免费项目", "individual", 1, 1, 32));
        var order = inOrder(dep(SportsCompetitionUnitMapper.class), dep(FeeApi.class));
        order.verify(dep(SportsCompetitionUnitMapper.class)).lockDraftEvent("fixture", 91L);
        order.verify(dep(SportsCompetitionUnitMapper.class)).insert(any(SportsCompetitionUnit.class));
        order.verify(dep(FeeApi.class)).placeInitialPolicy(eq("fixture"), eq(52L), any(), eq("free"), isNull(), isNull());
        verifyNoInteractions(dep(PlatformTransactionManager.class), dep(MutualLock.class));
    }
    @Test void staleAuthorizedGateCannotWriteWhenEventLockIsMissingOrChangedOwner() {
        when(dep(SportsCompetitionUnitMapper.class).lockDraftEvent("fixture", 91L)).thenReturn(null);
        owned(() -> {
            assertThrows(ServiceException.class, () -> service.createUnit(draft()));
            assertThrows(ServiceException.class, () -> service.updateUnit(51L, "新名称", "individual", 1, 1, false));
            assertThrows(ServiceException.class, () -> service.adjustLimit(51L, 32));
            return null;
        });
        assertThrows(ServiceException.class, () -> bridge().placeUnpricedUnit(91L, "AI项目", "individual", 1, 1, 32));
        noCatalogWrites();
    }
    @Test void cancellationAfterInitialGateReadPreventsAllNewCatalogWrites() {
        event.setHoldingStatus("cancelled");
        owned(() -> { assertThrows(ServiceException.class, () -> service.createUnit(draft())); return null; });
        assertThrows(ServiceException.class, () -> bridge().placeFreeUnit(91L, "AI项目", "individual", 1, 1, 32));
        noCatalogWrites();
    }
    @Test void existingCapacityFloorStillRejectsBelowOccupiedEntries() {
        pool.setUsedCount(5);
        owned(() -> { assertThrows(ServiceException.class, () -> service.adjustLimit(51L, 4)); return null; });
        noCatalogWrites();
        verify(dep(SportsCompetitionUnitMapper.class)).lockDraftEvent("fixture", 91L);
    }
}
