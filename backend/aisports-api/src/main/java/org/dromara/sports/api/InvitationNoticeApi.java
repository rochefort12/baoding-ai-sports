package org.dromara.sports.api;
/** 邀请/名单动作已验证对象和收件授权后调用；不承载实体，不将链接当作授权。 */
public interface InvitationNoticeApi {
    /** kind+对象ID+修订+收件账号去重；目标路径按kind白名单，名单移除跳本人列表。 */
    void created(String kind, Long invitationId, int revision, Long recipientAccountId, String title, String body, String targetPath, boolean requestSms);
    /** 仅在调用模块已验证当前邀请访问权后查询渠道结果。 */
    Status delivery(String kind, Long invitationId, Long recipientAccountId);
    record Status(String inboxStatus, String smsStatus, String smsReason) { }
}
