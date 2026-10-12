package org.dromara.sports.competition;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.core.lock.MutualLock;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.OrganizationQualificationApi;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.competition.domain.CompetitionEvent;
import org.dromara.sports.competition.domain.CompetitionUnit;
import org.dromara.sports.competition.mapper.*;
import org.dromara.sports.competition.service.CompetitionService;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.TransactionStatus;
import java.time.OffsetDateTime;
import java.util.*;
import java.util.function.Supplier;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 结束赛事直接调用服务也不能新增报到或场次；保留已有赛果整理的独立路径。 */
@Tag("local")
class CompetitionEndWindowTest {
    private final Map<Class<?>, Object> dependencies = new HashMap<>();
    private final CompetitionService service = create();
    private CompetitionService create() {
        try {
            var constructor = CompetitionService.class.getDeclaredConstructors()[0];
            return (CompetitionService) constructor.newInstance(Arrays.stream(constructor.getParameterTypes()).map(type -> {
                Object dependency = type == ObjectMapper.class ? new ObjectMapper() : mock(type);
                dependencies.put(type, dependency); return dependency;
            }).toArray());
        } catch (ReflectiveOperationException exception) { throw new AssertionError(exception); }
    }
    private <T> T dependency(Class<T> type) { return type.cast(dependencies.get(type)); }
    private void run(Runnable assertion) {
        when(dependency(OrganizationSessionApi.class).managedOrganization(201L)).thenReturn(Optional.of(
            new OrganizationSessionApi.ManagedOrganization(601L, "隔离组织", "fixture", 301L)));
        when(dependency(OrganizationQualificationApi.class).hasStaffAction("fixture", 601L, 301L, "organize")).thenReturn(true);
        var event = new CompetitionEvent(); event.setId(901L); event.setOrganizationId(601L);
        event.setTenantId("fixture"); event.setHoldingStatus("normal"); event.setEndsAt(OffsetDateTime.now().minusHours(1));
        when(dependency(CompetitionEventMapper.class).selectById(901L)).thenReturn(event);
        var unit = new CompetitionUnit(); unit.setId(501L); unit.setEventId(901L);
        when(dependency(CompetitionUnitMapper.class).selectById(501L)).thenReturn(unit);
        when(dependency(PlatformTransactionManager.class).getTransaction(any(TransactionDefinition.class))).thenReturn(mock(TransactionStatus.class));
        when(dependency(MutualLock.class).execute(anyString(), anyLong(), anyLong(), any(Supplier.class)))
            .thenAnswer(invocation -> ((Supplier<?>) invocation.getArgument(3)).get());
        try (var login = mockStatic(LoginHelper.class); var tenant = mockStatic(TenantHelper.class)) {
            login.when(LoginHelper::getUserId).thenReturn(201L);
            tenant.when(() -> TenantHelper.dynamic(eq("fixture"), any(Supplier.class)))
                .thenAnswer(invocation -> ((Supplier<?>) invocation.getArgument(1)).get());
            assertion.run();
        }
    }
    @Test void endedEventCannotAddCheckin() {
        run(() -> {
            assertTrue(assertThrows(ServiceException.class, () -> service.checkIn(901L, 401L, "fixture-checkin")).getMessage().contains("赛事已结束"));
            verifyNoInteractions(dependency(CompetitionCheckinMapper.class), dependency(ExecutionCommandMapper.class));
        });
    }
    @Test void endedEventCannotAddMatch() {
        run(() -> {
            assertTrue(assertThrows(ServiceException.class, () -> service.createMatch(501L, "fixture-match", 701L, 702L, "fixture-key")).getMessage().contains("赛事已结束"));
            verifyNoInteractions(dependency(CompetitionMatchMapper.class), dependency(ExecutionCommandMapper.class));
        });
    }
}
