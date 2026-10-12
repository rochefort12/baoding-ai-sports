package org.dromara.sports.event.ai;

import org.dromara.common.core.enums.UserType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.event.domain.SportsAiTask;
import org.dromara.sports.event.mapper.SportsAiTaskMapper;
import org.dromara.sports.event.service.EventPublicationService;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.TransactionStatus;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 调用正式确认服务：已创建重放、锁后终态、组织拒绝及失败任务均不能重复创建赛事。不是数据库并发测试。 */
@Tag("local")
class AiTaskConfirmationTest {
    private final Map<Class<?>, Object> dependencies = new HashMap<>();
    private final SportsEventRunAiTaskService service = create();
    private SportsEventRunAiTaskService create() {
        try {
            var constructor = SportsEventRunAiTaskService.class.getDeclaredConstructors()[0];
            return (SportsEventRunAiTaskService) constructor.newInstance(Arrays.stream(constructor.getParameterTypes()).map(type -> {
                Object dependency = mock(type); dependencies.put(type, dependency); return dependency;
            }).toArray());
        } catch (ReflectiveOperationException exception) { throw new AssertionError(exception); }
    }
    private <T> T dependency(Class<T> type) { return type.cast(dependencies.get(type)); }
    private SportsAiTask task(String status, long organization) {
        var task = new SportsAiTask(); task.setId(1001L); task.setOrganizationId(organization);
        task.setTenantId("fixture"); task.setStatus(status); task.setResultObjectId("CREATED".equals(status) ? 902L : null);
        return task;
    }
    private void run(Runnable assertion) {
        when(dependency(PlatformTransactionManager.class).getTransaction(any(TransactionDefinition.class))).thenReturn(mock(TransactionStatus.class));
        when(dependency(OrganizationSessionApi.class).managedOrganization(201L)).thenReturn(Optional.of(
            new OrganizationSessionApi.ManagedOrganization(601L, "隔离组织", "fixture", 301L)));
        try (var login = mockStatic(LoginHelper.class)) {
            login.when(LoginHelper::isLogin).thenReturn(true); login.when(LoginHelper::getUserType).thenReturn(UserType.SYS_USER);
            login.when(LoginHelper::getUserId).thenReturn(201L); login.when(LoginHelper::getTenantId).thenReturn("fixture");
            assertion.run();
        }
        verifyNoInteractions(dependency(EventPublicationService.class));
        verify(dependency(SportsAiTaskMapper.class), never()).updateById(any(SportsAiTask.class));
    }
    private SportsEventRunAiTaskService.ConfirmDraft draft() {
        return new SportsEventRunAiTaskService.ConfirmDraft("fixture-confirm", null, null, null, null,
            null, null, null, null, null, null, List.of());
    }
    @Test void completedTaskReplayReturnsSameEventWithoutCreation() {
        when(dependency(SportsAiTaskMapper.class).selectById(1001L)).thenReturn(task("CREATED", 601L));
        run(() -> { var reply = service.confirm(1001L, draft()); assertEquals(902L, reply.eventId()); assertTrue(reply.replayed()); });
    }
    @Test void stateIsReadAgainAfterRowLock() {
        when(dependency(SportsAiTaskMapper.class).selectById(1001L)).thenReturn(task("PENDING_CONFIRMATION", 601L), task("CREATED", 601L));
        run(() -> assertTrue(service.confirm(1001L, draft()).replayed()));
        var order = inOrder(dependency(SportsAiTaskMapper.class));
        order.verify(dependency(SportsAiTaskMapper.class)).selectById(1001L);
        order.verify(dependency(SportsAiTaskMapper.class)).lockById(1001L);
        order.verify(dependency(SportsAiTaskMapper.class)).selectById(1001L);
    }
    @Test void foreignOrganizationCannotConfirmOrLockTask() {
        when(dependency(SportsAiTaskMapper.class).selectById(1001L)).thenReturn(task("PENDING_CONFIRMATION", 999L));
        run(() -> assertThrows(ServiceException.class, () -> service.confirm(1001L, draft())));
        verify(dependency(SportsAiTaskMapper.class), never()).lockById(anyLong());
    }
    @Test void failedTaskCannotCreateEvent() {
        when(dependency(SportsAiTaskMapper.class).selectById(1001L)).thenReturn(task("FAILED", 601L));
        run(() -> assertThrows(ServiceException.class, () -> service.confirm(1001L, draft())));
    }
}
