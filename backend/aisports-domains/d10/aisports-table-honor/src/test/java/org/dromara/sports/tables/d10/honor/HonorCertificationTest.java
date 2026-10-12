package org.dromara.sports.tables.d10.honor;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.sports.api.StoredObjectApi;
import org.dromara.sports.platform.core.*;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

/** Mocked authorization/version/state boundaries; not proof of any actual championship or migration. */
@Tag("local")
class HonorCertificationTest {
    final ObjectMapper json=new ObjectMapper();final ScopedJdbc db=mock(ScopedJdbc.class);
    final StoredObjectApi objects=mock(StoredObjectApi.class);final ActionDispatcher actions=mock(ActionDispatcher.class);
    @SuppressWarnings("unchecked") final ObjectProvider<ActionDispatcher> provider=mock(ObjectProvider.class);
    final HonorCertificationService service=new HonorCertificationService(db,json,objects,provider);
    final String claim="{\"eventYear\":2020,\"eventName\":\"合成赛事记录（仅单测）\",\"sportId\":\"300\",\"place\":1,\"level\":\"world\",\"sourceUrl\":\"https://example.invalid/results\",\"proofFileIds\":[\"501\"]}";
    Map<String,Object> row(String state) {
        var r=new HashMap<String,Object>();r.put("id",99L);r.put("applicant_account_id",100L);r.put("person_id",200L);r.put("sport_id",300L);r.put("version",7);r.put("title","待认证 · 合成记录");r.put("status",state.equals("approved")?"verified":state.equals("revoked")?"revoked":"pending");r.put("certification_status",state);r.put("details_text",claim);r.put("verified_text","{}");r.put("history_text","[]");return r;
    }
    void setup(Map<String,Object> h) {
        when(provider.getObject()).thenReturn(actions);when(actions.available()).thenReturn(service.capabilities());
        when(db.count(anyString(),any(Object[].class))).thenReturn(1L);
        when(db.one(anyString(),any(Object[].class))).thenAnswer(c->{String sql=c.getArgument(0);if(sql.contains("JOIN asp_person"))return Map.of("id",200L,"legal_name","合成申请人","version",3,"verification_status","unverified","person_status","active","account_status","active","birth_year",1990,"has_identity_document",false);return sql.contains("FROM asp_sport")?Map.of("id",300L,"name","羽毛球"):h;});
    }
    org.mockito.MockedStatic<LoginHelper> participant(long id) {
        var l=mockStatic(LoginHelper.class);l.when(LoginHelper::isLogin).thenReturn(true);l.when(LoginHelper::getUserType).thenReturn(UserType.PLATFORM_USER);l.when(LoginHelper::getUserId).thenReturn(id);return l;
    }
    ObjectNode input(){return json.createObjectNode().put("honorId","99").put("expectedVersion",7);}
    ObjectNode review(String decision){return input().put("decision",decision).put("expectedPersonVersion","3").put("reason","合成材料核对记录").put("verifiedDetailsJson","{\"eventYear\":2019,\"eventName\":\"独立确认的合成赛事（仅单测）\",\"sportId\":\"300\",\"place\":2,\"level\":\"world\",\"officialIssuer\":\"合成公布单位\",\"officialResultsUrl\":\"https://example.invalid/official\"}");}
    @Test void foreignAccountCannotReadOrSubmit() {setup(row("draft"));try(var l=participant(101)){assertThrows(ServiceException.class,()->service.detail(99));assertThrows(ServiceException.class,()->service.execute("honor.certification.submit",input()));verifyNoInteractions(objects);verify(db,never()).update(anyString(),any(Object[].class));}}
    @Test void staleProofVersionFailsBeforeStorageOrLiveGate() {setup(row("draft"));try(var l=participant(100)){assertThrows(ServiceException.class,()->service.upload(99,6,new byte[]{1}));verifyNoInteractions(objects,actions);verify(db,never()).update(anyString(),any(Object[].class));}}
    @Test void closedProofChannelCannotWriteStorage() {setup(row("draft"));when(actions.available()).thenReturn(List.of());try(var l=participant(100)){assertThrows(ServiceException.class,()->service.upload(99,7,new byte[]{1}));verifyNoInteractions(objects);verify(db,never()).update(anyString(),any(Object[].class));}}
    @Test void storageFailureDoesNotOverwriteApplication() {setup(row("draft"));when(objects.keepHonorProof(eq(100L),any())).thenThrow(new ServiceException("对象存储暂不可用"));try(var l=participant(100)){assertThrows(ServiceException.class,()->service.upload(99,7,new byte[]{1}));verify(db,never()).update(anyString(),any(Object[].class));}}
    @Test void missingOrForeignProofPreventsSubmit() {var h=row("draft");h.put("details_text",claim.replace("[\"501\"]","[]"));setup(h);try(var l=participant(100)){assertThrows(ServiceException.class,()->service.execute("honor.certification.submit",input()));h.put("details_text",claim);when(db.count(contains("FROM asp_file"),any(Object[].class))).thenReturn(0L);assertThrows(ServiceException.class,()->service.execute("honor.certification.submit",input()));verify(db,never()).update(anyString(),any(Object[].class));}}
    @Test void submittedFactsCannotBeEditedInPlace() {setup(row("submitted"));try(var l=participant(100)){assertThrows(ServiceException.class,()->service.execute("honor.certification.save",input().put("detailsJson",claim)));verify(db,never()).update(anyString(),any(Object[].class));}}
    @Test void ordinaryReviewerCannotApprove() {setup(row("submitted"));try(var b=mockStatic(BusinessIdentity.class)){b.when(BusinessIdentity::isSuperAdmin).thenReturn(false);assertThrows(ServiceException.class,()->service.execute("honor.certification.review",review("approve")));verifyNoInteractions(db,objects);}}
    @Test void agentCannotTouchPrivateFactsOrGrantHonor() {TrustedRunContext.bind(new AgentRunAccess.RunPrincipal(1L,"platform",100L,"000000",null,Set.of(),"{}"));try{assertThrows(ServiceException.class,service::mine);assertThrows(ServiceException.class,()->service.execute("honor.certification.review",review("approve")));assertThrows(ServiceException.class,()->service.proof(99,501));verifyNoInteractions(db,objects);}finally{TrustedRunContext.clear();}}
    @Test void staleReviewRejectsBeforeDecisionWrites() {setup(row("submitted"));try(var b=mockStatic(BusinessIdentity.class)){b.when(BusinessIdentity::isSuperAdmin).thenReturn(true);assertThrows(ServiceException.class,()->service.execute("honor.certification.review",review("approve").put("expectedVersion",6)));verify(db,never()).update(anyString(),any(Object[].class));}}
    @Test void approvalDerivesActualConfirmedFactsAndNeverAwardsGrowth() {setup(row("submitted"));try(var b=mockStatic(BusinessIdentity.class)){b.when(BusinessIdentity::isSuperAdmin).thenReturn(true);b.when(BusinessIdentity::getUserIdStr).thenReturn("1");var r=service.execute("honor.certification.review",review("approve"));assertEquals("approved",r.path("status").asText());verify(db).update(startsWith("UPDATE asp_honor SET title="),eq("2019 · 独立确认的合成赛事（仅单测） · 羽毛球 · 世界亚军"),eq(300L),eq("verified"),eq("approved"),contains("officialResultsUrl"),contains("\"state\":\"approved\""),eq(99L));verify(db,never()).update(contains("asp_growth"),any(Object[].class));}}
    @Test void revokedCertificationCannotBeWorn() {setup(row("revoked"));try(var l=participant(100)){assertThrows(ServiceException.class,()->service.execute("honor.certification.wear",input().put("ready",true)));verify(db,never()).update(anyString(),any(Object[].class));}}
    @Test void unlinkedProofNeverReachesStorage() {setup(row("draft"));try(var l=participant(100)){assertThrows(ServiceException.class,()->service.proof(99,502));verifyNoInteractions(objects);}}
    @Test void revocationRemovesWearAndPublicConsentInSameWrite() {setup(row("approved"));try(var b=mockStatic(BusinessIdentity.class)){b.when(BusinessIdentity::isSuperAdmin).thenReturn(true);b.when(BusinessIdentity::getUserIdStr).thenReturn("1");var r=service.execute("honor.certification.review",review("revoke"));assertEquals("revoked",r.path("status").asText());verify(db).update(contains("certification_worn=false,certification_public=false"),any(Object[].class));}}
    @Test void claimsCannotSupplyStatusOrFutureYear() {assertThrows(ServiceException.class,()->HonorCertificationRules.claim(json,claim.replace("\"place\":1","\"status\":\"approved\",\"place\":1")));assertThrows(ServiceException.class,()->HonorCertificationRules.claim(json,claim.replace("2020","2999")));assertThrows(ServiceException.class,()->HonorCertificationRules.claim(json,claim.replace("\"place\":1","\"place\":4")));}
    @Test void publicProjectionRequiresConsentAndNeverIncludesProofs() {when(db.list(anyString(),any(Object[].class))).thenReturn(List.of(Map.of("id",99L,"title","2019 · 合成赛事 · 羽毛球 · 世界亚军","sport_id",300L,"certification_worn",true,"certification_public",true,"verified_text","{\"eventYear\":2019,\"eventName\":\"合成赛事\",\"sportName\":\"羽毛球\",\"place\":2}")));var projection=service.publicHonors(100,null);assertEquals(1,projection.size());assertFalse(json.valueToTree(projection).toString().contains("proofFileIds"));verify(db).list(contains("h.certification_public AND d.public_visible"),eq(100L),isNull(),isNull(),eq(true));}
    @Test void newRegisteredCertificationAbilitiesAreManualAndVersioned() {for(var c:service.capabilities()){assertFalse(c.agent());assertTrue(c.inputSchema().path("required").toString().contains("expectedVersion"));}assertTrue(service.capabilities().stream().filter(c->c.code().endsWith("review")).findFirst().orElseThrow().confirmation());}
    @Test void reviewPreviewBindsPrivateApplicantArchiveAndItsVersion() {setup(row("submitted"));try(var b=mockStatic(BusinessIdentity.class)){b.when(BusinessIdentity::isSuperAdmin).thenReturn(true);var preview=service.preview("honor.certification.review",review("approve"));assertEquals("合成申请人",preview.path("applicantIdentity").path("legalName").asText());assertEquals(3,preview.path("applicantIdentity").path("personVersion").asInt());assertEquals("unverified",preview.path("applicantIdentity").path("profileVerificationStatus").asText());assertFalse(preview.toString().contains("identity_hash"));}}
    @Test void changedApplicantArchiveVersionStopsApprovalBeforeAnyWrite() {setup(row("submitted"));try(var b=mockStatic(BusinessIdentity.class)){b.when(BusinessIdentity::isSuperAdmin).thenReturn(true);assertThrows(ServiceException.class,()->service.execute("honor.certification.review",review("approve").put("expectedPersonVersion","2")));verify(db,never()).update(anyString(),any(Object[].class));}}
    @Test void worldScopeIsExplicitAndAllThreeTitlesUseExactPlace() {assertThrows(ServiceException.class,()->HonorCertificationRules.claim(json,claim.replace("\"level\":\"world\",","")));for(int place=1;place<=3;place++){var facts=HonorCertificationRules.claim(json,claim.replace("\"place\":1","\"place\":"+place));assertTrue(HonorCertificationRules.title(facts,"羽毛球").endsWith(new String[]{"","世界冠军","世界亚军","世界季军"}[place]));}}
}
