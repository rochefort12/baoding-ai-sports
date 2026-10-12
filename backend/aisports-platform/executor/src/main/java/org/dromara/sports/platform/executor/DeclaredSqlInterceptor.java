package org.dromara.sports.platform.executor;

import org.apache.ibatis.executor.Executor;
import org.apache.ibatis.mapping.MappedStatement;
import org.apache.ibatis.plugin.*;
import org.dromara.sports.platform.core.SqlScope;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** Existing MyBatis projections use the same declaration guard as new parameterized JDBC actions. */
@Component
@Intercepts(@Signature(type=Executor.class,method="update",args={MappedStatement.class,Object.class}))
public class DeclaredSqlInterceptor implements Interceptor {
    @Value("${sports.platform.require-action-context:false}") private boolean requireContext;
    public Object intercept(Invocation invocation) throws Throwable {
        var statement=(MappedStatement)invocation.getArgs()[0];
        SqlScope.check(statement.getBoundSql(invocation.getArgs()[1]).getSql(),true,requireContext);
        return invocation.proceed();
    }
}
