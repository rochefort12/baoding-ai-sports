package org.dromara.sports.event.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.*;
import org.dromara.sports.event.domain.SportsEvent;
import org.dromara.sports.event.domain.SportsEventCommand;
import org.dromara.sports.event.mapper.*;
import org.junit.jupiter.api.*;
import java.time.OffsetDateTime;
import java.util.*;
import java.util.function.Supplier;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;

/** 正式发布与公开投影的确认/冻结/费用门禁；数据库依赖隔离。 */
@Tag("local")
class EventPublicationContactTest {
    final Map<Class<?>,Object> deps = new HashMap<>();
    final EventPublicationService service = create();
    final SportsEvent event = event();
    <T> T dep(Class<T> type) { return type.cast(deps.get(type)); }
    EventPublicationService create() {
        try {
            var c=EventPublicationService.class.getDeclaredConstructors()[0];
            return (EventPublicationService)c.newInstance(Arrays.stream(c.getParameterTypes()).map(type->{
                Object value=type==ObjectMapper.class?new ObjectMapper():mock(type);deps.put(type,value);return value;
            }).toArray());
        } catch(Exception e){throw new AssertionError(e);}
    }
    SportsEvent event() {
        var e=new SportsEvent();e.setId(901L);e.setTenantId("fixture");e.setOrganizationId(601L);
        e.setSportCode("badminton");e.setName("隔离赛事");e.setLocation("隔离场地");e.setProjectName("羽毛球");e.setFeeDescription("以项目配置为准");
        e.setPublicationStatus("draft");e.setHoldingStatus("normal");e.setContactSnapshot("{}");
        var now=OffsetDateTime.now();e.setRegistrationOpensAt(now.plusDays(1));e.setRegistrationClosesAt(now.plusDays(2));e.setStartsAt(now.plusDays(3));e.setEndsAt(now.plusDays(4));return e;
    }
    void session(Runnable test) {
        when(dep(SportsEventMapper.class).selectById(901L)).thenReturn(event);
        when(dep(SportsEventMapper.class).selectOne(any())).thenReturn(event);
        when(dep(SportsEventMapper.class).updateById(any(SportsEvent.class))).thenReturn(1);
        when(dep(OrganizationQualificationApi.class).isCertified("fixture",601L)).thenReturn(true);
        when(dep(OrganizationQualificationApi.class).publicContact("fixture",601L)).thenReturn(new OrganizationQualificationApi.OrganizerContact("原组织","默认联系人","默认渠道"));
        when(dep(OrganizationSessionApi.class).managedOrganization(201L)).thenReturn(Optional.of(new OrganizationSessionApi.ManagedOrganization(601L,"原组织","fixture",301L)));
        when(dep(FeeApi.class).publicUnitPrices("fixture",901L)).thenReturn(List.of(new FeeApi.PublicUnitPrice(501L,"合成单打",java.math.BigDecimal.ZERO,"free",null)));
        try(var login=mockStatic(LoginHelper.class);var tenant=mockStatic(TenantHelper.class)) {
            login.when(LoginHelper::isLogin).thenReturn(true);login.when(LoginHelper::getUserType).thenReturn(UserType.SYS_USER);
            login.when(LoginHelper::getUserId).thenReturn(201L);login.when(LoginHelper::getTenantId).thenReturn("fixture");
            tenant.when(()->TenantHelper.ignore(any(Supplier.class))).thenAnswer(call->((Supplier<?>)call.getArgument(0)).get());
            test.run();
        }
    }
    @Test void consentRequiredBeforePublication() {
        session(()->assertThrows(ServiceException.class,()->service.publish(901L,"key",false,"姓名","渠道")));
        verify(dep(SportsEventMapper.class),never()).updateById(any(SportsEvent.class));
    }
    @Test void confirmedSnapshotDoesNotFollowOrganizationChanges() {
        session(()->{
            service.publish(901L,"key",true,"赛事联系人","赛事渠道");
            when(dep(OrganizationQualificationApi.class).publicContact("fixture",601L)).thenReturn(new OrganizationQualificationApi.OrganizerContact("改名组织","新人","新渠道"));
            var view=service.publicFees(901L);assertEquals("原组织",view.organizationName());assertEquals("赛事渠道",view.contactMethod());assertTrue(view.contactFrozen());
        });
    }
    @Test void legacyPublishedEventDoesNotInventHistoricalContact() {
        session(()->{event.setPublicationStatus("published");assertNull(service.publicFees(901L).contactName());assertFalse(service.publicFees(901L).contactFrozen());});
        verify(dep(OrganizationQualificationApi.class),never()).publicContact(anyString(),anyLong());
    }
    @Test void missingContactIsRejectedWithoutPublishing() {
        session(()->assertThrows(ServiceException.class,()->service.publish(901L,"key",true,"", "渠道")));
        assertEquals("draft",event.getPublicationStatus());
    }
    @Test void restoreCannotReplaceFrozenContact() {
        session(()->{
            service.publish(901L,"key",true,"赛事联系人","赛事渠道");event.setPublicationStatus("offline");
            assertThrows(ServiceException.class,()->service.publish(901L,"second",true,"替代人","替代渠道"));
        });
    }
    @Test void unpricedProjectPreventsPublishing() {
        session(()->{
            when(dep(FeeApi.class).publicUnitPrices("fixture",901L)).thenReturn(List.of(new FeeApi.PublicUnitPrice(501L,"候选项目",null,null,null)));
            assertThrows(ServiceException.class,()->service.publish(901L,"key",true,"姓名","渠道"));
            assertEquals("draft",event.getPublicationStatus());
        });
    }
    @Test void noProjectCannotProduceAnEmptyPublishedEvent() {
        session(()->{
            when(dep(FeeApi.class).publicUnitPrices("fixture",901L)).thenReturn(List.of());
            assertThrows(ServiceException.class,()->service.publish(901L,"empty",true,"姓名","渠道"));
            assertEquals("draft",event.getPublicationStatus());
        });
        verify(dep(SportsEventMapper.class),never()).updateById(any(SportsEvent.class));
    }
    @Test void restrictedOrganizationCannotCreateNewEventButCanReadHistory() {
        session(()->{
            when(dep(OrganizationQualificationApi.class).isCertified("fixture",601L)).thenReturn(false);
            assertThrows(ServiceException.class,()->service.create(null));
            assertEquals(901L,service.managed(901L).id());
        });
        verify(dep(SportsEventMapper.class),never()).insert(any(SportsEvent.class));
    }
    EventPublicationService.EventDraft draft(String location,String fee,String starts,String ends) {
        return new EventPublicationService.EventDraft(event.getName(),location,event.getProjectName(),fee,
            event.getRegistrationOpensAt().toString(),event.getRegistrationClosesAt().toString(),starts,ends,
            "manual",null,null,null,null,null,null,null,null,null,null);
    }
    @Test void formalRegistrationPreventsMajorDateVenueAndFeeChangesEvenWhenOffline() {
        session(()->{
            event.setPublicationStatus("offline");event.setRegistrationReviewLocked(true);
            assertThrows(ServiceException.class,()->service.update(901L,draft(event.getLocation(),event.getFeeDescription(),event.getStartsAt().plusDays(1).toString(),event.getEndsAt().plusDays(1).toString())));
            assertThrows(ServiceException.class,()->service.update(901L,draft("替换的实际球馆",event.getFeeDescription(),event.getStartsAt().toString(),event.getEndsAt().toString())));
            assertThrows(ServiceException.class,()->service.update(901L,draft(event.getLocation(),"改为每单收费",event.getStartsAt().toString(),event.getEndsAt().toString())));
        });
        verify(dep(SportsEventMapper.class),never()).updateById(any(SportsEvent.class));
    }
    @Test void equivalentTimezoneAndUnchangedMeaningRemainEditable() {
        session(()->{
            event.setPublicationStatus("offline");event.setRegistrationReview("manual");event.setRegistrationReviewLocked(true);
            var updated=service.update(901L,draft(event.getLocation(),event.getFeeDescription(),event.getStartsAt().withOffsetSameInstant(java.time.ZoneOffset.UTC).toString(),event.getEndsAt().withOffsetSameInstant(java.time.ZoneOffset.UTC).toString()));
            assertTrue(updated.editable());
        });
    }
    @Test void stalePreviewVersionCannotPublishAndDoesNotWriteACommand() {
        session(()->{event.setVersion(3);assertThrows(ServiceException.class,()->service.publish(901L,"version-stale",true,"姓名","渠道",2,null));});
        assertEquals("draft",event.getPublicationStatus());verify(dep(SportsEventMapper.class),never()).updateById(any(SportsEvent.class));verify(dep(SportsEventCommandMapper.class),never()).insert(any(SportsEventCommand.class));
    }
    @Test void priceChangedWithoutEventVersionInvalidatesPublicationPreview() {
        session(()->{
            event.setVersion(3);var preview=service.previewFees(901L);assertEquals(3,preview.eventVersion());assertNotNull(preview.previewHash());
            when(dep(FeeApi.class).publicUnitPrices("fixture",901L)).thenReturn(List.of(new FeeApi.PublicUnitPrice(501L,"合成单打",new java.math.BigDecimal("10"),"event",null)));
            assertThrows(ServiceException.class,()->service.publish(901L,"price-stale",true,"姓名","渠道",3,preview.previewHash()));
        });assertEquals("draft",event.getPublicationStatus());verify(dep(SportsEventMapper.class),never()).updateById(any(SportsEvent.class));
    }
    @Test void memberOrCapacityChangedWithoutEventVersionInvalidatesPublicationPreview() {
        session(()->{
            event.setVersion(3);when(dep(CompetitionSetupApi.class).publicationUnits(901L)).thenReturn(List.of(new CompetitionSetupApi.DraftUnit(501L,"合成单打","individual",1,1,8)));
            var preview=service.previewFees(901L);
            when(dep(CompetitionSetupApi.class).publicationUnits(901L)).thenReturn(List.of(new CompetitionSetupApi.DraftUnit(501L,"合成单打","pair",2,2,16)));
            assertThrows(ServiceException.class,()->service.publish(901L,"directory-stale",true,"姓名","渠道",3,preview.previewHash()));
        });assertEquals("draft",event.getPublicationStatus());verify(dep(SportsEventMapper.class),never()).updateById(any(SportsEvent.class));
    }
    @Test void exactPreviewCanPublishThroughTheOriginalContactConfirmationRules() {
        session(()->{event.setVersion(3);var preview=service.previewFees(901L);assertEquals("published",service.publish(901L,"exact-preview",true,"姓名","渠道",preview.eventVersion(),preview.previewHash()).publicationStatus());});
        verify(dep(SportsEventCommandMapper.class)).insert(any(SportsEventCommand.class));
    }
    @Test void changedReadyPaymentConfigurationRejectsTheOldPublicationPreview() {
        session(()->{
            event.setVersion(3);when(dep(FeeApi.class).eventPaymentReady("fixture",901L)).thenReturn(true);when(dep(FeeApi.class).eventPaymentRevision("fixture",901L)).thenReturn(4);
            var preview=service.previewFees(901L);
            // Both configurations remain ready; only a changed instruction/channel revision distinguishes them.
            when(dep(FeeApi.class).eventPaymentRevision("fixture",901L)).thenReturn(5);
            assertThrows(ServiceException.class,()->service.publish(901L,"settings-stale",true,"姓名","渠道",3,preview.previewHash()));
        });assertEquals("draft",event.getPublicationStatus());verify(dep(SportsEventMapper.class),never()).updateById(any(SportsEvent.class));verify(dep(SportsEventCommandMapper.class),never()).insert(any(SportsEventCommand.class));
    }
}
