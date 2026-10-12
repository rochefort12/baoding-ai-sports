package org.dromara.sports.platform.core;

import java.lang.annotation.*;

/** A real business entry: scope is declared, and its success receipt commits with the business transaction. */
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface SportsAction {
    String value();
    String title();
    /** Registered capability governing a compatible UI entry; blank means a legacy-only entry. */
    String capability() default "";
    String[] reads() default {};
    String[] writes() default {};
    String permission() default "";
    boolean mutation() default true;
    boolean agent() default false;
    boolean confirmation() default false;
}
