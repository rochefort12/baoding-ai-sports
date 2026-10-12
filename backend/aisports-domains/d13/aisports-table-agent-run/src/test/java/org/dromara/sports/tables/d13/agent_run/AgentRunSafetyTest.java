package org.dromara.sports.tables.d13.agent_run;

import com.fasterxml.jackson.databind.*;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.sports.api.*;
import org.dromara.sports.platform.core.*;
import org.junit.jupiter.api.*;
import org.mockito.MockedStatic;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.*;
import org.springframework.transaction.*;
import java.util.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import static org.junit.jupiter.api.Assertions.*;

/** Observable authorization, consent and subtree effects; database/mock boundaries are tested separately over HTTP. */
@Tag("local") class AgentRunSafetyTest {
    final ObjectMapper json=new ObjectMapper();final JdbcTemplate db=mock(JdbcTemplate.class);
    final ActionDispatcher actions=mock(ActionDispatcher.class,withSettings().extraInterfaces(HumanActionConfirmation.class));
    AgentRuns runs;MockedStatic<LoginHelper> login;boolean revoked;
    final TestTransactions manager=new TestTransactions();
    JsonNode input,preview;Map<String,Object> row;
    @BeforeEach void prepare()throws Exception {
        input=json.readTree("{\"roomId\":\"39\",\"expectedVersion\":1,\"ready\":true}");preview=json.readTree("{\"roomId\":\"39\",\"version\":1}");
        row=new HashMap<>();row.put("id",10L);row.put("actor_id",2L);row.put("actor_type","platform");row.put("agent_id",100L);row.put("agent_version_id",200L);row.put("status","waiting_confirmation");row.put("scope","{\"capabilities\":[\"room.ready\"]}");row.put("root_run_id",10L);row.put("parent_run_id",null);row.put("goal","核对准备");row.put("depth",0);row.put("version",1);
        var block=json.createObjectNode().put("kind","confirmation").put("code","room.ready");block.set("input",input);block.set("preview",preview);
        when(db.queryForList(anyString(),any(Object[].class))).thenAnswer(call->{String sql=call.getArgument(0);if(sql.startsWith("SELECT * FROM asp_agent_run")||sql.startsWith("SELECT r.*,a.id AS agent_id"))return List.of(row);if(sql.startsWith("SELECT blocks::text FROM asp_agent_message"))return List.of(Map.of("blocks",json.createArrayNode().add(block).toString()));return List.of();});
        when(db.queryForMap(anyString(),any(Object[].class))).thenAnswer(call->{String sql=call.getArgument(0);if(sql.startsWith("SELECT revision"))return Map.of("revision",3,"playbook_hash","test");return row;});
        when(db.queryForList(anyString(),eq(String.class),any(Object[].class))).thenAnswer(call->{String sql=call.getArgument(0);if(sql.startsWith("SELECT capability_code"))return revoked?List.of():List.of("room.ready");if(sql.startsWith("SELECT v.definition"))return List.of("");return List.of();});
        when(db.queryForObject(anyString(),eq(Integer.class),any(Object[].class))).thenReturn(1);
        when(db.queryForList(startsWith("WITH RECURSIVE tree"),eq(Long.class),any(Object[].class))).thenReturn(List.of(11L,12L));
        when(actions.preview(eq("room.ready"),any())).thenReturn(preview);
        when(((HumanActionConfirmation)actions).confirm(eq("room.ready"),any())).thenReturn(88L);
        when(actions.execute(eq("room.ready"),any(),anyString(),eq(88L))).thenAnswer(call->{assertEquals(10L,TrustedRunContext.current().runId());assertEquals(Set.of("room.ready"),TrustedRunContext.current().capabilities());return json.createObjectNode().put("receiptId","99").put("actionCode","room.ready").put("status","succeeded");});
        login=mockStatic(LoginHelper.class);login.when(LoginHelper::getUserId).thenReturn(2L);login.when(LoginHelper::getUserType).thenReturn(UserType.PLATFORM_USER);
        runs=new AgentRuns(db,json,actions,mock(OrganizationSessionApi.class),mock(AgentMaterialApi.class),manager);
    }
    @AfterEach void close(){runs.close();login.close();TrustedRunContext.clear();}
    @Test void revokedAgentGrantRejectsOldCardEvenWithHumanPermission(){revoked=true;assertThrows(RuntimeException.class,()->runs.confirm(10,20,true));verify(actions,never()).execute(anyString(),any(),anyString(),any());verify((HumanActionConfirmation)actions,never()).confirm(anyString(),any());}
    @Test void acceptedCardExecutesWithRunScopeAndLinksHumanConsent(){runs.confirm(10,20,true);verify(db).update("UPDATE asp_action_confirmation SET run_id=? WHERE id=?",10L,88L);verify(actions).execute("room.ready",input,"agent-confirm:10:20",88L);assertNull(TrustedRunContext.current());}
    @Test void changedObjectStopsBeforeConsent(){when(actions.preview(eq("room.ready"),any())).thenReturn(json.createObjectNode().put("version",2));assertThrows(RuntimeException.class,()->runs.confirm(10,20,true));verify((HumanActionConfirmation)actions,never()).confirm(anyString(),any());}
    @Test void confirmationCannotStartBeforeModelReservationSettles(){row.put("tokens_reserved",30000);assertThrows(RuntimeException.class,()->runs.confirm(10,20,true));verify((HumanActionConfirmation)actions,never()).confirm(anyString(),any());}
    @Test void confirmationContinuationUsesAnIndependentWorkerLease(){runs.confirm(10,20,true);assertTrue(manager.propagations.contains(TransactionDefinition.PROPAGATION_REQUIRES_NEW));}
    @Test void stoppingChildTargetsItsSubtreeRatherThanRootId(){runs.stop(11);verify(db).update(startsWith("UPDATE asp_agent_run SET status='stopped'"),eq(11L));verify(db).update(startsWith("UPDATE asp_agent_run SET status='stopped'"),eq(12L));verify(db,never()).update(startsWith("UPDATE asp_agent_run SET status='stopped'"),eq(10L));}
    @Test void sameBusinessInputKeepsOneRequestKeyAcrossRetries(){TrustedRunContext.bind(new AgentRunAccess.RunPrincipal(10L,"platform",2L,null,null,Set.of("room.ready"),"{}"));when(db.queryForObject(startsWith("SELECT root_run_id"),eq(Long.class),eq(10L))).thenReturn(10L);assertEquals(runs.requestKey("room.ready",input,"model-first"),runs.requestKey("room.ready",input,"model-new-key"));}
    @Test void readRecoveryRefreshesFactsWithoutRequiringAMutationReceipt(){
        TrustedRunContext.bind(new AgentRunAccess.RunPrincipal(10L,"platform",2L,null,null,Set.of("room.query"),"{}"));
        var d=BusinessSupport.capability(json,"room.query","本人房间","asp_team_room",true,false,Set.of("platform"),"",Set.of(),Set.of());
        when(actions.available()).thenReturn(List.of(d));
        when(db.queryForList(startsWith("SELECT name,status,summary"),any(Object[].class))).thenReturn(List.of(Map.of("name","room.query","status","succeeded","summary","{\"input\":{},\"requestKey\":\"old-read\",\"result\":{\"version\":1}}")));
        when(actions.preview(eq("room.query"),any())).thenReturn(json.createObjectNode().put("version",2));
        assertEquals(2,runs.recovery().path("records").get(0).path("result").path("version").asInt());verify(actions,never()).lookup(anyString(),anyString());
    }
    static class TestTransactions extends AbstractPlatformTransactionManager {
        protected Object doGetTransaction(){return new Object();}
        final List<Integer> propagations=new ArrayList<>();
        protected void doBegin(Object transaction,TransactionDefinition definition){propagations.add(definition.getPropagationBehavior());}
        protected void doCommit(DefaultTransactionStatus status){}
        protected void doRollback(DefaultTransactionStatus status){}
    }
}
