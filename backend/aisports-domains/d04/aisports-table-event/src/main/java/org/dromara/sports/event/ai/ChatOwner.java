package org.dromara.sports.event.ai;

public interface ChatOwner {

    Owner current();

    record Owner(long organizationId, long accountId) {
    }
}
