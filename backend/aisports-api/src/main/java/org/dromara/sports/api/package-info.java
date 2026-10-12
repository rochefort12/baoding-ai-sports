/**
 * 体育领域的跨模块契约。
 *
 * <p>这里只放 API、DTO 和枚举，禁止 Entity、Mapper、Spring、MyBatis 或 Web 依赖。
 * 单体内使用 Java 实现；拆分服务时增加远程适配器，领域调用方仍依赖这些契约。
 * 实现放在各业务模块，本包不提供默认实现。</p>
 */
package org.dromara.sports.api;
