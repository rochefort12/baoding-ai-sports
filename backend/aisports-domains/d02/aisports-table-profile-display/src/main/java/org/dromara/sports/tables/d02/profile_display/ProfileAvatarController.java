package org.dromara.sports.tables.d02.profile_display;

import cn.dev33.satoken.annotation.SaCheckLogin;
import cn.dev33.satoken.annotation.SaIgnore;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;

@RestController
@RequestMapping("/sports/display")
@RequiredArgsConstructor
public class ProfileAvatarController {
    private final ProfileAvatarService avatars;

    @PostMapping(value="/avatar",consumes="multipart/form-data")
    @SaCheckLogin
    public R<ProfileAvatarService.AvatarReceipt> upload(@RequestParam long expectedVersion,@RequestPart("file") MultipartFile file) throws IOException {
        if (file.getSize()>5*1024*1024) throw org.dromara.sports.platform.core.BusinessSupport.fail("头像图片不能超过5MB",400);
        return R.ok(avatars.upload(file.getBytes(),expectedVersion));
    }

    @GetMapping("/avatar/{accountId}") @SaCheckLogin
    public void privateImage(@PathVariable long accountId,HttpServletResponse response) throws IOException { write(accountId,false,response); }

    @GetMapping("/public/{accountId}/avatar") @SaIgnore
    public void publicImage(@PathVariable long accountId,HttpServletResponse response) throws IOException { write(accountId,true,response); }

    private void write(long accountId,boolean anonymous,HttpServletResponse response) throws IOException {
        var image=avatars.image(accountId,anonymous);
        response.setContentType(image.contentType());
        response.setHeader("Cache-Control","no-store");
        response.setHeader("X-Content-Type-Options","nosniff");
        response.getOutputStream().write(image.body());
    }
}
