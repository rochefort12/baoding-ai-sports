package org.dromara.sports.team.service;

import lombok.RequiredArgsConstructor;
import org.dromara.sports.api.TeamMembershipApi;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

/**
 * 报名读取当前队伍事实的唯一入口。不回写报名。
 */
@Service
@RequiredArgsConstructor
public class TeamMembershipApiImpl implements TeamMembershipApi {

    private final TeamService teamService;

    @Override
    public Optional<ActiveTeam> findActive(Long teamId) {
        return teamService.findActive(teamId);
    }

    @Override
    public boolean isActiveCaptain(Long teamId, Long personId) {
        return teamService.isActiveCaptain(teamId, personId);
    }

    @Override
    public boolean containsActiveMembers(Long teamId, List<Long> personIds) {
        return teamService.containsActiveMembers(teamId, personIds);
    }

    @Override
    public boolean containsActiveAccounts(Long teamId, List<Long> accountIds) {
        return teamService.containsActiveAccounts(teamId, accountIds);
    }

    @Override
    public List<Long> activeCaptainTeamIds(Long personId) {
        return teamService.activeCaptainTeamIds(personId);
    }

    @Override
    public void requireSubmittable(Long teamId, Long captainPersonId, List<Long> personIds) {
        teamService.requireSubmittable(teamId, captainPersonId, personIds);
    }
}
