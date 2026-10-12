package org.dromara.sports.competition.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.competition.service.CompetitionService;
import org.dromara.sports.competition.service.CompetitionService.ProofCard;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 私人证明。公开页不能访问。队长不能代看队员的证明。
 */
@Validated
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/c/proofs")
public class CompetitionProofController {

    private final CompetitionService competitionService;

    @GetMapping
    public R<List<ProofCard>> mine(@RequestParam(defaultValue="false") boolean history) {
        return R.ok(competitionService.myProofs(history));
    }

    @GetMapping("/{honorId}")
    public R<ProofCard> proof(@PathVariable Long honorId) {
        return R.ok(competitionService.proof(honorId));
    }
}
