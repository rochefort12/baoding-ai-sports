package org.dromara.sports.platform.executor;

import cn.dev33.satoken.annotation.SaCheckLogin;
import cn.dev33.satoken.annotation.SaCheckPermission;
import com.fasterxml.jackson.databind.JsonNode;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.platform.core.*;
import org.dromara.sports.platform.registry.CapabilityRegistry;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@SaCheckLogin
@RequestMapping("/sports/platform")
@RequiredArgsConstructor
public class PlatformActionController {
    private final BusinessExecutor executor;
    private final CapabilityRegistry registry;
    @GetMapping("/capabilities") public R<List<CapabilityDefinition>> available(){return R.ok(executor.available());}
    @GetMapping("/receipts/{code}/{key}") public R<JsonNode> receipt(@PathVariable String code,@PathVariable String key){return R.ok(executor.lookup(code,key));}
    @PostMapping("/actions/{code}/preview") public R<JsonNode> preview(@PathVariable String code,@RequestBody JsonNode input){return R.ok(executor.preview(code,input));}
    @PostMapping("/actions/{code}/confirm") public R<String> confirm(@PathVariable String code,@RequestBody JsonNode input){return R.ok("确认已记录",executor.confirm(code,input).toString());}
    @PostMapping("/actions/{code}/execute") public R<JsonNode> execute(@PathVariable String code,@RequestBody ExecuteRequest request){return R.ok(executor.execute(code,request.input(),request.requestKey(),request.confirmationId()));}
    @GetMapping("/modules") @SaCheckPermission("sports:platform:inspect") public R<List<JsonNode>> modules(){return R.ok(registry.modules());}
    public record ExecuteRequest(JsonNode input,String requestKey,Long confirmationId) { }
}
