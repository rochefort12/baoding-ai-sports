package org.dromara.sports.tables.d02.profile_display;
import cn.dev33.satoken.annotation.SaCheckLogin;
import cn.dev33.satoken.annotation.SaIgnore;
import com.fasterxml.jackson.databind.JsonNode;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/sports/display") @RequiredArgsConstructor
public class ProfileDisplayController {
    private final ProfileDisplayService profiles;
    @GetMapping @SaCheckLogin public R<JsonNode> mine(){return R.ok(profiles.mine());}
    @GetMapping("/public/{id}") @SaIgnore public R<JsonNode> card(@PathVariable Long id){return R.ok(profiles.publicCard(id));}
}
