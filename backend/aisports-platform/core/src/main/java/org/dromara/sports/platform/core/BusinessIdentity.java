package org.dromara.sports.platform.core;
import org.dromara.common.core.enums.UserType;
import org.dromara.common.satoken.utils.LoginHelper;
/** Verified run context supplements interactive sessions; no client-supplied actor enters this class. */
public final class BusinessIdentity {
    private BusinessIdentity(){}
    public static boolean isLogin(){return TrustedRunContext.current()!=null||LoginHelper.isLogin();}
    public static Long getUserId(){var r=TrustedRunContext.current();return r==null?LoginHelper.getUserId():r.actorId();}
    public static String getUserIdStr(){return String.valueOf(getUserId());}
    public static String getTenantId(){var r=TrustedRunContext.current();return r==null?LoginHelper.getTenantId():r.tenantId();}
    public static UserType getUserType(){var r=TrustedRunContext.current();return r==null?LoginHelper.getUserType():"platform".equals(r.actorType())?UserType.PLATFORM_USER:UserType.SYS_USER;}
    public static boolean isSuperAdmin(){return TrustedRunContext.current()==null&&LoginHelper.isSuperAdmin();}
}
