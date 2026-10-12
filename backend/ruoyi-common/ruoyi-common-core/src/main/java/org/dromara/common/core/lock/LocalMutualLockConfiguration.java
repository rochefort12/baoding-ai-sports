package org.dromara.common.core.lock;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * 默认单机锁。只有显式改成 redis 时才不注册这个实现。
 */
@Configuration
public class LocalMutualLockConfiguration {

    @Bean
    @ConditionalOnProperty(prefix = "aisports.lock", name = "mode", havingValue = "local", matchIfMissing = true)
    public MutualLock localMutualLock() {
        return new LocalMutualLock();
    }
}
