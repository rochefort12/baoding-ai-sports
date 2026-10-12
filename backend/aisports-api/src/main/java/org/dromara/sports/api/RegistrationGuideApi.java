package org.dromara.sports.api;

/**
 * 参赛引导读取本人报名。账号由已登录请求绑定，模型不能指定别人。
 */
public interface RegistrationGuideApi {

    /**
     * 未登录时说明需要登录。已登录时只返回该账号自己的报名状态，不含证件、手机号和他人姓名。
     */
    String myStatus(Long accountId, int offset);
}
