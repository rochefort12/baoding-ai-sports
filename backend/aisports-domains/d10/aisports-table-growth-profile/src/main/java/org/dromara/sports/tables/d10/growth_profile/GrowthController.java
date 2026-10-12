package org.dromara.sports.tables.d10.growth_profile;
import cn.dev33.satoken.annotation.SaCheckLogin;
import com.fasterxml.jackson.databind.JsonNode;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.springframework.web.bind.annotation.*;
@RestController @SaCheckLogin @RequestMapping("/sports/growth") @RequiredArgsConstructor
public class GrowthController {
    private final GrowthService growth;
    @GetMapping public R<JsonNode> home(){return R.ok(growth.home());}
    @GetMapping("/card") public R<JsonNode> card(@RequestParam Long sportId,@RequestParam(required=false) Long teamId){return R.ok(growth.card(sportId,teamId));}
    @GetMapping("/teams/{id}/board") public R<JsonNode> board(@PathVariable Long id){return R.ok(growth.leaderboard(id));}
}
