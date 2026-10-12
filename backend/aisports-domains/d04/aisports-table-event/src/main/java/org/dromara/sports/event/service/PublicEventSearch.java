package org.dromara.sports.event.service;

import org.dromara.sports.event.service.EventPublicationService.EventCard;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;

/**
 * 公开赛事检索。模型只提交条件，排序、分页和每页数量在这里完成。
 */
public final class PublicEventSearch {

    public static final int PAGE_SIZE = 8;

    private PublicEventSearch() {
    }

    public static Page search(List<EventCard> published, Query query) {
        Query safe = query == null ? new Query("", "", "", false, 0) : query;
        String text = clip(safe.text());
        String project = clip(safe.project());
        String phase = knownPhase(safe.phase());
        int offset = Math.max(0, Math.min(safe.offset(), 10000));
        List<EventCard> matched = new ArrayList<>();
        for (EventCard event : published) {
            if (event == null) {
                continue;
            }
            if (!safe.includeCancelled() && "cancelled".equals(event.holdingStatus())) {
                continue;
            }
            if (!phase.isEmpty() && !phase.equals(event.phase())) {
                continue;
            }
            if (!project.isEmpty() && !contains(event.projectName(), project)) {
                continue;
            }
            if (!text.isEmpty() && score(event, text) == 0) {
                continue;
            }
            matched.add(event);
        }
        matched.sort(Comparator
            .comparingInt((EventCard event) -> text.isEmpty() ? 0 : -score(event, text))
            .thenComparingInt(PublicEventSearch::phaseRank)
            .thenComparing(EventCard::startsAt, Comparator.nullsLast(Comparator.naturalOrder()))
            .thenComparing(EventCard::id, Comparator.nullsLast(Comparator.naturalOrder())));
        int from = Math.min(offset, matched.size());
        int to = Math.min(from + PAGE_SIZE, matched.size());
        return new Page(List.copyOf(matched.subList(from, to)), matched.size(), from, PAGE_SIZE, to < matched.size());
    }

    private static int score(EventCard event, String text) {
        int score = 0;
        if (contains(event.name(), text)) {
            score += 4;
        }
        if (contains(event.projectName(), text)) {
            score += 3;
        }
        if (contains(event.location(), text)) {
            score += 2;
        }
        if (contains(event.feeDescription(), text)) {
            score += 1;
        }
        return score;
    }

    private static int phaseRank(EventCard event) {
        if ("cancelled".equals(event.holdingStatus())) {
            return 9;
        }
        return switch (event.phase() == null ? "" : event.phase()) {
            case "registration" -> 0;
            case "pre_registration" -> 1;
            case "ongoing" -> 2;
            case "registration_closed" -> 3;
            case "finished" -> 4;
            default -> 5;
        };
    }

    private static boolean contains(String value, String needle) {
        return value != null && value.toLowerCase(Locale.ROOT).contains(needle.toLowerCase(Locale.ROOT));
    }

    private static String clip(String value) {
        if (value == null) {
            return "";
        }
        String text = value.trim();
        return text.length() <= 80 ? text : text.substring(0, 80);
    }

    private static String knownPhase(String phase) {
        if (phase == null) {
            return "";
        }
        return switch (phase.trim()) {
            case "registration", "pre_registration", "ongoing", "registration_closed", "finished" -> phase.trim();
            default -> "";
        };
    }

    public record Query(String text, String project, String phase, boolean includeCancelled, int offset) {
    }

    public record Page(List<EventCard> events, int total, int offset, int limit, boolean hasMore) {
    }
}
