package org.dromara.sports.event.ai;

import org.dromara.common.core.exception.ServiceException;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

@Tag("local")
class PromotionCopyGuardTest {

    private static final String FACTS = "城市交流赛 保定运动馆 2026-10-24 09:00 男子单打 0.00 免费";

    @Test
    void keepsInvitationWhenNumbersComeFromTheEvent() {
        PromotionCopyGuard.Copy copy = PromotionCopyGuard.accept(
            "来保定打球", "10月这场见", "2026-10-24 09:00 在保定运动馆，男子单打免费。", "周末来打球", FACTS, false);
        assertEquals("来保定打球", copy.headline());
    }

    @Test
    void rejectsAmountTheEventDoesNotHave() {
        ServiceException rejected = assertThrows(ServiceException.class, () -> PromotionCopyGuard.accept(
            "来打球", "欢迎你", "报名只要198.00元", "来吧", FACTS, false));
        assertTrue(rejected.getMessage().contains("数字"));
        assertTrue(rejected.getMessage().contains("198"));
        assertTrue(rejected.getMessage().contains("基础文案仍可使用"));
    }

    @Test
    void acceptsEquivalentAmountFormatsWithoutAcceptingOtherAmounts() {
        PromotionCopyGuard.accept("来打球", "欢迎你", "参赛费198元", "来吧", "参赛费198.00元", false);
        assertThrows(ServiceException.class, () -> PromotionCopyGuard.accept("来打球", "欢迎你", "参赛费199元", "来吧", "参赛费198.00元", false));
    }

    @Test
    void statesCancellationWithoutInventingALink() {
        PromotionCopyGuard.Copy copy = PromotionCopyGuard.accept(
            "这场暂停", "谢谢关注", "原定交流不再举行。", "谢谢关注", FACTS, true);
        assertTrue(copy.groupBody().contains("已经取消"));
    }
}
