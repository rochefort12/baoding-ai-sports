package org.dromara.sports.organization;

/**
 * 办赛申请这一段的固定取值。套餐编号必须和 V007 插入的套餐相同。
 */
public final class OrganizationSlice {

    public static final long PACKAGE_ID = 2106100000000000012L;
    public static final String ACTION_ORGANIZE = "organize";
    public static final String ACTION_PAYMENT = "payment";
    public static final String FILE_PURPOSE = "organization-application";

    private OrganizationSlice() {
    }
}
