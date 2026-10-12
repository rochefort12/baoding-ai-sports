package org.dromara.sports.competition.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.competition.service.CompetitionService;
import org.dromara.sports.competition.service.CompetitionService.OwnResultCard;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 本人已确认赛果。不返回录分草稿，也不返回其他成员的联系资料。
 */
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/c/results")
public class CompetitionResultController {

    private final CompetitionService competitionService;

    @GetMapping
    public R<List<OwnResultCard>> mine() {
        return R.ok(competitionService.myResults());
    }
}
