package org.dromara.web.service;

import cn.hutool.crypto.digest.BCrypt;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.constant.SystemConstants;
import org.dromara.common.core.constant.TenantConstants;
import org.dromara.common.core.domain.model.LoginUser;
import org.dromara.common.core.domain.model.PasswordLoginBody;
import org.dromara.common.core.enums.LoginType;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.identity.ParticipantEntry;
import org.dromara.sports.identity.PlatformSession;
import org.dromara.system.domain.SysUser;
import org.dromara.system.domain.vo.SysUserVo;
import org.dromara.system.mapper.SysUserMapper;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicReference;

/**
 * 仅在认证内部读取同名候选；密码证明确定唯一主体后才建立租户上下文。
 * 浏览器提供的 tenantId 不参与选择，候选、密码摘要和组织目录均不返回客户端。
 */
@Service
@RequiredArgsConstructor
public class WorkAccountResolver {
    private final SysUserMapper userMapper;
    private final SysLoginService loginService;
    private final MappedPrincipalGuard mappedPrincipalGuard;

    public LoginUser authenticate(PasswordLoginBody body) {
        String username = body.getUsername().trim();
        AtomicReference<SysUserVo> selected = new AtomicReference<>();
        // 沿用 username 失败锁；先检查是否锁定，再进行候选查询和 BCrypt 验证。
        // 未知账号与密码错误走同一失败计数，不通过匿名查询暴露账号所属组织。
        loginService.checkLogin(LoginType.PASSWORD, TenantConstants.DEFAULT_TENANT_ID, username, () -> {
            List<SysUserVo> candidates = TenantHelper.ignore(() -> userMapper.selectVoList(
                new LambdaQueryWrapper<SysUser>().eq(SysUser::getUserName, username)));
            List<SysUserVo> matching = candidates.stream()
                .filter(user -> matchesPassword(body.getPassword(), user.getPassword())).toList();
            if (matching.size() > 1) {
                // 只有密码已真实命中多个主体时才反馈歧义；不能任意选首条租户。
                throw new ServiceException("该工作账号对应多个组织，请联系管理员确认账号");
            }
            if (matching.isEmpty()) {
                return true;
            }
            selected.set(matching.get(0));
            return false;
        });
        SysUserVo authenticated = selected.get();
        if (authenticated == null) {
            throw new ServiceException("工作账号或密码错误");
        }
        String tenantId = authenticated.getTenantId();
        if (tenantId == null || tenantId.isBlank()) {
            throw new ServiceException("工作账号暂不可用，请联系管理员");
        }
        if (ParticipantEntry.TENANT_ID.equals(tenantId) || PlatformSession.TENANT_ID.equals(tenantId)) {
            throw new ServiceException("请使用手机号登录后进入个人或组织空间");
        }
        loginService.checkTenant(tenantId);
        return TenantHelper.dynamic(tenantId, () -> {
            // 重新按服务器确定的租户读取：候选查询期间停用、改密或主体变化不得放行。
            SysUserVo current = userMapper.selectVoById(authenticated.getUserId());
            if (current == null || !Objects.equals(tenantId, current.getTenantId())
                || !Objects.equals(username, current.getUserName())
                || !matchesPassword(body.getPassword(), current.getPassword())) {
                throw new ServiceException("工作账号或密码错误");
            }
            if (!SystemConstants.NORMAL.equals(current.getStatus())) {
                throw new ServiceException("工作账号已停用，请联系管理员");
            }
            if (!UserType.SYS_USER.getUserType().equals(current.getUserType())) {
                throw new ServiceException("请使用手机号登录后进入个人或组织空间");
            }
            // 即使掌握技术主体密码，也不能绕过平台账号及 asp_staff_grant 的兑换链。
            mappedPrincipalGuard.rejectDirectLogin(current.getUserId());
            return loginService.buildLoginUser(current);
        });
    }

    private static boolean matchesPassword(String password, String hash) {
        if (password == null || hash == null || hash.isBlank()) {
            return false;
        }
        try {
            return BCrypt.checkpw(password, hash);
        } catch (IllegalArgumentException invalidStoredHash) {
            // 损坏或遗留非 BCrypt 摘要不是登录证明，也不把底层异常泄露到登录页面。
            return false;
        }
    }
}
