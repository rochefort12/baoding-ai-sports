package org.dromara.common.redis.lock;

import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.core.lock.LocalMutualLock;
import org.dromara.common.core.lock.MutualLock;
import org.redisson.api.RLock;
import org.redisson.api.RedissonClient;

import java.util.concurrent.TimeUnit;
import java.util.function.Supplier;

/**
 * Redis 互斥。客户端是 Redisson，不经过 Jedis、Lettuce 或 RedisTemplate。
 * 进程崩溃后由租约释放，避免锁一直留着。
 */
public class RedissonMutualLock implements MutualLock {

    private final RedissonClient client;

    public RedissonMutualLock(RedissonClient client) {
        this.client = client;
    }

    @Override
    public <T> T execute(String key, long waitMillis, long leaseMillis, Supplier<T> action) {
        String normalized = "aisports:lock:" + LocalMutualLock.requireKey(key);
        if (action == null) {
            throw new ServiceException("锁内动作不能为空");
        }
        if (leaseMillis <= 0) {
            throw new ServiceException("Redis 锁必须给出持有上限");
        }
        RLock lock = client.getLock(normalized);
        boolean acquired = false;
        try {
            acquired = lock.tryLock(Math.max(waitMillis, 0), leaseMillis, TimeUnit.MILLISECONDS);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new ServiceException("等待锁时被中断");
        }
        if (!acquired) {
            throw new ServiceException("锁正在被占用，请稍后再试");
        }
        try {
            return action.get();
        } finally {
            if (lock.isHeldByCurrentThread()) {
                lock.unlock();
            }
        }
    }
}
