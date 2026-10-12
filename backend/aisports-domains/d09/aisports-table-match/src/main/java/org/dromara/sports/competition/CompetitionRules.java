package org.dromara.sports.competition;

import org.dromara.common.core.exception.ServiceException;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

/**
 * 录分里不依赖数据库的判断。正式结果本期不能改。
 */
public final class CompetitionRules {

    private CompetitionRules() {
    }

    /** 通用胜负关系；不把羽毛球专项计分规则用于其他赛事。 */
    public static void requireComplementary(String a, String b) {
        if (!("win".equals(a) && "loss".equals(b) || "loss".equals(a) && "win".equals(b) || "draw".equals(a) && "draw".equals(b))) {
            throw new ServiceException("双方结果须为一胜一负，或同时平局");
        }
    }

    public static boolean isFinal(String status) {
        return "confirmed".equals(status);
    }

    public static void rejectChangedFinal(String status, String stored, String incoming) {
        if (!isFinal(status)) {
            return;
        }
        if (stored != null && stored.equals(incoming)) {
            return;
        }
        throw new ServiceException("正式结果不能修改");
    }

    public static String sha256(String payload) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(payload.getBytes(StandardCharsets.UTF_8));
            StringBuilder builder = new StringBuilder(digest.length * 2);
            for (byte value : digest) {
                builder.append(String.format("%02x", value));
            }
            return builder.toString();
        } catch (NoSuchAlgorithmException exception) {
            throw new ServiceException("请求摘要无法计算");
        }
    }
}
