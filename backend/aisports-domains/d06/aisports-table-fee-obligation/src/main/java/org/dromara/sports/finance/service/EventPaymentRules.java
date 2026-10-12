package org.dromara.sports.finance.service;

import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.api.FeeApi.PaymentChannel;
import java.util.*;

/** 只校验一期静态收款指引，实际到账继续由人工核对；不接支付网关。 */
public final class EventPaymentRules {
    private EventPaymentRules() { }
    public static List<PaymentChannel> normalize(List<PaymentChannel> input) {
        if (input == null || input.size() > 5) throw new ServiceException("收款渠道最多5种，请选择后填写");
        Set<String> seen = new HashSet<>();
        List<PaymentChannel> result = new ArrayList<>();
        for (PaymentChannel channel : input) {
            if (channel == null || channel.type() == null || !Set.of("wechat", "alipay", "bank", "custom_qr", "offline").contains(channel.type()) || !seen.add(channel.type())) throw new ServiceException("收款渠道无效或重复");
            String type = channel.type();
            boolean qr = Set.of("wechat", "alipay", "custom_qr").contains(type);
            if (qr && channel.qrFileId() == null) throw new ServiceException("请上传" + label(type) + "二维码");
            String name = text(channel.accountName(), 100), bank = text(channel.bankName(), 200), account = text(channel.bankAccount(), 100);
            String instruction = text(channel.instruction(), 500);
            if ("bank".equals(type) && (name.isEmpty() || bank.isEmpty() || account.isEmpty())) throw new ServiceException("请填写银行开户名、开户行和账号");
            if ("offline".equals(type) && instruction.isEmpty()) throw new ServiceException("请填写线下付款的地点或联系办理方式");
            String title = "custom_qr".equals(type) ? text(channel.label(), 40) : label(type);
            if (title.isEmpty()) throw new ServiceException("请填写自定义收款码名称");
            result.add(new PaymentChannel(type, title, qr ? channel.qrFileId() : null, "bank".equals(type) ? name : null,
                "bank".equals(type) ? bank : null, "bank".equals(type) ? account : null, instruction));
        }
        return List.copyOf(result);
    }
    private static String text(String value, int max) {
        String text = value == null ? "" : value.trim();
        if (text.length() > max) throw new ServiceException("收款信息超过允许长度，请精简后保存");
        return text;
    }
    private static String label(String type) {
        return switch (type) { case "wechat" -> "微信"; case "alipay" -> "支付宝"; case "bank" -> "银行转账"; case "offline" -> "线下付款"; default -> "自定义收款码"; };
    }
}
