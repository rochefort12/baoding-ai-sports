package org.dromara.sports.tables.d10.growth_policy;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.platform.core.ScopedJdbc;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.util.Map;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@Tag("local")
class GrowthPoliciesCompatibilityTest {
    private final ScopedJdbc db=mock(ScopedJdbc.class);
    private final ObjectMapper json=new ObjectMapper();
    private final GrowthPolicies policies=new GrowthPolicies(db,json);
    private String rules(String thresholds,String names) {
        return "{\"checkinPoints\":10,\"finishPoints\":30,\"teamFinishPoints\":40,\"thresholds\":"+thresholds+
            ",\"rankNames\":"+names+",\"personalTitles\":{\"first_checkin\":1,\"first_finish\":1,\"regular\":3},"+
            "\"teamTitles\":{\"team_first\":1,\"team_partners\":3,\"team_veterans\":10}}";
    }
    @Test void historicalSevenAndCurrentEightRulesBothRemainReadable() {
        when(db.one(anyString(),eq(42L))).thenReturn(
            Map.of("revision",1,"rules",rules("[0,40,120,400,1000,2400,4800]","[\"新星\",\"青铜\",\"白银\",\"黄金\",\"铂金\",\"钻石\",\"荣耀\"]")),
            Map.of("revision",2,"rules",rules("[0,40,120,400,1000,2400,4800,9600]","[\"新星\",\"青铜\",\"白银\",\"黄金\",\"铂金\",\"钻石\",\"星耀\",\"王者\"]")));
        assertEquals("荣耀",policies.current(42L).rankNames().get(6));
        var current=policies.current(42L);
        assertEquals("王者",current.rankNames().get(7)); assertEquals(10,current.checkinPoints());
        assertEquals(30,current.finishPoints()); assertEquals(40,current.teamFinishPoints());
    }
    @Test void newLastThresholdMustIncreaseRatherThanSilentlyGrantingKing() {
        when(db.one(anyString(),eq(42L))).thenReturn(Map.of("revision",2,"rules",
            rules("[0,40,120,400,1000,2400,4800,4800]","[\"新星\",\"青铜\",\"白银\",\"黄金\",\"铂金\",\"钻石\",\"星耀\",\"王者\"]")));
        assertThrows(ServiceException.class,()->policies.current(42L));
    }
    @Test void ninthLegendRuleRemainsCompatibleAndKeepsRewards() {
        when(db.one(anyString(),eq(42L))).thenReturn(Map.of("revision",5,"rules",rules(
            "[0,40,120,400,1000,2400,4800,9600,19200]",
            "[\"新星\",\"青铜\",\"白银\",\"黄金\",\"铂金\",\"钻石\",\"星耀\",\"王者\",\"传奇\"]")));
        var current=policies.current(42L);
        assertEquals(7,current.rank(19199)); assertEquals(8,current.rank(19200));
        assertEquals("传奇",current.rankNames().get(8)); assertEquals(10,current.checkinPoints());
        assertEquals(30,current.finishPoints()); assertEquals(40,current.teamFinishPoints());
    }
    @Test void legendThresholdMustNotReuseKingThreshold() {
        when(db.one(anyString(),eq(42L))).thenReturn(Map.of("revision",5,"rules",rules(
            "[0,40,120,400,1000,2400,4800,9600,9600]",
            "[\"新星\",\"青铜\",\"白银\",\"黄金\",\"铂金\",\"钻石\",\"星耀\",\"王者\",\"传奇\"]")));
        assertThrows(ServiceException.class,()->policies.current(42L));
    }
}
