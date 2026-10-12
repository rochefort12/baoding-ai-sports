package org.dromara.sports.event.ai;

import org.dromara.common.core.exception.ServiceException;

import java.util.LinkedHashSet;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 宣传文案里的数字必须能在赛事事实里找到。版面上的时间、地点和金额仍由程序填写。
 */
public final class PromotionCopyGuard {

    private static final Pattern TOKEN = Pattern.compile("\\d+\\.\\d+|\\d{2,}");

    private PromotionCopyGuard() {
    }

    public static Copy accept(String headline, String invitation, String groupBody, String momentsCaption, String factText, boolean cancelled) {
        Copy copy = new Copy(
            bound(headline, 40, "标题"),
            bound(invitation, 160, "邀请"),
            bound(groupBody, 800, "群消息"),
            bound(momentsCaption, 160, "朋友圈短句"));
        String joined = copy.headline() + "\n" + copy.invitation() + "\n" + copy.groupBody() + "\n" + copy.momentsCaption();
        if (joined.contains("官方认证") || joined.contains("政府认证") || joined.contains("<") || joined.contains("http")) {
            throw new ServiceException("文案不能写官方认证、链接或页面代码，没有保存");
        }
        if (joined.contains("名额")) {
            throw new ServiceException("文案不要自填名额，没有保存");
        }
        Set<String> allowed = tokens(factText);
        for (String token : tokens(joined)) {
            if (!allowed.contains(token)) {
                throw new ServiceException("AI文案中的数字“" + token + "”无法在当前赛事资料中核对，未保存这版AI文案。请检查赛事资料或重新生成；基础文案仍可使用。");
            }
        }
        if (cancelled && !copy.groupBody().contains("取消")) {
            copy = new Copy(copy.headline(), copy.invitation(), copy.groupBody() + "这场已经取消，不再招募新的报名。", copy.momentsCaption());
        }
        return copy;
    }

    private static String bound(String value, int max, String label) {
        String text = value == null ? "" : value.trim();
        if (text.isEmpty()) {
            throw new ServiceException(label + "还没写好，没有保存");
        }
        if (text.length() > max) {
            throw new ServiceException(label + "太长，没有保存");
        }
        return text;
    }

    static Set<String> tokens(String text) {
        Set<String> found = new LinkedHashSet<>();
        Matcher matcher = TOKEN.matcher(text == null ? "" : text);
        while (matcher.find()) {
            String raw = matcher.group();
            // 金额的 198、198.00 是同一个数；保留手机号等前导零，避免把不同号码视为相同事实。
            found.add(raw.length() > 1 && raw.startsWith("0") && !raw.startsWith("0.")
                ? raw : new java.math.BigDecimal(raw).stripTrailingZeros().toPlainString());
        }
        return found;
    }

    public record Copy(String headline, String invitation, String groupBody, String momentsCaption) {
    }
}
