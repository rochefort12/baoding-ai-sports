package org.dromara.sports.tables.d13.agent_run;
import cn.dev33.satoken.annotation.SaIgnore;
import com.fasterxml.jackson.databind.JsonNode;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

/** Run tokens stay between local services. Every material read revalidates the live run scope. */
@SaIgnore @RestController @RequiredArgsConstructor @RequestMapping("/sports/internal/agents")
public class AgentInternalController {
    private final AgentRuns runs;
    @GetMapping("/{id}/materials/{fileId}") public JsonNode material(@RequestHeader(value="X-Sports-Run",required=false)String token,@PathVariable long id,@PathVariable long fileId,@RequestParam int offset){return runs.materialBatch(token,id,fileId,offset);}
    @PostMapping("/{id}/progress") public void progress(@RequestHeader(value="X-Sports-Run",required=false)String token,@PathVariable long id,@RequestBody JsonNode progress){runs.progress(token,id,progress);}
}
