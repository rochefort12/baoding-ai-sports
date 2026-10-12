package org.dromara.sports.tables.d10.growth_profile;

import com.fasterxml.jackson.databind.node.ObjectNode;
import org.dromara.sports.api.GrowthPolicyApi;

/** Current rule determines display only. Existing growth facts and their historical policy are unchanged. */
final class GrowthRankPresentation {
    private GrowthRankPresentation() {}

    static void apply(ObjectNode output, GrowthPolicyApi.Rule rule, long points) {
        int rank = rule.rank(points), highest = rule.thresholds().size() - 1;
        output.put("rank", rule.rankNames().get(rank));
        output.put("rankIndex", rank);
        output.put("maxRankIndex", highest);
        output.put("policyVersion", rule.version());
        output.put("nextRank", rule.rankNames().get(Math.min(rank + 1, highest)));
        output.put("nextThreshold", rank == highest ? points : rule.thresholds().get(rank + 1));
        output.put("rankThreshold", rule.thresholds().get(rank));
        var ranks = output.putArray("ranks");
        for (int index = 0; index <= highest; index++) {
            var item = ranks.addObject();
            item.put("index", index);
            item.put("name", rule.rankNames().get(index));
            item.put("threshold", rule.thresholds().get(index));
        }
    }
}
