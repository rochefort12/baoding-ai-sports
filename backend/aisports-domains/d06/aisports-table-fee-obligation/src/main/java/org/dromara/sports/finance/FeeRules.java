package org.dromara.sports.finance;

import org.dromara.common.core.exception.ServiceException;

import java.math.BigDecimal;

/**
 * 收费里不依赖数据库的判断。金额、作废和冲正都从这里走。
 */
public final class FeeRules {

    private FeeRules() {
    }

    public static String obligationStatus(String paymentMode, BigDecimal amount) {
        if (amount == null || amount.signum() < 0) {
            throw new ServiceException("金额不能为负");
        }
        if ("free".equals(paymentMode)) {
            if (amount.signum() != 0) {
                throw new ServiceException("免费项目的金额必须为 0");
            }
            return "not_required";
        }
        if (amount.signum() == 0) {
            throw new ServiceException("收费项目的金额必须大于 0");
        }
        return "open";
    }

    public static String afterEntryClosed(String obligationStatus) {
        if ("open".equals(obligationStatus) || "not_required".equals(obligationStatus)) {
            return "void";
        }
        return obligationStatus;
    }

    public static boolean opensActionCase(String obligationStatus) {
        return "settled".equals(obligationStatus);
    }

    public static String afterReversal(boolean entryStillBillable, String obligationStatus) {
        if ("void".equals(obligationStatus)) {
            return "void";
        }
        return entryStillBillable ? "open" : "void";
    }

    public static boolean sameMoney(BigDecimal left, BigDecimal right) {
        return left != null && right != null && left.compareTo(right) == 0;
    }
}
