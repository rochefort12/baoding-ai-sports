package org.dromara.sports.event.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.sports.api.*;
import org.dromara.sports.event.domain.*;
import org.dromara.sports.event.mapper.*;
import org.junit.jupiter.api.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 删除仅限当前组织从未发布草稿；真实事务回滚及配置外键由接口/数据库验收。 */
@Tag("local")
class EventDraftDeletionTest {
    private final Map<Class<?>, Object> dependencies = new HashMap<>();
    private final EventPublicationService service = create();
    private final SportsEvent event = new SportsEvent();
    private <T> T dep(Class<T> type) { return type.cast(dependencies.get(type)); }
    private EventPublicationService create() {
        try {
            var constructor = EventPublicationService.class.getDeclaredConstructors()[0];
            return (EventPublicationService) constructor.newInstance(Arrays.stream(constructor.getParameterTypes()).map(type -> {
                Object value = type == ObjectMapper.class ? new ObjectMapper() : mock(type);
                dependencies.put(type, value); return value;
            }).toArray());
        } catch (ReflectiveOperationException failure) { throw new AssertionError(failure); }
    }
    @BeforeEach void setup() {
        event.setId(91L); event.setTenantId("fixture"); event.setOrganizationId(61L);
        event.setPublicationStatus("draft"); event.setHoldingStatus("normal");
        when(dep(SportsEventMapper.class).selectOne(any())).thenReturn(event);
        when(dep(SportsEventMapper.class).deleteById(91L)).thenReturn(1);
        when(dep(SportsEventCommandMapper.class).selectCount(any())).thenReturn(0L);
        when(dep(SportsAiTaskMapper.class).selectList(any())).thenReturn(List.of());
        when(dep(OrganizationSessionApi.class).managedOrganization(21L)).thenReturn(Optional.of(
            new OrganizationSessionApi.ManagedOrganization(61L, "合成组织", "fixture", 31L)));
    }
    private void run(Runnable work) {
        try (var login = mockStatic(LoginHelper.class)) {
            login.when(LoginHelper::isLogin).thenReturn(true); login.when(LoginHelper::getUserType).thenReturn(UserType.SYS_USER);
            login.when(LoginHelper::getUserId).thenReturn(21L); login.when(LoginHelper::getTenantId).thenReturn("fixture");
            work.run();
        }
    }
    private void rejected() {
        run(() -> assertThrows(ServiceException.class, () -> service.deleteDraft(91L)));
        verifyNoInteractions(dep(CompetitionSetupApi.class), dep(SportsEventPosterMapper.class), dep(SportsAiTaskMapper.class));
        verify(dep(SportsEventMapper.class), never()).deleteById(anyLong());
    }
    @Test void onlySuccessfulDependencyCleanupCanDeleteTheEvent() {
        run(() -> service.deleteDraft(91L));
        var order = inOrder(dep(CompetitionSetupApi.class), dep(SportsEventMapper.class));
        order.verify(dep(CompetitionSetupApi.class)).discardEmptyDraftUnits(91L);
        order.verify(dep(SportsEventMapper.class)).deleteById(91L);
    }
    @Test void existingPublicationCommandPreventsDeletingARevertedDraft() {
        when(dep(SportsEventCommandMapper.class).selectCount(any())).thenReturn(1L); rejected();
    }
    @Test void lockedCurrentStateAndOwnershipAreRechecked() {
        event.setPublicationStatus("published"); rejected();
        event.setPublicationStatus("draft"); event.setOrganizationId(62L); rejected();
    }
    @Test void fundsOrRegistrationRejectionCannotContinueDeletingTheEvent() {
        doThrow(new ServiceException("已有报名或资金历史")).when(dep(CompetitionSetupApi.class)).discardEmptyDraftUnits(91L);
        run(() -> assertThrows(ServiceException.class, () -> service.deleteDraft(91L)));
        verifyNoInteractions(dep(SportsEventPosterMapper.class), dep(SportsAiTaskMapper.class));
        verify(dep(SportsEventMapper.class), never()).deleteById(anyLong());
    }
}
