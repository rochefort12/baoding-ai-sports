package org.dromara.web.domain.vo;

/** 匿名登录方式目录只给可用性；不输出 OAuth 凭据、租户目录或绑定账号。 */
public record WorkLoginMethodsVo(Wechat wechat) {
    public record Wechat(boolean available) {
    }

    public static WorkLoginMethodsVo current() {
        // 工作微信尚未通过真实 OAuth/唯一主体解析验收，配置存在也不能表示通道已开放。
        // 保留原第三方绑定流程；以后由独立验证过的工作微信能力取代此关闭状态。
        return new WorkLoginMethodsVo(new Wechat(false));
    }
}
