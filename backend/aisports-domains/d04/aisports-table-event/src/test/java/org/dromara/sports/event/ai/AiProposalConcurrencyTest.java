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

/** 正式候选写回的状态、旧候选和更新结果门禁；依赖隔离，不冒充真实数据库并发。 */
@Tag("local")
class AiProposalConcurrencyTest {
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
    private void save() {
        try {
            var method = SportsEventRunAiTaskService.class.getDeclaredMethod("saveProposal", long.class, String.class, String.class);
            method.setAccessible(true); method.invoke(service, 1001L, "old", "new");
        } catch (java.lang.reflect.InvocationTargetException exception) {
            if (exception.getCause() instanceof RuntimeException cause) throw cause;
            throw new AssertionError(exception.getCause());
        } catch (ReflectiveOperationException exception) { throw new AssertionError(exception); }
    }
    private SportsAiTask pending(String proposal) {
        SportsAiTask task = task("PENDING_CONFIRMATION", 601L); task.setProposal(proposal); return task;
    }
    private void session(Runnable assertion) {
        when(dependency(PlatformTransactionManager.class).getTransaction(any(TransactionDefinition.class))).thenReturn(mock(TransactionStatus.class));
        when(dependency(OrganizationSessionApi.class).managedOrganization(201L)).thenReturn(Optional.of(
            new OrganizationSessionApi.ManagedOrganization(601L, "隔离组织", "fixture", 301L)));
        try (var login = mockStatic(LoginHelper.class)) {
            login.when(LoginHelper::isLogin).thenReturn(true); login.when(LoginHelper::getUserType).thenReturn(UserType.SYS_USER);
            login.when(LoginHelper::getUserId).thenReturn(201L); login.when(LoginHelper::getTenantId).thenReturn("fixture");
            assertion.run();
        }
        verifyNoInteractions(dependency(EventPublicationService.class));
    }
    @Test void staleModelReplyCannotOverwriteNewerDialogue() {
        when(dependency(SportsAiTaskMapper.class).selectById(1001L)).thenReturn(pending("old"), pending("another-dialogue"));
        session(() -> assertThrows(ServiceException.class, this::save));
        verify(dependency(SportsAiTaskMapper.class), never()).updateById(any(SportsAiTask.class));
    }
    @Test void completedTaskCannotAcceptLateModelReply() {
        when(dependency(SportsAiTaskMapper.class).selectById(1001L)).thenReturn(pending("old"), task("CREATED", 601L));
        session(() -> assertThrows(ServiceException.class, this::save));
        verify(dependency(SportsAiTaskMapper.class), never()).updateById(any(SportsAiTask.class));
    }
    @Test void failedOptimisticUpdateIsNotReportedAsSuccess() {
        when(dependency(SportsAiTaskMapper.class).selectById(1001L)).thenReturn(pending("old"));
        when(dependency(SportsAiTaskMapper.class).updateById(any(SportsAiTask.class))).thenReturn(0);
        session(() -> assertThrows(ServiceException.class, this::save));
    }
    @Test void matchingPendingProposalIsWrittenAfterLockAndRead() {
        when(dependency(SportsAiTaskMapper.class).selectById(1001L)).thenReturn(pending("old"), pending("old"));
        when(dependency(SportsAiTaskMapper.class).updateById(any(SportsAiTask.class))).thenReturn(1);
        session(this::save);
        var order = inOrder(dependency(SportsAiTaskMapper.class));
        order.verify(dependency(SportsAiTaskMapper.class),times(2)).selectById(1001L);
        order.verify(dependency(SportsAiTaskMapper.class)).lockById(1001L);
        order.verify(dependency(SportsAiTaskMapper.class)).selectById(1001L);
        order.verify(dependency(SportsAiTaskMapper.class)).updateById(argThat((SportsAiTask value) -> "new".equals(value.getProposal())));
    }
}
