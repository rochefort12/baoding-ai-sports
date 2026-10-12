package org.dromara.sports.event.controller;

import cn.dev33.satoken.annotation.SaIgnore;
import com.fasterxml.jackson.databind.JsonNode;
import lombok.RequiredArgsConstructor;
import org.dromara.sports.api.StoredObjectApi;
import org.dromara.sports.event.ai.SportsEventRunAiTaskService;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Map;

/**
 * 网关回调。只认内部令牌，不接受登录令牌，也不能改成写赛事。
 */
@SaIgnore
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/internal/ai/tasks")
public class SportsEventAiInternalController {

    private final SportsEventRunAiTaskService taskService;
    @GetMapping("/{taskId}/files/{fileId}/images") public JsonNode images(@RequestHeader(value="X-Ai-Internal-Token",required=false)String token,@PathVariable long taskId,@PathVariable long fileId,@org.springframework.web.bind.annotation.RequestParam int offset){return taskService.internalImages(token,taskId,fileId,offset);}
    @PostMapping("/{taskId}/progress") public void progress(@RequestHeader(value="X-Ai-Internal-Token",required=false)String token,@PathVariable long taskId,@RequestBody JsonNode input){taskService.internalProgress(token,taskId,input);}

    @PostMapping("/{taskId}/tools")
    public Map<String, String> tool(@RequestHeader(value = "X-Ai-Internal-Token", required = false) String token,
                                    @PathVariable long taskId, @RequestBody ToolCall call) {
        String result = taskService.internalTool(token, taskId, call == null ? "" : call.name(), call == null ? null : call.arguments());
        return Map.of("result", result);
    }

    @GetMapping("/{taskId}/files/{fileId}")
    public void file(@RequestHeader(value = "X-Ai-Internal-Token", required = false) String token,
                     @PathVariable long taskId, @PathVariable long fileId, HttpServletResponse response) throws IOException {
        StoredObjectApi.DocumentBody body = taskService.internalFile(token, taskId, fileId);
        response.setContentType(body.contentType());
        response.getOutputStream().write(body.body());
    }

    @GetMapping(value = "/{taskId}/files/{fileId}/pages/{page}", produces = MediaType.IMAGE_PNG_VALUE)
    public void page(@RequestHeader(value = "X-Ai-Internal-Token", required = false) String token,
                     @PathVariable long taskId, @PathVariable long fileId, @PathVariable int page,
                     HttpServletResponse response) throws IOException {
        byte[] body = taskService.internalPage(token, taskId, fileId, page);
        response.setContentType(MediaType.IMAGE_PNG_VALUE);
        response.getOutputStream().write(body);
    }

    public record ToolCall(String name, JsonNode arguments) {
    }
}
