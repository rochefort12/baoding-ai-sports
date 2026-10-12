package org.dromara.sports.competition.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.competition.service.CompetitionService;
import org.dromara.sports.competition.service.CompetitionService.AwardCard;
import org.dromara.sports.competition.service.CompetitionService.CheckInCard;
import org.dromara.sports.competition.service.CompetitionService.EligiblePerson;
import org.dromara.sports.competition.service.CompetitionService.EntryChoice;
import org.dromara.sports.competition.service.CompetitionService.EventChoice;
import org.dromara.sports.competition.service.CompetitionService.ImportCard;
import org.dromara.sports.competition.service.CompetitionService.MatchCard;
import org.dromara.sports.competition.service.CompetitionService.ResultCard;
import org.dromara.sports.competition.service.CompetitionService.UnitChoice;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 承办方报到、手工场次、录分和发奖。正式结果本期不能改。
 */
@Validated
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/b/competition")
public class CompetitionOrganizerController {

    private final CompetitionService competitionService;

    @GetMapping("/events")
    public R<List<EventChoice>> events() {
        return R.ok(competitionService.events());
    }

    @GetMapping("/units")
    public R<List<UnitChoice>> units(@RequestParam @NotNull Long eventId) {
        return R.ok(competitionService.units(eventId));
    }

    @GetMapping("/events/{eventId}/eligible")
    public R<List<EligiblePerson>> eligible(@PathVariable Long eventId) {
        return R.ok(competitionService.eligible(eventId));
    }

    @PostMapping("/events/{eventId}/check-ins")
    public R<CheckInCard> checkIn(@PathVariable Long eventId, @Validated @RequestBody PersonRequest request) {
        return R.ok(competitionService.checkIn(eventId, request.unitId(), request.personId(), request.requestKey()));
    }

    @GetMapping("/units/{unitId}/entries")
    public R<List<EntryChoice>> entries(@PathVariable Long unitId) {
        return R.ok(competitionService.entries(unitId));
    }

    @GetMapping("/units/{unitId}/matches")
    public R<List<MatchCard>> matches(@PathVariable Long unitId) {
        return R.ok(competitionService.matches(unitId));
    }

    @PostMapping("/units/{unitId}/matches")
    public R<MatchCard> createMatch(@PathVariable Long unitId, @Validated @RequestBody MatchRequest request) {
        return R.ok(competitionService.createMatch(unitId, request.code(), request.registrationA(), request.registrationB(), request.requestKey()));
    }

    @PostMapping("/matches/{matchId}/result")
    public R<ResultCard> saveResult(@PathVariable Long matchId, @Validated @RequestBody ResultRequest request) {
        return R.ok(competitionService.saveResult(matchId, request.summary(), request.games(), request.outcomeA(), request.outcomeB(), request.requestKey()));
    }

    @PostMapping("/matches/{matchId}/finalize")
    public R<ResultCard> finalizeResult(@PathVariable Long matchId, @Validated @RequestBody KeyRequest request) {
        return R.ok(competitionService.finalizeResult(matchId, request.requestKey()));
    }

    @PostMapping("/events/{eventId}/result-import")
    public R<ImportCard> importResults(@PathVariable Long eventId, @Validated @RequestBody ImportRequest request) {
        return R.ok(competitionService.importResults(eventId, request.unitId(), request.text(), request.requestKey()));
    }

    @GetMapping("/units/{unitId}/awards")
    public R<List<AwardCard>> awards(@PathVariable Long unitId) {
        return R.ok(competitionService.awards(unitId));
    }

    @PostMapping("/awards")
    public R<AwardCard> grant(@Validated @RequestBody AwardRequest request) {
        return R.ok(competitionService.grant(request.registrationId(), request.title(), request.basis(), request.requestKey(), request.awardKind(), request.basisMatchIds()));
    }

    public record PersonRequest(@NotNull Long personId, @NotBlank String requestKey, Long unitId) {
    }

    public record MatchRequest(@NotBlank String code, @NotNull Long registrationA, @NotNull Long registrationB, @NotBlank String requestKey) {
    }

    public record ResultRequest(String summary, String games, @NotBlank String outcomeA, @NotBlank String outcomeB, @NotBlank String requestKey) {
    }

    public record KeyRequest(@NotBlank String requestKey) {
    }

    public record ImportRequest(@NotNull Long unitId, @NotBlank String text, @NotBlank String requestKey) {
    }

    public record AwardRequest(@NotNull Long registrationId, @NotBlank String title, @NotBlank String basis, @NotBlank String requestKey, String awardKind, List<Long> basisMatchIds) {
    }
}
