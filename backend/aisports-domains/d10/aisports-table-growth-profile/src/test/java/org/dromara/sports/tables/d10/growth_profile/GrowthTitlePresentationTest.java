package org.dromara.sports.tables.d10.growth_profile;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.sports.api.GrowthPolicyApi;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.util.List;
import java.util.Map;
import static org.junit.jupiter.api.Assertions.*;

@Tag("local")
class GrowthTitlePresentationTest {
    private final ObjectMapper json = new ObjectMapper();
    private GrowthPolicyApi.Rule rules(int regular) {
        return new GrowthPolicyApi.Rule("participation-v5",10,30,40,List.of(0L),List.of("新星"),
            Map.of("first_checkin",1,"first_finish",1,"regular",regular),
            Map.of("team_first",1,"team_partners",3,"team_veterans",10));
    }
    @Test void reachingAConditionDoesNotInventAnAward() {
        var output=json.createObjectNode(); GrowthTitlePresentation.apply(output,rules(3),"person",1,1,json.createArrayNode());
        var first=output.path("titleGoals").get(0); assertTrue(first.path("eligible").asBoolean());
        assertFalse(first.path("awarded").asBoolean()); assertEquals(0,first.path("remaining").asLong());
        assertEquals(2,output.path("titleGoals").get(2).path("remaining").asLong());
    }
    @Test void administratorPublishedThresholdIsUsedInsteadOfHardcodedDefaults() {
        var output=json.createObjectNode(); GrowthTitlePresentation.apply(output,rules(7),"person",2,3,json.createArrayNode());
        assertEquals(7,output.path("titleGoals").get(2).path("required").asInt());
        assertEquals(4,output.path("titleGoals").get(2).path("remaining").asLong());
    }
    @Test void teamUsesCompletedTeamEventsRatherThanMemberCheckins() {
        var output=json.createObjectNode(); GrowthTitlePresentation.apply(output,rules(3),"team",100,1,json.createArrayNode());
        assertEquals("team_finish",output.path("titleGoals").get(0).path("milestone").asText());
        assertEquals(2,output.path("titleGoals").get(1).path("remaining").asLong());
        assertEquals(9,output.path("titleGoals").get(2).path("remaining").asLong());
    }
    @Test void historicalVerifiedHonourRemainsSeparateFromCurrentEligibility() {
        var output=json.createObjectNode(); var honours=json.createArrayNode(); honours.addObject().put("title_code","regular");
        GrowthTitlePresentation.apply(output,rules(7),"person",1,3,honours);
        var goal=output.path("titleGoals").get(2); assertTrue(goal.path("awarded").asBoolean());
        assertFalse(goal.path("eligible").asBoolean()); assertEquals(4,goal.path("remaining").asLong());
    }
}
