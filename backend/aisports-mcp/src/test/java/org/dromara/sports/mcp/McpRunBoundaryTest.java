package org.dromara.sports.mcp;
import org.dromara.sports.platform.core.*;
import org.dromara.common.tenant.helper.TenantHelper;
import org.junit.jupiter.api.*;
import org.springframework.mock.web.*;
import jakarta.servlet.FilterChain;
import java.util.Set;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;
@Tag("local") class McpRunBoundaryTest {
 private MockHttpServletRequest request(){var r=new MockHttpServletRequest("POST","/mcp");r.setServerName("localhost");r.setRemoteAddr("127.0.0.1");r.addHeader("X-Sports-Run","private-unit-run");return r;}
 @Test void runCredentialCannotBeUsedFromAnotherMachine()throws Exception{var access=mock(AgentRunAccess.class);var f=new McpAuthenticationFilter(Set.of(),Set.of("localhost"),access);var r=request();r.setRemoteAddr("192.168.1.200");var out=new MockHttpServletResponse();var chain=mock(FilterChain.class);f.doFilter(r,out,chain);assertEquals(403,out.getStatus());verifyNoInteractions(access,chain);}
 @Test void revokedRunFailsBeforeToolCode()throws Exception{var access=mock(AgentRunAccess.class);when(access.authorize(anyString())).thenThrow(BusinessSupport.fail("revoked",403));var f=new McpAuthenticationFilter(Set.of(),Set.of("localhost"),access);var out=new MockHttpServletResponse();var chain=mock(FilterChain.class);try(var tenant=mockStatic(TenantHelper.class)){f.doFilter(request(),out,chain);}assertEquals(403,out.getStatus());verifyNoInteractions(chain);assertNull(TrustedRunContext.current());}
 @Test void runActorIsServerIssuedAndClearedAfterRequest()throws Exception{var access=mock(AgentRunAccess.class);var p=new AgentRunAccess.RunPrincipal(10L,"platform",20L,null,null,Set.of("room.query"),"{}");when(access.authorize("private-unit-run")).thenReturn(p);var f=new McpAuthenticationFilter(Set.of(),Set.of("localhost"),access);try(var tenant=mockStatic(TenantHelper.class)){f.doFilter(request(),new MockHttpServletResponse(),(req,res)->{assertEquals(20L,TrustedRunContext.current().actorId());assertEquals(Set.of("room.query"),TrustedRunContext.current().capabilities());});}assertNull(TrustedRunContext.current());}
}
