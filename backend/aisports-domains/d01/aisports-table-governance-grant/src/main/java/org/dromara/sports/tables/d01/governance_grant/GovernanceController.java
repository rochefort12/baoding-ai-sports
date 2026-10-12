package org.dromara.sports.tables.d01.governance_grant;
import cn.dev33.satoken.annotation.SaCheckLogin;
import com.fasterxml.jackson.databind.JsonNode;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.springframework.web.bind.annotation.*;
@RestController @SaCheckLogin @RequestMapping("/sports/government") @RequiredArgsConstructor
public class GovernanceController {
    private final GovernanceService government;
    @GetMapping public R<JsonNode> home(){return R.ok(government.dashboard());}
    @GetMapping("/administration") public R<JsonNode> administration(){return R.ok(government.administration());}
}
