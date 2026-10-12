package org.dromara.sports.event.service;

import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.util.List;
import static org.junit.jupiter.api.Assertions.*;

@Tag("local")
class PromotionBasicCopyTest {
    @Test void preparesUsefulCopyFromCurrentFactsWithoutAi() {
        var copy = EventPromotionService.basicCopy("模拟城市球赛", "2026-10-16 09:00", "模拟场馆", List.of(new EventPromotionService.FeeLine("男子单打", "198.00", "赛事统一收款")), true, false);
        assertTrue(copy.groupBody().contains("男子单打：198.00元／单")); assertTrue(copy.groupBody().contains("模拟场馆")); assertFalse(copy.invitation().isBlank());
    }
    @Test void doesNotInviteRegistrationForDraftOrCancelledEvent() {
        assertTrue(EventPromotionService.basicCopy("模拟赛", "", "", List.of(), false, false).invitation().contains("正式发布"));
        var copy = EventPromotionService.basicCopy("模拟赛", "", "", List.of(new EventPromotionService.FeeLine("项目", "", "")), true, true);
        assertTrue(copy.invitation().contains("取消")); assertTrue(copy.groupBody().contains("费用待确认")); assertFalse(copy.groupBody().contains("免费"));
    }
}
