package org.dromara.sports.platform.executor;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.platform.authz.ActionAuthorization;
import org.dromara.sports.platform.registry.CapabilityRegistry;
import org.dromara.sports.platform.core.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import org.junit.jupiter.api.*;
import java.util.*;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;

/** Guidance must not borrow a foreign role, a removed permission or a narrower execution grant. */
@Tag("local") class AgentGuidanceAuthorizationTest {
    final ObjectMapper json=new ObjectMapper();
    CapabilityDefinition definition(String permission){return BusinessSupport.capability(json,"government.qualify","主办方资格","asp_governance_grant",false,true,Set.of("government"),permission,Set.of(),Set.of("asp_organization"),"organizationId");}
    void principal(String actor,String permissions){TrustedRunContext.bind(new AgentRunAccess.RunPrincipal(1L,actor,2L,null,null,Set.of(),"{\"runtimePermissions\":"+permissions+"}"));}
    @AfterEach void clear(){TrustedRunContext.clear();}
    @Test void currentPermissionIsNecessaryEvenForManualGuidance(){var auth=new ActionAuthorization(mock(OrganizationSessionApi.class));var d=definition("sports:government:qualify");principal("government","[]");assertFalse(auth.guidanceAllowed(d));principal("government","[\"sports:government:qualify\"]");assertTrue(auth.guidanceAllowed(d));}
    @Test void permissionCannotBeCombinedWithAnotherActorRole(){var auth=new ActionAuthorization(mock(OrganizationSessionApi.class));principal("platform","[\"sports:government:qualify\"]");assertFalse(auth.guidanceAllowed(definition("sports:government:qualify")));}
    @Test void openManualEntranceDoesNotEnableTheAgent(){var registry=mock(CapabilityRegistry.class);var auth=mock(ActionAuthorization.class);var d=BusinessSupport.capability(json,"room.query","查看集结","asp_team_room",true,false,Set.of("platform"),"",Set.of(),Set.of());when(registry.definitions()).thenReturn(List.of(d));when(auth.guidanceAllowed(d)).thenReturn(true);when(registry.open("room.query","ui")).thenReturn(true);when(registry.open("room.query","agent")).thenReturn(true);principal("platform","[]");var executor=new BusinessExecutor(registry,auth,mock(JdbcTemplate.class),mock(PlatformTransactionManager.class),json);var result=executor.guidance().get(0);assertTrue(result.path("uiEnabled").asBoolean());assertFalse(result.path("agentEnabled").asBoolean());assertTrue(executor.available().isEmpty());}
}
