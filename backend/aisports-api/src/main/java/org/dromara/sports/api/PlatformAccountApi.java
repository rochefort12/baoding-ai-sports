package org.dromara.sports.api;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

/**
 * 当前请求中的平台账号。只有平台登录才有值，不能从后台用户号反推。
 */
public interface PlatformAccountApi {

    Optional<Long> currentAccountId();

    /**
     * 用已验证手机号寻找可邀请的平台账号。找不到时为空。不返回证件和手机号。
     */
    Optional<InviteCandidate> findInviteCandidate(String phone);

    /**
     * 当前平台账号可用于报名快照的本人档案。未建档或必填未齐时为空。
     */
    Optional<RegistrationProfile> currentRegistrationProfile();

    /**
     * 队伍成员展示。只返回姓名、账号编号和能否被选入报名。不返回证件和手机号。
     * 调用方必须先确认这些档案属于调用者有权查看的队伍。
     */
    List<MemberLabel> memberLabels(Collection<Long> personIds);

    record InviteCandidate(Long accountId, String displayName, boolean profileReady, Long personId) {
    }

    /**
     * @param selectable 账号仍有效且档案已齐，可以选入报名
     */
    record MemberLabel(Long personId, Long accountId, String legalName, boolean selectable) {
    }

    record RegistrationProfile(Long accountId, Long personId, String legalName, String gender,
                               LocalDate birthDate, String mobile) {
    }
}
