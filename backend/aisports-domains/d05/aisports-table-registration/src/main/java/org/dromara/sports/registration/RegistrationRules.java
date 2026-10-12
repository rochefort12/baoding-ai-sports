package org.dromara.sports.registration;

import org.dromara.common.core.exception.ServiceException;

import java.time.OffsetDateTime;

/**
 * 报名里不依赖数据库的判断：人数、窗口和同一请求键怎么处理。
 */
public final class RegistrationRules {

    public static final String RETURN = "return";
    public static final String OCCUPY = "occupy";
    public static final String REPLACE = "replace";

    private RegistrationRules() {
    }

    public static MemberBounds bounds(String entryType, Integer min, Integer max) {
        if ("individual".equals(entryType)) {
            return new MemberBounds(1, 1);
        }
        if ("pair".equals(entryType)) {
            return new MemberBounds(2, 2);
        }
        if ("team".equals(entryType)) {
            if (min == null || max == null || min < 1 || max < min) {
                throw new ServiceException("请填写团体人数上下限");
            }
            return new MemberBounds(min, max);
        }
        throw new ServiceException("玩法无效");
    }

    /**
     * 开始时刻可以提交，结束时刻不能提交。
     */
    public static boolean windowOpen(OffsetDateTime opens, OffsetDateTime closes, OffsetDateTime now) {
        return opens != null && closes != null && now != null && !now.isBefore(opens) && now.isBefore(closes);
    }

    public static boolean beforeClose(OffsetDateTime closes, OffsetDateTime now) {
        return closes != null && now != null && now.isBefore(closes);
    }

    /**
     * 同一请求键只对应一次已经完成的提交。
     * 草稿加上创建键只有在该键尚未完成过提交时才是 OCCUPY。
     * 撤回后再次到达的旧键返回当前报名，不重新占用。
     * 主动重提传入新键，且当前保存的键已经完成过提交，才是 REPLACE。
     *
     * @param requestKeyConsumed 到达的这个请求键是否已经完成过一次提交
     * @param storedKeyConsumed 报名上当前保存的请求键是否已经完成过一次提交
     */
    public static String submitAction(String status, String storedKey, String requestKey,
                                       boolean requestKeyConsumed, boolean storedKeyConsumed) {
        if ("submitted".equals(status) || "approved".equals(status)) {
            if (requestKey.equals(storedKey)) {
                return RETURN;
            }
            throw new ServiceException("approved".equals(status) ? "已通过的报名不能再次提交" : "这条报名已经提交");
        }
        if ("rejected".equals(status) && requestKey.equals(storedKey)) {
            return RETURN;
        }
        if (requestKeyConsumed) {
            return RETURN;
        }
        if ("rejected".equals(status)) {
            return REPLACE;
        }
        if ("draft".equals(status)) {
            if (requestKey.equals(storedKey)) {
                return storedKeyConsumed ? RETURN : OCCUPY;
            }
            if (storedKeyConsumed) {
                return REPLACE;
            }
            throw new ServiceException("请使用创建报名时的请求键");
        }
        throw new ServiceException("当前报名不能提交");
    }

    public record MemberBounds(int min, int max) {
    }
}
