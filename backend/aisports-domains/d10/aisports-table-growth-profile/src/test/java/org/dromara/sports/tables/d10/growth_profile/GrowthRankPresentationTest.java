package org.dromara.sports.tables.d10.growth_profile;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.sports.api.GrowthPolicyApi;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.util.List;
import java.util.Map;
import static org.junit.jupiter.api.Assertions.*;

@Tag("local")
class GrowthRankPresentationTest {
    private final ObjectMapper json = new ObjectMapper();
    private GrowthPolicyApi.Rule current() {
        return new GrowthPolicyApi.Rule("participation-v2",10,30,40,
            List.of(0L,40L,120L,400L,1000L,2400L,4800L,9600L),
            List.of("新星","青铜","白银","黄金","铂金","钻石","星耀","王者"),Map.of(),Map.of());
    }
    @Test void zeroPointsStayNoviceRatherThanGrantingBronze() {
        var output=json.createObjectNode(); GrowthRankPresentation.apply(output,current(),0);
        assertEquals("新星",output.path("rank").asText()); assertEquals(40,output.path("nextThreshold").asLong());
    }
    @Test void originalBronzeThresholdAndPointsRemainUnchanged() {
        var output=json.createObjectNode(); GrowthRankPresentation.apply(output,current(),40);
        assertEquals("青铜",output.path("rank").asText()); assertEquals(1,output.path("rankIndex").asInt());
        assertEquals(120,output.path("nextThreshold").asLong()); assertEquals(8,output.path("ranks").size());
    }
    @Test void stellarCanProgressToKingInsteadOfPrematureHighestRank() {
        var output=json.createObjectNode(); GrowthRankPresentation.apply(output,current(),4800);
        assertEquals("星耀",output.path("rank").asText()); assertEquals("王者",output.path("nextRank").asText());
        assertEquals(9600,output.path("nextThreshold").asLong()); assertEquals(7,output.path("maxRankIndex").asInt());
    }
    @Test void kingHasNoArtificialNextThreshold() {
        var output=json.createObjectNode(); GrowthRankPresentation.apply(output,current(),9700);
        assertEquals("王者",output.path("rank").asText()); assertEquals(9700,output.path("nextThreshold").asLong());
    }
    @Test void historicalSevenRankRuleStillShowsItsOriginalGloryName() {
        var historical=new GrowthPolicyApi.Rule("participation-v1",10,30,40,
            List.of(0L,40L,120L,400L,1000L,2400L,4800L),
            List.of("新星","青铜","白银","黄金","铂金","钻石","荣耀"),Map.of(),Map.of());
        var output=json.createObjectNode(); GrowthRankPresentation.apply(output,historical,4800);
        assertEquals("荣耀",output.path("rank").asText()); assertEquals(6,output.path("maxRankIndex").asInt());
    }
    @Test void kingHasRealNextLegendWithoutInflatingCurrentPoints() {
        var legend=new GrowthPolicyApi.Rule("participation-v5",10,30,40,
            List.of(0L,40L,120L,400L,1000L,2400L,4800L,9600L,19200L),
            List.of("新星","青铜","白银","黄金","铂金","钻石","星耀","王者","传奇"),Map.of(),Map.of());
        var output=json.createObjectNode(); GrowthRankPresentation.apply(output,legend,9600);
        assertEquals("王者",output.path("rank").asText()); assertEquals("传奇",output.path("nextRank").asText());
        assertEquals(19200,output.path("nextThreshold").asLong()); assertEquals(8,output.path("maxRankIndex").asInt());
        GrowthRankPresentation.apply(output,legend,19200); assertEquals("传奇",output.path("rank").asText());
        assertEquals(19200,output.path("nextThreshold").asLong());
    }
}
