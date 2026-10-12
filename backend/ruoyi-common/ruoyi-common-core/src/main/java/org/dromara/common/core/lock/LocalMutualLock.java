package org.dromara.common.core.lock;

import org.dromara.common.core.exception.ServiceException;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.ReentrantLock;
import java.util.function.Supplier;

/**
 * 单机互斥。只在当前进程内生效，多实例部署时不能靠它保护名额。
 */
public class LocalMutualLock implements MutualLock {

    private final ConcurrentHashMap<String, ReentrantLock> locks = new ConcurrentHashMap<>();

    @Override
    public <T> T execute(String key, long waitMillis, long leaseMillis, Supplier<T> action) {
        String normalized = requireKey(key);
        if (action == null) {
            throw new ServiceException("锁内动作不能为空");
        }
        ReentrantLock lock = locks.computeIfAbsent(normalized, ignored -> new ReentrantLock());
        boolean acquired = false;
        try {
            acquired = lock.tryLock(Math.max(waitMillis, 0), TimeUnit.MILLISECONDS);
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
            lock.unlock();
        }
    }

    public static String requireKey(String key) {
        if (key == null || key.isBlank()) {
            throw new ServiceException("锁键不能为空");
        }
        return key.trim();
    }
}
