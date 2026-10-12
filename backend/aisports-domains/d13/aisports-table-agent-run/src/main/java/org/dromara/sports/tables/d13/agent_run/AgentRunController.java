package org.dromara.sports.tables.d13.agent_run;
import cn.dev33.satoken.annotation.SaCheckLogin;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.dromara.sports.api.AgentMaterialApi;
import java.util.*;
import static org.dromara.sports.platform.core.BusinessSupport.fail;
@RestController @SaCheckLogin @RequestMapping("/sports/agents/runs") @RequiredArgsConstructor
public class AgentRunController {
    private final AgentRuns runs;
    private final ObjectMapper json;
    @GetMapping public R<JsonNode> list(){return R.ok(runs.list());}
    @GetMapping("/{id}") public R<JsonNode> detail(@PathVariable long id){return R.ok(runs.detail(id));}
    @GetMapping(value="/{id}/stream",produces="text/event-stream") public void stream(@PathVariable long id,jakarta.servlet.http.HttpServletResponse response)throws java.io.IOException{org.dromara.sports.platform.core.VisibleProgressStream.write(response,()->runs.detail(id),v->!Set.of("running","waiting_children").contains(v.path("status").asText()));}
    @PostMapping public R<JsonNode> start(@RequestBody JsonNode input){return R.ok(runs.start(input));}
    @PostMapping("/materials") public R<JsonNode> startMaterial(@RequestParam String goal,@RequestParam boolean consent,@RequestParam(defaultValue="{}") String context,@RequestPart("files") MultipartFile[] files){var input=json.createObjectNode().put("goal",goal).put("consent",consent);if(context.length()>500)throw fail("页面对象提示过长",400);try{input.set("context",json.readTree(context));}catch(java.io.IOException e){throw fail("页面对象提示无效",400);}return R.ok(runs.start(input,uploads(files)));}
    @PostMapping("/{id}/materials") public R<JsonNode> addMaterial(@PathVariable long id,@RequestParam String message,@RequestPart("files") MultipartFile[] files){return R.ok(runs.answer(id,json.createObjectNode().put("message",message),uploads(files)));}
    private List<AgentMaterialApi.Upload> uploads(MultipartFile[] values){if(values==null||values.length<1||values.length>4)throw fail("每次请选择1至4份资料",400);long size=Arrays.stream(values).mapToLong(MultipartFile::getSize).sum();if(size>20L*1024*1024)throw fail("本次资料合计不能超过20MB",400);var result=new ArrayList<AgentMaterialApi.Upload>();try{for(var file:values)result.add(new AgentMaterialApi.Upload(file.getOriginalFilename(),file.getBytes()));return result;}catch(java.io.IOException e){throw fail("未能接收完整资料，请重新上传",400);}}
    @PostMapping("/{id}/answer") public R<JsonNode> answer(@PathVariable long id,@RequestBody JsonNode in){return R.ok(runs.answer(id,in));}
    @PostMapping("/{id}/stop") public R<JsonNode> stop(@PathVariable long id){return R.ok(runs.stop(id));}
    @PostMapping("/{id}/confirm") public R<JsonNode> confirm(@PathVariable long id,@RequestBody Confirm in){return R.ok(runs.confirm(id,in.messageId(),in.accepted()));}
    public record Confirm(long messageId,boolean accepted){}
}
