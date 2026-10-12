package org.dromara.sports.tables.d13.change_case;
import cn.dev33.satoken.annotation.SaCheckLogin;
import com.fasterxml.jackson.databind.JsonNode;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.springframework.web.bind.annotation.*;
@RestController @SaCheckLogin @RequestMapping("/sports/entry-management") @RequiredArgsConstructor
public class EntryHandoverController {private final EntryHandoverService handovers;@GetMapping("/pending") public R<JsonNode> pending(){return R.ok(handovers.pending());}@GetMapping("/{id}") public R<JsonNode> detail(@PathVariable Long id){return R.ok(handovers.detail(id));}}
