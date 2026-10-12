package org.dromara.sports.team;

import org.dromara.common.core.exception.ServiceException;

/**
 * 长期队伍里不依赖数据库的判断。服务在锁内装好事实后调用这里。
 */
public final class TeamRules {

    private TeamRules() {
    }

    public static void requireActive(boolean teamActive) {
        if (!teamActive) {
            throw new ServiceException("队伍已解散");
        }
    }

    public static void requireCaptain(boolean actorIsCaptain) {
        if (!actorIsCaptain) {
            throw new ServiceException("只有队长可以办理");
        }
    }

    public static void requireCanApply(boolean teamActive, boolean activeMember, boolean pending) {
        requireActive(teamActive);
        if (activeMember) {
            throw new ServiceException("你已经在队伍里");
        }
        if (pending) {
            throw new ServiceException("已经有一条待处理的入队申请或邀请");
        }
    }

    public static void requireCanInvite(boolean teamActive, boolean actorIsCaptain, boolean activeMember, boolean pending, boolean self) {
        requireActive(teamActive);
        requireCaptain(actorIsCaptain);
        if (self) {
            throw new ServiceException("不能邀请自己");
        }
        if (activeMember) {
            throw new ServiceException("对方已经在队伍里");
        }
        if (pending) {
            throw new ServiceException("已经有一条待处理的入队申请或邀请");
        }
    }

    public static void requireLeave(boolean teamActive, String role) {
        requireActive(teamActive);
        if ("captain".equals(role)) {
            throw new ServiceException("队长要先转让队长或解散队伍");
        }
        if (!"member".equals(role)) {
            throw new ServiceException("当前不能退出");
        }
    }

    public static void requireRemove(boolean teamActive, boolean actorIsCaptain, String targetRole) {
        requireActive(teamActive);
        requireCaptain(actorIsCaptain);
        if (!"member".equals(targetRole)) {
            throw new ServiceException("只能移除普通成员");
        }
    }

    public static void requireTransfer(boolean teamActive, boolean actorIsCaptain, boolean targetActiveMember, boolean targetIsCaptain) {
        requireActive(teamActive);
        requireCaptain(actorIsCaptain);
        if (targetIsCaptain || !targetActiveMember) {
            throw new ServiceException("只能转让给当前队员");
        }
    }

    public static void requireTeamSubmit(boolean teamActive, boolean actorIsCaptain, boolean rosterStillActive) {
        requireActive(teamActive);
        if (!actorIsCaptain) {
            throw new ServiceException("只有当前队长可以代表队伍报名");
        }
        if (!rosterStillActive) {
            throw new ServiceException("名单里有人已经不在队伍中，请先修改报名");
        }
    }
}
