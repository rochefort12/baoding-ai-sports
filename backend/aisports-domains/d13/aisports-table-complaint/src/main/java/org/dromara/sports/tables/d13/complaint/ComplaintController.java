package org.dromara.sports.tables.d13.complaint;
import cn.dev33.satoken.annotation.SaCheckLogin;
import com.fasterxml.jackson.databind.JsonNode;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.springframework.web.bind.annotation.*;
@RestController @SaCheckLogin @RequestMapping("/sports/issues") @RequiredArgsConstructor
public class ComplaintController {private final ComplaintService issues;@GetMapping public R<JsonNode> list(){return R.ok(issues.mine());}@GetMapping("/{id}") public R<JsonNode> detail(@PathVariable Long id){return R.ok(issues.detail(id));}}
