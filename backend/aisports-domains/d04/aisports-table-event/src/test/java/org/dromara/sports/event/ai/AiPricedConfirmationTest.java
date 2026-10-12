package org.dromara.sports.event.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.sports.api.*;
import org.dromara.sports.event.domain.SportsAiTask;
import org.dromara.sports.event.mapper.SportsAiTaskMapper;
import org.dromara.sports.event.service.EventPublicationService;
import org.dromara.sports.event.ai.SportsEventRunAiTaskService.*;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.TransactionStatus;
import java.util.*;
import java.math.BigDecimal;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** Actual confirm service orchestration with mocked storage contracts; not database atomicity or model acceptance. */
@Tag("local")
class AiPricedConfirmationTest {
    private final Map<Class<?>,Object> dependencies=new HashMap<>();
    private final ObjectMapper json=new ObjectMapper();
    private final SportsEventRunAiTaskService service=create();
    private SportsEventRunAiTaskService create() {
        try {
            var c=SportsEventRunAiTaskService.class.getDeclaredConstructors()[0];
            return (SportsEventRunAiTaskService)c.newInstance(Arrays.stream(c.getParameterTypes()).map(type->{
                Object value=type==ObjectMapper.class?json:mock(type);dependencies.put(type,value);return value;
            }).toArray());
        }catch(ReflectiveOperationException e){throw new AssertionError(e);}
    }
    private <T>T dep(Class<T> type){return type.cast(dependencies.get(type));}
    private List<UnitDraft> units(){return List.of(new UnitDraft("单打","individual",1,1,8,"20","order","filled"),new UnitDraft("双打","pair",2,2,4,"40","order","filled"));}
    private ConfirmDraft draft(Integer version,List<UnitDraft> units){return new ConfirmDraft("fixture-price","合成赛","合成馆","羽毛球","单打20双打40",null,null,null,null,"manual","合成规程",units,null,null,null,version);}
    private SportsAiTask task() {
        var t=new SportsAiTask();t.setId(1001L);t.setTenantId("fixture");t.setOrganizationId(601L);t.setStatus("PENDING_CONFIRMATION");t.setVersion(7);
        var proposal=json.createObjectNode();var event=proposal.putObject("event");event.putObject("name").put("value","合成赛");event.putObject("registrationReview").put("value","manual");
        var list=proposal.putArray("units");for(var u:units()){var n=list.addObject();n.putObject("name").put("value",u.name());n.putObject("entryType").put("value",u.entryType());n.putObject("minMembers").put("value",u.minMembers());n.putObject("maxMembers").put("value",u.maxMembers());n.putObject("limitCount").put("value",u.limitCount());n.putObject("feeAmount").put("value",u.feeAmount()).put("status","filled");n.putObject("feeBasis").put("value","order").put("status","filled");}
        t.setProposal(proposal.toString());return t;
    }
    private void run(boolean payment,Runnable assertion){
        when(dep(SportsAiTaskMapper.class).selectById(1001L)).thenReturn(task());
        when(dep(PlatformTransactionManager.class).getTransaction(any(TransactionDefinition.class))).thenReturn(mock(TransactionStatus.class));
        when(dep(OrganizationSessionApi.class).managedOrganization(201L)).thenReturn(Optional.of(new OrganizationSessionApi.ManagedOrganization(601L,"合成组织","fixture",301L)));
        when(dep(OrganizationQualificationApi.class).hasStaffAction("fixture",601L,301L,"payment")).thenReturn(payment);
        try(var login=mockStatic(LoginHelper.class)){
            login.when(LoginHelper::isLogin).thenReturn(true);login.when(LoginHelper::getUserType).thenReturn(UserType.SYS_USER);
            login.when(LoginHelper::getUserId).thenReturn(201L);login.when(LoginHelper::getTenantId).thenReturn("fixture");assertion.run();
        }
    }
    private void noWrites(){verifyNoInteractions(dep(EventPublicationService.class),dep(CompetitionSetupApi.class),dep(FeeApi.class));verify(dep(SportsAiTaskMapper.class),never()).updateById(any(SportsAiTask.class));}
    @Test void missingAndStaleConfirmationVersionsCannotCreatePrices(){
        run(true,()->{assertThrows(ServiceException.class,()->service.confirm(1001L,draft(null,units())));assertThrows(ServiceException.class,()->service.confirm(1001L,draft(6,units())));});noWrites();
    }
    @Test void changingAConfirmedPriceWithoutUpdatingTheVisibleCandidateIsRejected(){
        var changed=List.of(new UnitDraft("单打","individual",1,1,8,"99","order","filled"),units().get(1));
        run(true,()->assertThrows(ServiceException.class,()->service.confirm(1001L,draft(7,changed))));noWrites();
    }
    @Test void removingSourcePricesCannotBypassConfirmation(){
        var unpriced=units().stream().map(u->new UnitDraft(u.name(),u.entryType(),u.minMembers(),u.maxMembers(),u.limitCount())).toList();
        run(true,()->assertThrows(ServiceException.class,()->service.confirm(1001L,draft(7,unpriced))));noWrites();
    }
    @Test void organizerWithoutPaymentStaffGrantCannotConfirmFeePolicy(){
        run(false,()->assertThrows(ServiceException.class,()->service.confirm(1001L,draft(7,units()))));noWrites();
    }
    @Test void sourcePricesCreateTwoInitialDraftPoliciesAndNeverPaymentFacts(){
        var card=mock(EventPublicationService.EventCard.class);when(card.id()).thenReturn(902L);
        when(dep(EventPublicationService.class).create(any())).thenReturn(card);
        when(dep(CompetitionSetupApi.class).placeUnpricedUnit(902L,"单打","individual",1,1,8)).thenReturn(801L);
        when(dep(CompetitionSetupApi.class).placeUnpricedUnit(902L,"双打","pair",2,2,4)).thenReturn(802L);
        when(dep(SportsAiTaskMapper.class).updateById(any(SportsAiTask.class))).thenReturn(1);
        run(true,()->{var result=service.confirm(1001L,draft(7,units()));assertEquals(902L,result.eventId());assertFalse(result.replayed());});
        verify(dep(FeeApi.class)).placeInitialPolicy("fixture",801L,new BigDecimal("20.00"),"event",null,null);
        verify(dep(FeeApi.class)).placeInitialPolicy("fixture",802L,new BigDecimal("40.00"),"event",null,null);
        verifyNoMoreInteractions(dep(FeeApi.class));
        var eventInput=org.mockito.ArgumentCaptor.forClass(EventPublicationService.EventDraft.class);verify(dep(EventPublicationService.class)).create(eventInput.capture());assertEquals("羽毛球",eventInput.getValue().projectName());
        var order=inOrder(dep(PlatformTransactionManager.class),dep(FeeApi.class));order.verify(dep(PlatformTransactionManager.class)).getTransaction(any());order.verify(dep(FeeApi.class)).placeInitialPolicy("fixture",801L,new BigDecimal("20.00"),"event",null,null);order.verify(dep(FeeApi.class)).placeInitialPolicy("fixture",802L,new BigDecimal("40.00"),"event",null,null);order.verify(dep(PlatformTransactionManager.class)).commit(any());
    }
    @Test void sourceDeclarationAndExplicitHumanSwitchReachTheCreatedEvent() throws Exception {
        String statement="自主评估运动适宜性，遵守裁判安排。";
        var sourceTask=task();var node=(com.fasterxml.jackson.databind.node.ObjectNode)json.readTree(sourceTask.getProposal());
        var declaration=node.withObject("event").putObject("declarationText");declaration.put("value",statement).put("status","filled");declaration.putArray("sources").addObject().put("kind","document").put("quote",statement);sourceTask.setProposal(node.toString());
        var card=mock(EventPublicationService.EventCard.class);when(card.id()).thenReturn(902L);when(dep(EventPublicationService.class).create(any())).thenReturn(card);
        when(dep(CompetitionSetupApi.class).placeUnpricedUnit(anyLong(),anyString(),anyString(),any(),any(),anyInt())).thenReturn(801L,802L);
        when(dep(SportsAiTaskMapper.class).updateById(any(SportsAiTask.class))).thenReturn(1);
        run(true,()->{
            when(dep(SportsAiTaskMapper.class).selectById(1001L)).thenReturn(sourceTask);
            var original=draft(7,units());var consent=new ConfirmDraft(original.requestKey(),original.name(),original.location(),original.projectName(),original.feeDescription(),null,null,null,null,"manual",original.rulesText(),units(),null,null,null,statement,true,7);
            assertEquals(902L,service.confirm(1001L,consent).eventId());
        });
        var argument=org.mockito.ArgumentCaptor.forClass(EventPublicationService.EventDraft.class);verify(dep(EventPublicationService.class)).create(argument.capture());
        assertEquals(statement,argument.getValue().declarationText());assertEquals(Boolean.TRUE,argument.getValue().declarationAckRequired());
    }
    @Test void initialGatewaySanitizationRetainsCandidatePricesSourcesAndDeclaration() throws Exception {
        var sanitize=SportsEventRunAiTaskService.class.getDeclaredMethod("sanitize",String.class);sanitize.setAccessible(true);
        String input="{\"event\":{\"declarationText\":{\"value\":\"真实原文声明\",\"status\":\"filled\",\"sources\":[{\"quote\":\"真实原文声明\"}]}},\"units\":[{\"name\":{\"value\":\"双打\"},\"feeAmount\":{\"value\":\"40.00\",\"status\":\"filled\",\"sources\":[{\"quote\":\"双打整单40元\"}]},\"feeBasis\":{\"value\":\"order\",\"status\":\"filled\"}}]}";
        var stored=json.readTree((String)sanitize.invoke(service,input));
        assertEquals("40.00",stored.path("units").get(0).path("feeAmount").path("value").asText());
        assertEquals("order",stored.path("units").get(0).path("feeBasis").path("value").asText());
        assertEquals("双打整单40元",stored.path("units").get(0).path("feeAmount").path("sources").get(0).path("quote").asText());
        assertEquals("真实原文声明",stored.path("event").path("declarationText").path("value").asText());
    }
    @Test void savingSameVisibleValuesResolvesEventAndProjectConflictsWithoutChangingSettledSources() throws Exception {
        var sourceTask=task();var proposal=(com.fasterxml.jackson.databind.node.ObjectNode)json.readTree(sourceTask.getProposal());
        var description=proposal.withObject("event").putObject("projectName").put("value","羽毛球").put("status","conflict");description.putArray("alternatives").add("羽毛球").add("乒乓球");
        proposal.withObject("event").withObject("name").put("status","filled").putArray("sources").addObject().put("kind","document").put("quote","赛事名称：合成赛");
        var fee=(com.fasterxml.jackson.databind.node.ObjectNode)proposal.path("units").get(0).path("feeAmount");fee.put("status","conflict").putArray("alternatives").add("20").add("30");
        sourceTask.setProposal(proposal.toString());
        when(dep(SportsAiTaskMapper.class).updateById(any(SportsAiTask.class))).thenReturn(1);
        run(true,()->{
            when(dep(SportsAiTaskMapper.class).selectById(1001L)).thenReturn(sourceTask);
            var event=json.createObjectNode().put("name","合成赛").put("projectName","羽毛球");var projects=json.createArrayNode();projects.addObject().put("feeAmount","20");projects.addObject();
            service.editCandidate(1001L,new CandidateEdit(7,event,null,projects));
        });
        var after=json.readTree(sourceTask.getProposal());
        for(String pointer:List.of("/event/projectName","/units/0/feeAmount")){assertEquals("filled",after.at(pointer+"/status").asText());assertEquals("manual",after.at(pointer+"/sources/0/kind").asText());assertTrue(after.at(pointer+"/alternatives").isEmpty());}
        assertEquals("document",after.at("/event/name/sources/0/kind").asText());assertEquals("赛事名称：合成赛",after.at("/event/name/sources/0/quote").asText());
        verifyNoInteractions(dep(EventPublicationService.class),dep(CompetitionSetupApi.class),dep(FeeApi.class));
    }
}
