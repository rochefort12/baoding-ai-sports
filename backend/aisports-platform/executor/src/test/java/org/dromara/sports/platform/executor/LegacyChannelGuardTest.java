package org.dromara.sports.platform.executor;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.sports.platform.authz.ActionAuthorization;
import org.dromara.sports.platform.registry.CapabilityRegistry;
import org.dromara.sports.platform.core.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import org.junit.jupiter.api.*;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;

@Tag("local") class LegacyChannelGuardTest {
    final ObjectMapper json=new ObjectMapper();
    final CapabilityRegistry registry=mock(CapabilityRegistry.class);
    final ActionAuthorization auth=mock(ActionAuthorization.class);
    final BusinessExecutor executor=new BusinessExecutor(registry,auth,mock(JdbcTemplate.class),mock(PlatformTransactionManager.class),json);
    @SportsAction(value="legacy.event.create",title="兼容赛事建立",capability="event.create") void entry(){}
    SportsAction annotation()throws Exception{return getClass().getDeclaredMethod("entry").getAnnotation(SportsAction.class);}
    @AfterEach void clear(){TrustedRunContext.clear();ActionContext.clear();}
    @Test void agentCannotFallBackToAnUnregisteredCompatibilityEntry()throws Exception{
        TrustedRunContext.bind(new AgentRunAccess.RunPrincipal(1L,"organizer",2L,"org",3L,Set.of("event.create"),"{}"));
        var called=new AtomicBoolean();assertThrows(RuntimeException.class,()->executor.legacy(annotation(),()->{called.set(true);return null;}));assertFalse(called.get());
    }
    @Test void closingRegistryAlsoClosesItsCompatibleUiEntry()throws Exception{
        var d=BusinessSupport.capability(json,"event.create","赛事草稿","asp_event",true,false,Set.of("organizer"),"",Set.of(),Set.of());
        when(registry.definition("event.create")).thenReturn(d);when(registry.open("event.create","ui")).thenReturn(false);
        var called=new AtomicBoolean();assertThrows(RuntimeException.class,()->executor.legacy(annotation(),()->{called.set(true);return null;}));assertFalse(called.get());verify(auth).check(d);
    }
}
