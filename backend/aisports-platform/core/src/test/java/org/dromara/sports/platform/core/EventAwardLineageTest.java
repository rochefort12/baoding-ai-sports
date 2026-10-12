package org.dromara.sports.platform.core;
import com.fasterxml.jackson.databind.*;
import org.junit.jupiter.api.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
@Tag("local")
class EventAwardLineageTest {
    final ObjectMapper json = new ObjectMapper();
    EventAwardLineage.Claim c(long id,long registration,String title,String source,String status) throws Exception {
        return new EventAwardLineage.Claim(id,registration,7,"award-"+id,title,json.readTree(source),status);
    }
    @Test void oldAndRenamedPlacingShareOneCurrentClaim() throws Exception {
        var old=c(1,10,"第二名","{}","verified"); var updated=c(2,10,"第二名-1","{}","verified");
        assertEquals(List.of(updated),EventAwardLineage.latest(List.of(old,updated)));
    }
    @Test void distinctProjectsAndSpecialAwardsAreNeverPersonDeduplicated() throws Exception {
        var rows=List.of(c(1,10,"第二名","{}","verified"),c(2,11,"第二名","{}","verified"),c(3,10,"体育精神奖","{}","verified"));
        assertEquals(3,EventAwardLineage.latest(rows).size());
    }
    @Test void suspendedOrRevokedNewestClaimCannotResurrectOldVerifiedProof() throws Exception {
        for(String status:List.of("suspended","revoked")){
            var newer=c(3,10,"第一名","{}",status);
            assertEquals(List.of(newer),EventAwardLineage.latest(List.of(c(1,10,"第二名","{}","verified"),newer)));
        }
    }
    @Test void legacyReissuesFollowTheirActualPreviousProofNotTitle() throws Exception {
        var old=c(1,10,"最佳表现奖","{}","verified"); var newer=c(3,10,"优胜奖","{\"previousHonorId\":\"1\"}","verified");
        assertEquals(EventAwardLineage.key(old,List.of(old,newer)),EventAwardLineage.key(newer,List.of(old,newer)));
    }
    @Test void explicitSpecialKindKeepsAPlacingNamedPrizeIndependent() throws Exception {
        var rows=List.of(c(1,10,"第一名","{}","verified"),c(2,10,"第一名","{\"awardKind\":\"special\",\"awardRootKey\":\"skill\"}","verified"));
        assertEquals(2,EventAwardLineage.latest(rows).size());
    }
    @Test void legacyPlacingRenameFollowsExplicitPreviousProofEvenWithoutRankWords() throws Exception {
        var old=c(1,10,"第一名","{}","revoked");var newer=c(2,10,"本届优胜者","{\"previousHonorId\":\"1\"}","verified");
        assertEquals("placing",EventAwardLineage.kind(newer,List.of(old,newer)));
        assertEquals(List.of(newer),EventAwardLineage.latest(List.of(old,newer)));
    }
    @Test void dependencyStaysInsideItsDeclaredProjectOrMatches() throws Exception {
        assertTrue(EventAwardLineage.dependsOn(json.readTree("{\"basisScope\":\"unit\",\"unitId\":\"10\"}"),5,10,false));
        assertFalse(EventAwardLineage.dependsOn(json.readTree("{\"basisScope\":\"unit\",\"unitId\":\"11\"}"),5,10,true));
        var special=json.readTree("{\"basisResults\":[{\"matchId\":\"6\"}]}");
        assertFalse(EventAwardLineage.dependsOn(special,5,10,true));assertTrue(EventAwardLineage.dependsOn(special,6,10,false));
        assertFalse(EventAwardLineage.dependsOn(json.readTree("{\"unitId\":\"11\"}"),5,10,true));
    }
    @Test void teamRecipientsShareAClaimButEachGetsOneCurrentProof() throws Exception {
        var a=c(1,10,"第一名","{}","verified");var b=new EventAwardLineage.Claim(2,10,8,"award-1","第一名",json.readTree("{}"),"verified");
        assertEquals(EventAwardLineage.key(a,List.of(a,b)),EventAwardLineage.key(b,List.of(a,b)));
        assertEquals(2,EventAwardLineage.latest(List.of(a,b)).size());
    }
    @Test void basisFingerprintBindsRevisionAndStatusButIsOrderIndependent() throws Exception {
        var a=json.readTree("[{\"matchId\":\"5\",\"resultId\":\"1\",\"revision\":1,\"status\":\"confirmed\"},{\"matchId\":\"6\",\"resultId\":\"2\",\"revision\":1,\"status\":\"confirmed\"}]");
        var reverse=json.createArrayNode().add(a.get(1)).add(a.get(0));
        assertEquals(EventAwardLineage.fingerprint(a),EventAwardLineage.fingerprint(reverse));
        ((com.fasterxml.jackson.databind.node.ObjectNode)a.get(0)).put("status","void");
        assertNotEquals(EventAwardLineage.fingerprint(a),EventAwardLineage.fingerprint(json.readTree(reverse.toString().replace("void","confirmed"))));
    }
}
