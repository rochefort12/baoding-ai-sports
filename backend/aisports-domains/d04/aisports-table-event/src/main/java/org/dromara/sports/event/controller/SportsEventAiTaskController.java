package org.dromara.sports.event.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.api.StoredObjectApi;
import org.dromara.sports.event.ai.SportsEventRunAiTaskService;
import org.dromara.sports.event.ai.SportsEventRunAiTaskService.ConfirmDraft;
import org.dromara.sports.event.ai.SportsEventRunAiTaskService.ConfirmResult;
import org.dromara.sports.event.ai.SportsEventRunAiTaskService.TalkReply;
import org.dromara.sports.event.ai.SportsEventRunAiTaskService.TalkRequest;
import org.dromara.sports.event.ai.SportsEventRunAiTaskService.TaskCard;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * 办赛人从资料创建赛事。模型走内部接口，不携带登录令牌。
 */
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/b/ai/tasks")
public class SportsEventAiTaskController {

    private final SportsEventRunAiTaskService taskService;
    @GetMapping(value="/{taskId}/stream",produces="text/event-stream") public void stream(@PathVariable long taskId,HttpServletResponse response)throws IOException{org.dromara.sports.platform.core.VisibleProgressStream.write(response,()->taskService.progress(taskId),v->!java.util.Set.of("UPLOADED","PROCESSING").contains(v.path("status").asText()));}

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public R<TaskCard> upload(@RequestParam boolean bailianConsent, @RequestPart("files") MultipartFile[] files) {
        return R.ok(taskService.upload(files, bailianConsent));
    }

    @PostMapping("/text")
    public R<TaskCard> text(@RequestBody TextRequest request) {
        return R.ok(taskService.startText(request != null && request.consent(), request == null ? null : request.text()));
    }

    public record TextRequest(boolean consent, String text) { }

    @GetMapping("/{taskId}")
    public R<TaskCard> detail(@PathVariable long taskId) {
        return R.ok(taskService.get(taskId));
    }

    @PostMapping(value="/{taskId}/materials",consumes=MediaType.MULTIPART_FORM_DATA_VALUE)
    public R<TaskCard> append(@PathVariable long taskId,@RequestParam boolean consent,@RequestParam Integer expectedVersion,@RequestPart("files") MultipartFile[] files){return R.ok(taskService.appendMaterials(taskId,files,consent,expectedVersion));}

    @PostMapping("/{taskId}/retry")
    public R<TaskCard> retry(@PathVariable long taskId) {
        return R.ok(taskService.retry(taskId));
    }

    @PostMapping("/{taskId}/abandon")
    public R<TaskCard> abandon(@PathVariable long taskId) {
        return R.ok(taskService.abandon(taskId));
    }

    @PostMapping("/{taskId}/confirm")
    public R<ConfirmResult> confirm(@PathVariable long taskId, @RequestBody ConfirmDraft draft) {
        return R.ok(taskService.confirm(taskId, draft));
    }

    @PutMapping("/{taskId}/candidate")
    public R<TaskCard> edit(@PathVariable long taskId,@RequestBody SportsEventRunAiTaskService.CandidateEdit edit){return R.ok(taskService.editCandidate(taskId,edit));}

    @GetMapping("/{taskId}/sources")
    public R<com.fasterxml.jackson.databind.JsonNode> sources(@PathVariable long taskId){return R.ok(taskService.sourceElements(taskId));}

    @GetMapping("/{taskId}/files/{fileId}/visuals/{index}")
    public void visual(@PathVariable long taskId,@PathVariable long fileId,@PathVariable int index,HttpServletResponse response)throws IOException{
        var body=taskService.previewVisual(taskId,fileId,index);response.setHeader("Cache-Control","private, no-store");response.setContentType(body.contentType());response.getOutputStream().write(body.body());
    }

    @PostMapping("/{taskId}/talk")
    public R<TalkReply> talk(@PathVariable long taskId, @RequestBody TalkRequest request) {
        return R.ok(taskService.talk(taskId, request));
    }

    @GetMapping("/{taskId}/files/{fileId}")
    public void file(@PathVariable long taskId, @PathVariable long fileId, HttpServletResponse response) throws IOException {
        StoredObjectApi.DocumentBody body = taskService.preview(taskId, fileId);
        response.setContentType(body.contentType());
        response.getOutputStream().write(body.body());
    }
}
