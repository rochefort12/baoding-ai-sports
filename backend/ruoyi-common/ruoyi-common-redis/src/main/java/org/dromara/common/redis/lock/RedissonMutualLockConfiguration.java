package org.dromara.common.redis.lock;

import org.dromara.common.core.lock.MutualLock;
import org.redisson.api.RedissonClient;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * 只有 aisports.lock.mode=redis 时替换单机锁。
 */
@Configuration
public class RedissonMutualLockConfiguration {

    @Bean
    @ConditionalOnProperty(prefix = "aisports.lock", name = "mode", havingValue = "redis")
    public MutualLock redissonMutualLock(RedissonClient client) {
        return new RedissonMutualLock(client);
    }
}
