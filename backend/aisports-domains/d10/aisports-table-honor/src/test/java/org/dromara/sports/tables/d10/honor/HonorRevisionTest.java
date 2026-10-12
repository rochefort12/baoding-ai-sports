package org.dromara.sports.tables.d10.honor;
import com.fasterxml.jackson.databind.*;
import org.dromara.sports.api.*;
import org.dromara.sports.platform.core.*;
import org.dromara.common.core.exception.ServiceException;
import org.junit.jupiter.api.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
/** Mocked rejection boundaries; ordinary-role integration is recorded separately. */
@Tag("local")
class HonorRevisionTest {
 final ScopedJdbc db=mock(ScopedJdbc.class); final ObjectMapper json=new ObjectMapper();
 final OrganizationSessionApi org=mock(OrganizationSessionApi.class); final OrganizationQualificationApi qualification=mock(OrganizationQualificationApi.class);
 final HonorRevisionService service=new HonorRevisionService(db,json,org,qualification);
 final Map<String,Object> h=Map.of("id",99L,"event_id",500L,"registration_id",10L,"person_id",7L,"award_key","old","title","第一名","version",4L,"status","suspended","source_text","{\"unitId\":\"20\",\"rosterVersionId\":\"30\",\"awardKind\":\"placing\"}");
 void setup(String state){when(org.managedOrganization(1L)).thenReturn(Optional.of(new OrganizationSessionApi.ManagedOrganization(2L,"Synthetic","t",3L)));when(qualification.hasStaffAction("t",2L,3L,"organize")).thenReturn(true);when(db.count(anyString(),any(Object[].class))).thenReturn(1L);when(db.one(contains("FROM asp_honor"),any(Object[].class))).thenReturn(h);when(db.list(contains("FROM asp_honor"),any(Object[].class))).thenReturn(List.of(h));var result=new HashMap<String,Object>();result.put("match_id",40L);result.put("code","01");result.put("result_id",50L);result.put("revision",2L);result.put("status",state);result.put("performance","{}");when(db.list(contains("FROM asp_match m"),any(Object[].class))).thenReturn(List.of(result));}
 com.fasterxml.jackson.databind.node.ObjectNode input(){return json.createObjectNode().put("honorId","99").put("expectedVersion",4).put("decision","reissue").put("title","第二名").put("reason","合成核实依据");}
 @Test void staleClaimVersionRejectsBeforeAnyWrite(){setup("confirmed");try(var actor=mockStatic(BusinessIdentity.class)){actor.when(BusinessIdentity::getUserId).thenReturn(1L);assertThrows(ServiceException.class,()->service.execute("honor.resolve",input().put("expectedVersion",3)));verify(db,never()).update(anyString(),any(Object[].class));}}
 @Test void voidDependencyCannotBorrowAnotherConfirmedMatch(){setup("void");try(var actor=mockStatic(BusinessIdentity.class)){actor.when(BusinessIdentity::getUserId).thenReturn(1L);assertTrue(assertThrows(ServiceException.class,()->service.execute("honor.resolve",input())).getMessage().contains("缺少有效正式结果"));verify(db,never()).update(anyString(),any(Object[].class));}}
 @Test void changedOrMissingBasisFingerprintRejectsBeforeAnyWrite(){setup("confirmed");try(var actor=mockStatic(BusinessIdentity.class)){actor.when(BusinessIdentity::getUserId).thenReturn(1L);assertTrue(assertThrows(ServiceException.class,()->service.execute("honor.resolve",input().put("basisFingerprint","stale"))).getMessage().contains("依据已变化"));verify(db,never()).update(anyString(),any(Object[].class));}}
 @Test void anotherOrganizationCannotPreviewPrivateProofs(){setup("confirmed");when(db.count(anyString(),any(Object[].class))).thenReturn(0L);try(var actor=mockStatic(BusinessIdentity.class)){actor.when(BusinessIdentity::getUserId).thenReturn(1L);assertThrows(ServiceException.class,()->service.pending(500));verify(db,never()).list(anyString(),any(Object[].class));}}
 @Test void cancelledEventCannotReissueProof(){setup("confirmed");when(db.count(contains("holding_status='normal'"),any(Object[].class))).thenReturn(0L);try(var actor=mockStatic(BusinessIdentity.class)){actor.when(BusinessIdentity::getUserId).thenReturn(1L);assertTrue(assertThrows(ServiceException.class,()->service.execute("honor.resolve",input())).getMessage().contains("取消赛事"));verify(db,never()).update(anyString(),any(Object[].class));}}
 @Test void automatedAgentCannotResolveHumanAward(){TrustedRunContext.bind(new AgentRunAccess.RunPrincipal(1L,"platform",100L,"000000",null,Set.of(),"{}"));try{assertThrows(ServiceException.class,()->service.execute("honor.resolve",input()));verifyNoInteractions(db);}finally{TrustedRunContext.clear();}}
}
