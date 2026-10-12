package org.dromara.sports.platform.core;

import java.time.OffsetDateTime;

/** Stable outcome reference; sensitive input and complete private responses are not persisted here. */
public record ActionReceipt(String id, String actionCode, String status, String objectType,
                            String objectId, String message, OffsetDateTime occurredAt) { }
