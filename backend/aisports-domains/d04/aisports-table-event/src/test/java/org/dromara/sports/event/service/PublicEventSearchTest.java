package org.dromara.sports.event.service;

import org.dromara.sports.event.service.EventPublicationService.EventCard;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

@Tag("local")
class PublicEventSearchTest {

    @Test
    void pagesEightAndContinuesWithoutDroppingTheRest() {
        List<EventCard> events = new ArrayList<>();
        events.add(card(1, "已结束赛", "羽毛球", "finished", "normal"));
        for (int id = 2; id <= 10; id++) {
            events.add(card(id, "报名赛" + id, "羽毛球", "registration", "normal"));
        }
        PublicEventSearch.Page first = PublicEventSearch.search(events, new PublicEventSearch.Query("", "", "", false, 0));
        assertEquals(8, first.events().size());
        assertEquals(10, first.total());
        assertTrue(first.hasMore());
        assertEquals("registration", first.events().get(0).phase());
        PublicEventSearch.Page second = PublicEventSearch.search(events, new PublicEventSearch.Query("", "", "", false, 8));
        assertEquals(2, second.events().size());
        assertFalse(second.hasMore());
    }

    @Test
    void textRanksNameAndCanExcludeCancelled() {
        EventCard named = card(1, "篮球公开赛", "篮球", "finished", "normal");
        EventCard other = card(2, "城市赛", "篮球", "registration", "normal");
        EventCard cancelled = card(3, "篮球取消赛", "篮球", "registration", "cancelled");
        PublicEventSearch.Page page = PublicEventSearch.search(List.of(other, cancelled, named), new PublicEventSearch.Query("篮球公开", "", "", false, 0));
        assertEquals(1, page.total());
        assertEquals(1L, page.events().get(0).id());
        PublicEventSearch.Page withCancelled = PublicEventSearch.search(List.of(cancelled), new PublicEventSearch.Query("", "", "", true, 0));
        assertEquals(1, withCancelled.total());
    }

    private static EventCard card(long id, String name, String project, String phase, String holding) {
        EventCard event = mock(EventCard.class);
        when(event.id()).thenReturn(id);
        when(event.name()).thenReturn(name);
        when(event.projectName()).thenReturn(project);
        when(event.phase()).thenReturn(phase);
        when(event.holdingStatus()).thenReturn(holding);
        when(event.location()).thenReturn("保定");
        when(event.feeDescription()).thenReturn("");
        when(event.startsAt()).thenReturn(null);
        return event;
    }
}
