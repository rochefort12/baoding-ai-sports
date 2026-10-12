package org.dromara.sports.tables.d10.honor;

import cn.dev33.satoken.annotation.SaCheckLogin;
import cn.dev33.satoken.annotation.SaIgnore;
import com.fasterxml.jackson.databind.JsonNode;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.api.HonorDisplayApi;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import java.io.IOException;
import java.util.List;
import static org.dromara.sports.platform.core.BusinessSupport.fail;

@RestController @RequiredArgsConstructor @RequestMapping("/sports/honors/certifications")
public class HonorCertificationController {
    private final HonorCertificationService service;
    @GetMapping @SaCheckLogin public R<JsonNode> mine(){return R.ok(service.mine());}
    @GetMapping("/review") @SaCheckLogin public R<JsonNode> review(@RequestParam(defaultValue="submitted")String status){return R.ok(service.queue(status));}
    @GetMapping("/{honorId}") @SaCheckLogin public R<JsonNode> detail(@PathVariable long honorId){return R.ok(service.detail(honorId));}
    @GetMapping("/approved") @SaCheckLogin public R<List<HonorDisplayApi.CertifiedHonor>> approved(@RequestParam(required=false)Long sportId){return R.ok(service.myHonors(sportId));}
    @GetMapping("/public/{accountId}") @SaIgnore public R<List<HonorDisplayApi.CertifiedHonor>> publicFacts(@PathVariable long accountId,@RequestParam(required=false)Long sportId){return R.ok(service.publicHonors(accountId,sportId));}
    @PostMapping(value="/{honorId}/proof",consumes="multipart/form-data") @SaCheckLogin
    public R<JsonNode> upload(@PathVariable long honorId,@RequestParam long expectedVersion,@RequestPart("file")MultipartFile file)throws IOException {
        if(file.getSize()>5*1024*1024)throw fail("证明文件不能超过5MB",400);return R.ok(service.upload(honorId,expectedVersion,file.getBytes()));
    }
    @GetMapping("/{honorId}/proof/{fileId}") @SaCheckLogin
    public void proof(@PathVariable long honorId,@PathVariable long fileId,HttpServletResponse response)throws IOException {
        var body=service.proof(honorId,fileId);response.setContentType(body.contentType());response.setHeader("Cache-Control","no-store");response.setHeader("X-Content-Type-Options","nosniff");response.setHeader("Content-Disposition","inline; filename=\"honor-proof\"");response.getOutputStream().write(body.body());
    }
}
