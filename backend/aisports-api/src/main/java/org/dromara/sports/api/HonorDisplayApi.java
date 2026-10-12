package org.dromara.sports.api;

import java.util.List;

/** Derived approved facts only. Never exposes applications, evidence files or reviewer notes. */
public interface HonorDisplayApi {
    /** Anonymous display requires the honor and sport profile public switches. */
    List<CertifiedHonor> publicHonors(long accountId, Long sportId);

    /** Authenticated participants may see only their own approved badges. */
    List<CertifiedHonor> myHonors(Long sportId);

    record CertifiedHonor(String honorId, String title, int eventYear, String eventName,
                          String sportId, String sportName, int place, boolean worn,
                          boolean publicVisible) { }
}
