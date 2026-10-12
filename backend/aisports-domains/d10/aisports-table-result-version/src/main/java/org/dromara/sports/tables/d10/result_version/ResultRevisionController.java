package org.dromara.sports.tables.d10.result_version;
import cn.dev33.satoken.annotation.SaCheckLogin;
import com.fasterxml.jackson.databind.JsonNode;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.springframework.web.bind.annotation.*;
@RestController @SaCheckLogin @RequestMapping("/sports/fixtures") @RequiredArgsConstructor
public class ResultRevisionController {private final ResultRevisionService results;@GetMapping("/events/{id}") public R<JsonNode> fixtures(@PathVariable Long id){return R.ok(results.fixtures(id));}}
