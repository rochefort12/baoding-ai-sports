package org.dromara.sports.organization.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * 本机关闭了 SnailJob，文件清理仍要按上海时间每天跑。
 */
@Configuration
@EnableScheduling
public class SportsFileScheduleConfiguration {
}
