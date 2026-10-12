package org.dromara.sports.event;

import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.Set;

/**
 * 按北京时间计算赛事阶段。边界落在后一个阶段。时间不齐时返回空，不猜一个阶段。
 */
public final class EventPhaseCalculator {

    public static final ZoneId ZONE = ZoneId.of("Asia/Shanghai");
    public static final String PRE_REGISTRATION = "pre_registration";
    public static final String REGISTRATION = "registration";
    public static final String REGISTRATION_CLOSED = "registration_closed";
    public static final String ONGOING = "ongoing";
    public static final String FINISHED = "finished";
    public static final Set<String> PUBLISHABLE = Set.of(PRE_REGISTRATION, REGISTRATION, REGISTRATION_CLOSED);

    private EventPhaseCalculator() {
    }

    public static String phase(OffsetDateTime registrationStart, OffsetDateTime registrationEnd,
                               OffsetDateTime eventStart, OffsetDateTime eventEnd, OffsetDateTime now) {
        if (registrationStart == null || registrationEnd == null || eventStart == null || eventEnd == null || now == null) {
            return null;
        }
        if (now.isBefore(registrationStart)) {
            return PRE_REGISTRATION;
        }
        if (now.isBefore(registrationEnd)) {
            return REGISTRATION;
        }
        if (now.isBefore(eventStart)) {
            return REGISTRATION_CLOSED;
        }
        if (now.isBefore(eventEnd)) {
            return ONGOING;
        }
        return FINISHED;
    }

    public static boolean ordered(OffsetDateTime registrationStart, OffsetDateTime registrationEnd,
                                  OffsetDateTime eventStart, OffsetDateTime eventEnd) {
        return registrationStart != null && registrationEnd != null && eventStart != null && eventEnd != null
            && registrationStart.isBefore(registrationEnd)
            && !registrationEnd.isAfter(eventStart)
            && eventStart.isBefore(eventEnd);
    }
}
