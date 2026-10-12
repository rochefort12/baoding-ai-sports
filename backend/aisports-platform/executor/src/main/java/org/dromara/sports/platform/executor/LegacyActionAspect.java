package org.dromara.sports.platform.executor;
import lombok.RequiredArgsConstructor;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.*;
import org.dromara.sports.platform.core.SportsAction;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
/** Adapter only: transaction, declaration, identity and receipt handling remain in the shared executor. */
@Aspect @Component @Order(0) @RequiredArgsConstructor
public class LegacyActionAspect {
 private final BusinessExecutor executor;
 @Around("@annotation(action)") public Object execute(ProceedingJoinPoint point,SportsAction action)throws Throwable{return executor.legacy(action,point::proceed);}
}
