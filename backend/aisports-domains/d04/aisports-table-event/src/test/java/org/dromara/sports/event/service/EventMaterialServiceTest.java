package org.dromara.sports.event.service;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.event.ai.SportsEventAiProperties;
import org.dromara.sports.event.ai.SportsEventCallAiGatewayClient;
import org.dromara.sports.platform.core.BusinessIdentity;
import org.dromara.sports.platform.core.ScopedJdbc;
import org.dromara.sports.api.StoredObjectApi;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.util.Map;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import static org.junit.jupiter.api.Assertions.*;

/** Unit boundaries only: organization guards, optimistic draft versions and failed model preservation. */
@Tag("local")
class EventMaterialServiceTest {
    final ObjectMapper json=new ObjectMapper();
    final EventPublicationService events=mock(EventPublicationService.class);
    final EventPromotionService promotion=mock(EventPromotionService.class);
    final SportsEventCallAiGatewayClient gateway=mock(SportsEventCallAiGatewayClient.class);
    final SportsEventAiProperties properties=mock(SportsEventAiProperties.class);
    final ScopedJdbc db=mock(ScopedJdbc.class);
    final StoredObjectApi files=mock(StoredObjectApi.class);
    final EventPublicationService.EventCard event=mock(EventPublicationService.EventCard.class);
    final EventPromotionService.PromotionView promo=mock(EventPromotionService.PromotionView.class);
    final EventMaterialService service=new EventMaterialService(events,promotion,gateway,properties,db,json,files);
    void prepare(String material) {
        when(events.managed(99L)).thenReturn(event); when(promotion.current(99L)).thenReturn(promo);
        when(event.name()).thenReturn("测试羽毛球赛");when(event.location()).thenReturn("东馆");
        when(promo.whenText()).thenReturn("2026-10-20 09:00");when(promo.contactName()).thenReturn("负责人员");when(promo.contactMethod()).thenReturn("主办方站内联系");
        when(db.one(anyString(),anyLong(),any())).thenReturn(Map.of("materials",material));
        when(db.update(anyString(),any(),any(),any(),any())).thenReturn(1);
    }
    @Test void foreignOrganizationStopsBeforeDocumentsAndModel() {
        when(events.managed(99L)).thenThrow(new ServiceException("当前组织无权访问"));
        assertThrows(ServiceException.class,()->service.generate(99L,"plan",0,"unused",""));
        verifyNoInteractions(db,gateway,promotion);
    }
    @Test void staleVersionStopsBeforeModelCostOrWrite() {
        prepare("{\"plan\":{\"version\":3,\"title\":\"旧稿\",\"content\":\"保留\"}}");
        try(var identity=mockStatic(BusinessIdentity.class)){identity.when(BusinessIdentity::getTenantId).thenReturn("test-org");
            var facts=service.current(99L);assertThrows(ServiceException.class,()->service.generate(99L,"plan",2,facts.path("factDigest").asText(),""));
            verifyNoInteractions(gateway);verify(db,never()).update(anyString(),any(),any(),any(),any());
        }
    }
    @Test void failedModelNeverOverwritesHandwrittenDraft() {
        prepare("{\"plan\":{\"version\":1,\"title\":\"手稿\",\"content\":\"原稿\"}}");
        when(gateway.composeMaterial(any(),eq("plan"),anyString())).thenThrow(new ServiceException("模型超时"));
        try(var identity=mockStatic(BusinessIdentity.class)){identity.when(BusinessIdentity::getTenantId).thenReturn("test-org");
            var facts=service.current(99L);assertThrows(ServiceException.class,()->service.generate(99L,"plan",1,facts.path("factDigest").asText(),""));
            verify(db,never()).update(anyString(),any(),any(),any(),any());
        }
    }
    @Test void changingFactsDuringModelCallRejectsGeneratedDraft() {
        prepare("{}");
        when(gateway.composeMaterial(any(),anyString(),anyString())).thenAnswer(call->{when(event.location()).thenReturn("西馆");return json.createObjectNode().put("title","草稿").put("content","需核对");});
        try(var identity=mockStatic(BusinessIdentity.class)){identity.when(BusinessIdentity::getTenantId).thenReturn("test-org");
            var facts=service.current(99L);assertThrows(ServiceException.class,()->service.generate(99L,"plan",0,facts.path("factDigest").asText(),""));
            verify(db,never()).update(anyString(),any(),any(),any(),any());
        }
    }
    @Test void manualEditAddsNewVersionAndKeepsPriorOrigin() {
        prepare("{\"plan\":{\"version\":2,\"title\":\"AI旧稿\",\"content\":\"旧稿\",\"source\":\"ai\",\"history\":[]}}");
        try(var identity=mockStatic(BusinessIdentity.class)){identity.when(BusinessIdentity::getTenantId).thenReturn("test-org");identity.when(BusinessIdentity::getUserId).thenReturn(88L);
            var facts=service.current(99L);var saved=service.save(99L,"plan",2,facts.path("factDigest").asText(),"修改标题","负责人改稿");
            assertEquals(3,saved.path("version").asInt());assertEquals("manual",saved.path("source").asText());
            assertEquals("ai",saved.path("history").get(0).path("source").asText());assertEquals("旧稿",saved.path("history").get(0).path("content").asText());
            verify(db,times(1)).update(anyString(),any(),any(),any(),any());
        }
    }
    @Test void documentLimitAllows10000AndRejects10001BeforeAnyRead() {
        String legalContent="现场岗位核对记录".repeat(1250);
        assertEquals(10000,legalContent.length());
        assertThrows(ServiceException.class,()->service.save(99L,"script",0,"unused","执行记录",legalContent+"核"));
        verifyNoInteractions(events,promotion,db,gateway);
        prepare("{}");
        try(var identity=mockStatic(BusinessIdentity.class)){identity.when(BusinessIdentity::getTenantId).thenReturn("test-org");identity.when(BusinessIdentity::getUserId).thenReturn(88L);
            var facts=service.current(99L);var saved=service.save(99L,"script",0,facts.path("factDigest").asText(),"执行记录",legalContent);
            assertEquals(10000,saved.path("content").asText().length());
            assertEquals("manual",saved.path("source").asText());verify(db,times(1)).update(anyString(),any(),any(),any(),any());
        }
    }
    @Test void coverRequiresMatchingVersionAndOwnedBannerPurpose() {
        prepare("{}");when(db.one(startsWith("SELECT version"),anyLong(),any())).thenReturn(Map.of("version",4));
        try(var identity=mockStatic(BusinessIdentity.class)){identity.when(BusinessIdentity::getTenantId).thenReturn("test-org");identity.when(BusinessIdentity::getUserId).thenReturn(88L);
            assertThrows(ServiceException.class,()->service.saveCover(99L,3,123L));verifyNoInteractions(files);
            doThrow(new ServiceException("文件归属错误")).when(files).requireImage(123L,StoredObjectApi.EVENT_BANNER,"test-org");
            assertThrows(ServiceException.class,()->service.saveCover(99L,4,123L));verify(db,never()).update(anyString(),any(),any(),any(),any());
        }
    }
}
