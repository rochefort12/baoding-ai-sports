package org.dromara.common.core.lock;

import java.util.function.Supplier;

/**
 * 同一业务键上的互斥。调用方只依赖这个接口，不关心当前是单机还是 Redis。
 */
public interface MutualLock {

    /**
     * 持有锁执行动作。等待超时或被中断时失败，不执行动作。
     *
     * @param key 业务键，例如某个竞赛单元的名额
     * @param waitMillis 最多等待多久
     * @param leaseMillis 锁的持有上限。单机实现把锁留到方法结束，不使用这个值
     */
    <T> T execute(String key, long waitMillis, long leaseMillis, Supplier<T> action);
}
