package org.dromara.sports.tables.d03.team_room;
import cn.dev33.satoken.annotation.SaCheckLogin;
import com.fasterxml.jackson.databind.JsonNode;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.springframework.web.bind.annotation.*;
@RestController @SaCheckLogin @RequestMapping("/sports/rooms") @RequiredArgsConstructor
public class RoomController {
    private final RoomService rooms;
    @GetMapping public R<JsonNode> home(){return R.ok(rooms.home());}
    @GetMapping("/units/{id}") public R<JsonNode> options(@PathVariable Long id){return R.ok(rooms.options(id));}
    @GetMapping("/{id}") public R<JsonNode> detail(@PathVariable Long id){return R.ok(rooms.detail(id));}
}
