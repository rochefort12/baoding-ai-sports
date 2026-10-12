package org.dromara.sports.team.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.sports.team.service.TeamService;
import org.dromara.sports.team.service.TeamService.CandidateCard;
import org.dromara.sports.team.service.TeamService.PreviewCard;
import org.dromara.sports.team.service.TeamService.TeamDetail;
import org.dromara.sports.team.service.TeamService.TeamHome;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 参赛者的长期队伍。平台共享数据，不进组织租户。
 */
@Validated
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/sports/c/teams")
public class TeamParticipantController {

    private final TeamService teamService;

    @GetMapping
    public R<TeamHome> home() {
        return R.ok(teamService.home());
    }

    @PostMapping
    public R<TeamDetail> create(@Validated @RequestBody NameRequest request) {
        return R.ok(teamService.create(request.name()));
    }

    @GetMapping("/{teamId}/preview")
    public R<PreviewCard> preview(@PathVariable Long teamId) {
        return R.ok(teamService.preview(teamId));
    }

    @GetMapping("/{teamId}/candidates")
    public R<List<CandidateCard>> candidates(@PathVariable Long teamId) {
        return R.ok(teamService.candidates(teamId));
    }

    @GetMapping("/{teamId}")
    public R<TeamDetail> detail(@PathVariable Long teamId) {
        return R.ok(teamService.detail(teamId));
    }

    @PostMapping("/{teamId}/name")
    public R<TeamDetail> rename(@PathVariable Long teamId, @Validated @RequestBody NameRequest request) {
        return R.ok(teamService.rename(teamId, request.name()));
    }

    @PostMapping("/{teamId}/applications")
    public R<TeamHome> apply(@PathVariable Long teamId) {
        return R.ok(teamService.apply(teamId));
    }

    @PostMapping("/applications/{requestId}/cancel")
    public R<TeamHome> cancel(@PathVariable Long requestId) {
        return R.ok(teamService.cancel(requestId));
    }

    @PostMapping("/applications/{requestId}/approve")
    public R<TeamDetail> approve(@PathVariable Long requestId) {
        return R.ok(teamService.approve(requestId));
    }

    @PostMapping("/applications/{requestId}/reject")
    public R<TeamDetail> reject(@PathVariable Long requestId, @RequestBody(required = false) ReasonRequest request) {
        return R.ok(teamService.reject(requestId, request == null ? null : request.reason()));
    }

    @PostMapping("/{teamId}/invitations")
    public R<TeamDetail> invite(@PathVariable Long teamId, @Validated @RequestBody PhoneRequest request) {
        return R.ok(teamService.invite(teamId, request.phone(), Boolean.TRUE.equals(request.requestSms())));
    }

    @GetMapping("/invitations/{invitationId}")
    public R<TeamService.InvitationCard> invitation(@PathVariable Long invitationId) { return R.ok(teamService.invitation(invitationId)); }

    @GetMapping("/{teamId}/share-invitation")
    public R<TeamService.ShareLinkCard> shareLink(@PathVariable Long teamId) { return R.ok(teamService.shareLink(teamId)); }

    @PostMapping("/{teamId}/share-invitation")
    public R<TeamService.ShareLinkCard> createShare(@PathVariable Long teamId, @RequestBody(required=false) ShareRequest request) {
        return R.ok(teamService.createShareLink(teamId, request != null && Boolean.TRUE.equals(request.replace())));
    }

    @PostMapping("/{teamId}/share-invitation/revoke")
    public R<Void> revokeShare(@PathVariable Long teamId) { teamService.revokeShareLink(teamId); return R.ok(); }

    @PostMapping("/share-invitations/{token}/accept")
    public R<TeamService.ShareJoinCard> acceptShare(@PathVariable String token, @RequestBody ConfirmRequest request) {
        return R.ok(teamService.acceptShare(token, Boolean.TRUE.equals(request.confirmed())));
    }

    @GetMapping("/share-invitations/{token}")
    public R<TeamService.ShareConfirmationCard> shareConfirmation(@PathVariable String token) { return R.ok(teamService.shareConfirmation(token)); }

    @PostMapping("/invitations/{invitationId}/accept")
    public R<TeamHome> accept(@PathVariable Long invitationId) {
        return R.ok(teamService.accept(invitationId));
    }

    @PostMapping("/invitations/{invitationId}/decline")
    public R<TeamHome> decline(@PathVariable Long invitationId) {
        return R.ok(teamService.decline(invitationId));
    }

    @PostMapping("/invitations/{invitationId}/revoke")
    public R<TeamDetail> revoke(@PathVariable Long invitationId) {
        return R.ok(teamService.revoke(invitationId));
    }

    @PostMapping("/{teamId}/leave")
    public R<TeamHome> leave(@PathVariable Long teamId) {
        return R.ok(teamService.leave(teamId));
    }

    @PostMapping("/{teamId}/members/{memberId}/remove")
    public R<TeamDetail> remove(@PathVariable Long teamId, @PathVariable Long memberId) {
        return R.ok(teamService.remove(teamId, memberId));
    }

    @PostMapping("/{teamId}/captain")
    public R<TeamDetail> transfer(@PathVariable Long teamId, @Validated @RequestBody MemberRequest request) {
        return R.ok(teamService.transfer(teamId, request.memberId()));
    }

    @PostMapping("/{teamId}/disband")
    public R<TeamHome> disband(@PathVariable Long teamId) {
        return R.ok(teamService.disband(teamId));
    }

    public record NameRequest(@NotBlank String name) {
    }

    public record PhoneRequest(@NotBlank String phone, Boolean requestSms) {
    }

    public record ReasonRequest(String reason) {
    }

    public record MemberRequest(@NotNull Long memberId) {
    }

    public record ShareRequest(Boolean replace) { }
    public record ConfirmRequest(Boolean confirmed) { }
}
