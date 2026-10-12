package org.dromara.sports.event.service;

import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.sports.api.StoredObjectApi;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.event.ai.SportsEventAiProperties;
import org.dromara.sports.event.ai.SportsEventCallAiGatewayClient;
import org.dromara.sports.event.domain.SportsEventPoster;
import org.dromara.sports.event.mapper.SportsEventPosterMapper;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.redisson.api.RLock;
import org.redisson.api.RedissonClient;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.SimpleTransactionStatus;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@Tag("local")
class PromotionVisualTest {
    final EventPublicationService events = mock(EventPublicationService.class);
    final EventPromotionService promotion = mock(EventPromotionService.class);
    final SportsEventPosterMapper posters = mock(SportsEventPosterMapper.class);
    final SportsEventCallAiGatewayClient gateway = mock(SportsEventCallAiGatewayClient.class);
    final SportsEventAiProperties properties = mock(SportsEventAiProperties.class);
    final StoredObjectApi files = mock(StoredObjectApi.class);
    final OrganizationSessionApi sessions = mock(OrganizationSessionApi.class);
    final PlatformTransactionManager transactions = mock(PlatformTransactionManager.class);
    final RedissonClient redis = mock(RedissonClient.class);
    final RLock lock = mock(RLock.class);
    final PromotionVisualService service = new PromotionVisualService(events, promotion, posters, gateway, properties, files, sessions, transactions, redis);

    void prepare() {
        var event = mock(EventPublicationService.EventCard.class);
        when(event.name()).thenReturn("社区三人篮球赛"); when(event.projectName()).thenReturn("篮球");
        when(events.managed(901L)).thenReturn(event);
        when(sessions.managedOrganization(any())).thenAnswer(call -> java.util.Optional.of(
            new OrganizationSessionApi.ManagedOrganization(1L, "测试组织", LoginHelper.getTenantId(), 777L)));
        when(redis.getLock(anyString())).thenReturn(lock); when(lock.tryLock()).thenReturn(true);
        when(lock.isHeldByCurrentThread()).thenReturn(true);
        when(properties.imageConfigured()).thenReturn(true);
        when(transactions.getTransaction(any())).thenReturn(new SimpleTransactionStatus());
        when(posters.selectOne(any())).thenReturn(new SportsEventPoster());
    }
    @Test void consentAndForeignOrganizationStopBeforeGeneration() {
        assertThrows(ServiceException.class, () -> service.generate(901L, false, "community", "社区", "周末"));
        verifyNoInteractions(events, gateway, files, redis);
        when(events.managed(901L)).thenThrow(new ServiceException("不属于当前组织"));
        assertThrows(ServiceException.class, () -> service.generate(901L, true, "community", "社区", "周末"));
        verifyNoInteractions(gateway, files, redis);
    }
    @Test void subjectDigestDoesNotAssumeBadminton() {
        assertNotEquals(PromotionVisualService.subjectDigest("友谊赛", "篮球"), PromotionVisualService.subjectDigest("友谊赛", "羽毛球"));
        assertNotEquals(PromotionVisualService.subjectDigest("友谊赛", "篮球"), PromotionVisualService.subjectDigest("冠军赛", "篮球"));
        assertEquals(PromotionVisualService.subjectDigest(null, null), PromotionVisualService.subjectDigest("", ""));
    }
    @Test void missingOrWrongOrganizationMappingStopsBeforePaidGeneration() {
        prepare(); when(sessions.managedOrganization(any())).thenReturn(java.util.Optional.empty());
        assertThrows(ServiceException.class, () -> service.generate(901L, true, "community", "社区", "周末"));
        verifyNoInteractions(gateway, files, redis);
    }
    @Test void imageCanBeSavedBeforeAnyCopyExists() {
        prepare(); var row = new SportsEventPoster();
        when(posters.selectOne(any())).thenReturn(null);
        when(promotion.prepareVisualPoster(eq(901L), any())).thenReturn(row);
        when(gateway.createPromotionVisual(anyString(), anyString(), anyString(), anyString(), anyString())).thenReturn(new byte[32]);
        when(files.keepImage(eq(777L), any(), eq(StoredObjectApi.EVENT_BANNER), any())).thenReturn(123L);
        when(posters.updateById(row)).thenReturn(1);
        service.generate(901L, true, "community", "社区", "周末");
        assertEquals(123L, row.getVisualFileId());
        verify(promotion).prepareVisualPoster(eq(901L), any());
        verify(promotion).current(901L);
    }
    @Test void concurrentRequestDoesNotCallProvider() {
        prepare(); when(lock.tryLock()).thenReturn(false);
        assertThrows(ServiceException.class, () -> service.generate(901L, true, "community", "社区", "周末"));
        verifyNoInteractions(gateway, files); verify(lock, never()).unlock();
    }
    @Test void providerFailureKeepsStoredCopyAndVisual() {
        prepare(); when(gateway.createPromotionVisual(anyString(), anyString(), anyString(), anyString(), anyString())).thenThrow(new ServiceException("不可用"));
        assertThrows(ServiceException.class, () -> service.generate(901L, true, "community", "社区", "周末"));
        verifyNoInteractions(files); verify(posters, never()).updateById(any(SportsEventPoster.class)); verify(lock).unlock();
    }
    @Test void changedSportDuringGenerationStopsFileWrite() {
        prepare(); var changed = mock(EventPublicationService.EventCard.class);
        when(changed.name()).thenReturn("社区三人篮球赛"); when(changed.projectName()).thenReturn("游泳");
        var initial = events.managed(901L); when(events.managed(901L)).thenReturn(initial, changed);
        when(gateway.createPromotionVisual(anyString(), anyString(), anyString(), anyString(), anyString())).thenReturn(new byte[32]);
        assertThrows(ServiceException.class, () -> service.generate(901L, true, "community", "社区", "周末"));
        verifyNoInteractions(files); verify(lock).unlock();
    }
    @Test void savedVisualReusedAndDoesNotOverwriteEventCover() {
        prepare(); var row = new SportsEventPoster(); when(posters.selectOne(any())).thenReturn(row);
        byte[] image = new byte[32]; when(gateway.createPromotionVisual(anyString(), anyString(), anyString(), anyString(), anyString())).thenReturn(image);
        try (var login = mockStatic(LoginHelper.class)) {
            login.when(LoginHelper::getTenantId).thenReturn("org-fixture"); login.when(LoginHelper::getUserId).thenReturn(99L);
            when(files.keepImage(777L, "org-fixture", StoredObjectApi.EVENT_BANNER, image)).thenReturn(123L);
            when(posters.updateById(row)).thenReturn(1);
            service.generate(901L, true, "community", "社区", "周末");
            assertEquals(123L, row.getVisualFileId()); assertEquals("community", row.getVisualStyle());
            service.generate(901L, true, "community", "社区", "周末");
            verify(gateway, times(1)).createPromotionVisual("社区三人篮球赛", "篮球", "社区", "周末", "community");
            verify(files, times(1)).keepImage(anyLong(), anyString(), anyString(), any());
            verify(promotion, times(2)).current(901L);
            // 模型升级不能继续复用旧模型图片，但不修改赛事公开封面。
            when(properties.getImageModel()).thenReturn("doubao-seedream-5-0-flash-260915");
            service.generate(901L, true, "community", "社区", "周末");
            verify(gateway, times(2)).createPromotionVisual("社区三人篮球赛", "篮球", "社区", "周末", "community");
            verify(files, times(2)).keepImage(anyLong(), anyString(), anyString(), any());
        }
    }
}
