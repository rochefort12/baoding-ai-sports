package org.dromara.web.service;

import cn.dev33.satoken.stp.StpUtil;
import cn.dev33.satoken.stp.parameter.SaLoginParameter;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.constant.SystemConstants;
import org.dromara.common.core.domain.model.LoginUser;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.mybatis.helper.DataPermissionHelper;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.api.OrganizationSessionApi.OrganizationEntry;
import org.dromara.system.domain.vo.SysClientVo;
import org.dromara.system.domain.vo.SysTenantVo;
import org.dromara.system.domain.vo.SysUserVo;
import org.dromara.system.mapper.SysUserMapper;
import org.dromara.system.service.ISysClientService;
import org.dromara.system.service.ISysTenantService;
import org.dromara.web.domain.vo.LoginVo;
import org.springframework.stereotype.Service;

/**
 * 用平台账号兑换组织管理会话。授权以成员表为准，不读平台 Token 里缓存的角色。
 */
@Service
@RequiredArgsConstructor
public class OrganizationEnterService {

    private final OrganizationSessionApi sessionApi;
    private final ISysTenantService tenantService;
    private final ISysClientService clientService;
    private final SysUserMapper userMapper;
    private final SysLoginService loginService;

    public LoginVo enter(String clientId) {
        if (!LoginHelper.isLogin() || LoginHelper.getUserType() != UserType.PLATFORM_USER) {
            throw new ServiceException("请先使用平台账号登录");
        }
        SysClientVo client = clientService.queryByClientId(clientId);
        if (client == null || (client.getStatus() != null && !SystemConstants.NORMAL.equals(client.getStatus()))) {
            throw new ServiceException("客户端无效");
        }
        OrganizationEntry entry = sessionApi.entryFor(LoginHelper.getUserId())
            .orElseThrow(() -> new ServiceException("当前账号还不能进入组织"));
        SysTenantVo tenant = tenantService.queryByTenantId(entry.tenantId());
        if (tenant == null || !SystemConstants.NORMAL.equals(tenant.getStatus()) || !tenantService.checkExpireTime(entry.tenantId())) {
            throw new ServiceException("组织租户不可用");
        }
        LoginUser loginUser = DataPermissionHelper.ignore(() -> TenantHelper.dynamic(entry.tenantId(), () -> {
            SysUserVo user = userMapper.selectVoById(entry.sysUserId());
            if (user == null || SystemConstants.DISABLE.equals(user.getStatus())) {
                throw new ServiceException("组织管理账号不可用");
            }
            return loginService.buildLoginUser(user);
        }));
        loginUser.setClientKey(client.getClientKey());
        loginUser.setDeviceType(client.getDeviceType());
        SaLoginParameter model = new SaLoginParameter();
        model.setDeviceType(client.getDeviceType());
        model.setTimeout(client.getTimeout());
        model.setActiveTimeout(client.getActiveTimeout());
        model.setExtra(LoginHelper.CLIENT_KEY, client.getClientId());
        LoginHelper.login(loginUser, model);
        LoginVo loginVo = new LoginVo();
        loginVo.setAccessToken(StpUtil.getTokenValue());
        loginVo.setExpireIn(StpUtil.getTokenTimeout());
        loginVo.setClientId(client.getClientId());
        return loginVo;
    }
}
