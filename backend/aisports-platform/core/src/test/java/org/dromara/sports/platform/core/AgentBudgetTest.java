package org.dromara.sports.platform.core;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.*;
import static org.junit.jupiter.api.Assertions.*;
@Tag("local") class AgentBudgetTest {
    final ObjectMapper json=new ObjectMapper();
    @Test void configuredLimitsDriveTheRun()throws Exception{var b=AgentBudget.read(json.readTree("{\"maxDepth\":1,\"maxToolsPerTurn\":5,\"activeSeconds\":45,\"maxTokensPerTurn\":4000,\"maxTokensTotal\":8000,\"maxChildren\":1}"));assertEquals(5,b.maxToolsPerTurn());assertEquals(45,b.activeSeconds());assertEquals(8000,b.maxTokensTotal());}
    @Test void malformedOrEnlargedLimitsFailClosed()throws Exception{for(String value:new String[]{"{\"maxDepth\":4}","{\"maxToolsPerTurn\":0}","{\"activeSeconds\":\"300\"}","{\"maxTokensTotal\":-1}"}){var node=json.readTree(value);assertThrows(RuntimeException.class,()->AgentBudget.read(node));}}
    @Test void childCannotEnlargeParentBudget(){var parent=new AgentBudget(1,5,45,4000,8000,1);var child=new AgentBudget(3,30,300,30000,120000,4);assertEquals(parent,child.narrow(parent));}
}
