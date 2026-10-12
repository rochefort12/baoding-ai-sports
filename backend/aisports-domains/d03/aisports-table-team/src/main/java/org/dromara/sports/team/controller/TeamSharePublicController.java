package org.dromara.sports.team.controller;

import cn.dev33.satoken.annotation.SaIgnore;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.team.service.TeamService;
import org.springframework.web.bind.annotation.*;

/** 随机邀请凭据的最小匿名预览；登录、完整档案和确认写入保持在参赛者接口。 */
@SaIgnore
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/public/team-invitations")
public class TeamSharePublicController {
    private final TeamService teamService;

    @GetMapping("/{token}")
    public R<TeamService.SharePreviewCard> preview(@PathVariable String token) {
        return R.ok(teamService.previewShare(token));
    }
}
