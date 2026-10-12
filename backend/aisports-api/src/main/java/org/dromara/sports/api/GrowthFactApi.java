package org.dromara.sports.api;

/** Reconcile observable participation facts in the caller's database transaction. No points supplied by callers. */
public interface GrowthFactApi {
    void reconcileEvent(Long eventId);
}
