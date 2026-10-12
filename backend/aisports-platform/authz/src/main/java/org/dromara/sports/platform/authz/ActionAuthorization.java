package org.dromara.sports.platform.authz;

import cn.dev33.satoken.stp.StpUtil;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.platform.core.*;
import org.springframework.stereotype.Component;

/** Capabilities supplement, not replace, each provider's current object/tenant authorization. */
@Component
@RequiredArgsConstructor
public class ActionAuthorization {
    private final OrganizationSessionApi organizations;
    public record Actor(String type,Long id,String tenantId,Long organizationId) { }
    public Actor actor() {
        var run=TrustedRunContext.current();
        if(run!=null) return new Actor(run.actorType(),run.actorId(),run.tenantId(),run.organizationId());
        if(!LoginHelper.isLogin()) throw new ServiceException("请先登录后继续办理",401);
        if(LoginHelper.getUserType()==UserType.PLATFORM_USER) return new Actor("platform",LoginHelper.getUserId(),null,null);
        if(LoginHelper.isSuperAdmin()) return new Actor("admin",LoginHelper.getUserId(),LoginHelper.getTenantId(),null);
        var org=organizations.managedOrganization(LoginHelper.getUserId());
        if(org.isPresent()) return new Actor("organizer",LoginHelper.getUserId(),org.get().tenantId(),org.get().organizationId());
        return new Actor("government",LoginHelper.getUserId(),LoginHelper.getTenantId(),null);
    }
    public boolean allowed(CapabilityDefinition definition) {
        try { check(definition); return true; } catch(ServiceException ex) { return false; }
    }
    /** Showing a permitted manual entrance never changes the run's narrower Agent grant. */
    public boolean guidanceAllowed(CapabilityDefinition definition) {
        var actor=actor();if(!definition.actorTypes().contains(actor.type()))return false;
        var run=TrustedRunContext.current();
        if(run==null)return allowed(definition);
        if(definition.permission().isBlank()||"admin".equals(actor.type()))return true;
        try{var permissions=new com.fasterxml.jackson.databind.ObjectMapper().readTree(run.scopeJson()).path("runtimePermissions");for(var permission:permissions)if(permission.asText().equals(definition.permission())||permission.asText().equals("*:*:*"))return true;}catch(Exception invalid){return false;}
        return false;
    }
    public void check(CapabilityDefinition definition) {
        var actor=actor();
        if(!definition.actorTypes().contains(actor.type())) throw new ServiceException("当前身份不能办理此事项",403);
        var run=TrustedRunContext.current();
        if(run!=null) {
            if(!definition.agent() || !run.capabilities().contains(definition.code())) throw new ServiceException("智能体没有该项办理权限",403);
        } else if(!definition.permission().isBlank() && !"admin".equals(actor.type()) && !StpUtil.hasPermission(definition.permission())) {
            throw new ServiceException("当前岗位未获授权",403);
        }
    }
}
