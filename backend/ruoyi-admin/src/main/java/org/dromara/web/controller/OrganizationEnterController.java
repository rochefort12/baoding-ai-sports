package org.dromara.web.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.domain.R;
import org.dromara.common.core.utils.StringUtils;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.web.domain.vo.LoginVo;
import org.dromara.web.service.OrganizationEnterService;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 平台会话兑换管理会话。不放在带 SaIgnore 的登录控制器上。
 */
@SaCheckLogin
@RestController
@RequiredArgsConstructor
@RequestMapping("/auth/organization")
public class OrganizationEnterController {

    private final OrganizationEnterService enterService;

    @PostMapping("/enter")
    public R<LoginVo> enter(HttpServletRequest request) {
        String clientId = request.getHeader(LoginHelper.CLIENT_KEY);
        if (StringUtils.isBlank(clientId)) {
            clientId = request.getParameter(LoginHelper.CLIENT_KEY);
        }
        return R.ok(enterService.enter(clientId));
    }
}
