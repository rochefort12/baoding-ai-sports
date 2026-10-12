package org.dromara.sports.api;

import java.util.Optional;

/**
 * 人员档案的授权读取边界。只能读取当前登录本人的档案，并且必填身份已经齐备。
 * 不允许将全量身份证、联系方式或 ORM 实体作为返回值。
 */
public interface PersonApi {
    /**
     * 读取有权用于指定业务用途的档案摘要；未授权或不存在返回 empty。
     */
    Optional<PersonSummary> findAuthorized(CallerContext caller, Long personId, String purpose);

    /**
     * 调用者能否以报名用途使用该参赛人。必须是当前登录本人，且真实姓名、出生日期、性别、手机号已齐。
     */
    boolean canRegister(CallerContext caller, Long personId);

    /**
     * @param personId 档案主键
     * @param displayName 按调用用途脱敏的显示名称
     * @param verified 是否已有身份核验事实，不能代替赛事资格审核
     */
    record PersonSummary(Long personId, String displayName, boolean verified) { }
}
