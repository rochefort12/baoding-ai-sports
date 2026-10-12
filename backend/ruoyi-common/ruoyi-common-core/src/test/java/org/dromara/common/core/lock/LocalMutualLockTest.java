package org.dromara.common.core.lock;

import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

@Tag("local")
class LocalMutualLockTest {

    @Test
    void concurrentIncrementsDoNotLoseUpdates() throws Exception {
        MutualLock lock = new LocalMutualLock();
        int[] count = {0};
        int threads = 8;
        int rounds = 40;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CountDownLatch start = new CountDownLatch(1);
        List<Future<?>> futures = new ArrayList<>();
        for (int i = 0; i < threads; i++) {
            futures.add(pool.submit(() -> {
                start.await();
                for (int round = 0; round < rounds; round++) {
                    lock.execute("capacity:unit:1", 5000, 0, () -> {
                        count[0]++;
                        return null;
                    });
                }
                return null;
            }));
        }
        start.countDown();
        for (Future<?> future : futures) {
            future.get();
        }
        pool.shutdown();
        assertEquals(threads * rounds, count[0]);
    }

    @Test
    void blankKeyIsRejected() {
        MutualLock lock = new LocalMutualLock();
        assertThrows(Exception.class, () -> lock.execute(" ", 10, 0, () -> null));
    }
}
