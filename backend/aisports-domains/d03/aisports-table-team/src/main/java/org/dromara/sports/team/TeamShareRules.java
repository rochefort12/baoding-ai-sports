package org.dromara.sports.team;

import org.dromara.common.core.exception.ServiceException;
import java.time.OffsetDateTime;
import java.security.SecureRandom;
import java.util.HexFormat;

/** 分享凭据仅授予入队邀请，不授予队内资料访问或任何参赛确认。 */
public final class TeamShareRules {
    private static final SecureRandom RANDOM = new SecureRandom();
    private TeamShareRules() { }

    public static String newToken() {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        return HexFormat.of().formatHex(bytes);
    }

    public static String token(String value) {
        if (value == null || !value.matches("[a-f0-9]{64}")) throw new ServiceException("邀请链接无效，请向队长获取新的链接");
        return value;
    }

    public static String status(String storedStatus, boolean teamActive, boolean inviterStillCaptain,
                                OffsetDateTime expiresAt, OffsetDateTime now) {
        if (!"pending".equals(storedStatus)) return storedStatus;
        if (!teamActive || !inviterStillCaptain) return "invalidated";
        if (expiresAt == null || !expiresAt.isAfter(now)) return "expired";
        return "pending";
    }

    public static void requireAccept(String status, boolean previouslyUsed, boolean currentMember, boolean confirmed) {
        if (!confirmed) throw new ServiceException("请本人确认是否加入队伍");
        if (!"pending".equals(status)) throw new ServiceException("邀请链接已失效，请向队长获取新的链接");
        if (previouslyUsed && !currentMember) throw new ServiceException("你曾使用此链接入队；离队后请联系队长重新邀请");
    }
}
