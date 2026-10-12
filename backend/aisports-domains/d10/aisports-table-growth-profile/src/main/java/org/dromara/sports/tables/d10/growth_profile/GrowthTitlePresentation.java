package org.dromara.sports.tables.d10.growth_profile;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.dromara.sports.api.GrowthPolicyApi;
import java.util.HashSet;
import java.util.Map;

/** Read-only goals use current rules; only verified stored honours mean a title has been awarded. */
final class GrowthTitlePresentation {
    private GrowthTitlePresentation() {}

    static void apply(ObjectNode output, GrowthPolicyApi.Rule rule, String ownerType,
                      long checkins, long finishes, JsonNode verifiedTitles) {
        var earned = new HashSet<String>();
        for (var title : verifiedTitles) earned.add(title.path("title_code").asText());
        var goals = output.putArray("titleGoals");
        boolean personal = "person".equals(ownerType);
        Map<String, Integer> conditions = personal ? rule.personalTitles() : rule.teamTitles();
        String[][] catalogue = personal
            ? new String[][]{{"first_checkin", "首次登场", "checkin"}, {"first_finish", "首次完赛", "finish"}, {"regular", "赛场常客", "finish"}}
            : new String[][]{{"team_first", "默契初成", "team_finish"}, {"team_partners", "默契搭档", "team_finish"}, {"team_veterans", "久经赛场", "team_finish"}};
        for (String[] definition : catalogue) {
            Integer required = conditions.get(definition[0]);
            if (required == null) continue;
            long current = Math.max(0, "checkin".equals(definition[2]) ? checkins : finishes);
            var goal = goals.addObject();
            goal.put("code", definition[0]);
            goal.put("title", definition[1]);
            goal.put("milestone", definition[2]);
            goal.put("required", required);
            goal.put("current", current);
            goal.put("remaining", Math.max(0, required - current));
            goal.put("awarded", earned.contains(definition[0]));
            goal.put("eligible", current >= required);
        }
    }
}
