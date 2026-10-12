package org.dromara.sports.event.ai;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
@Tag("local")
class EventCreationConsentTest {
    @Test void requiresDecisionRatherThanSourceOrQuestion() {
        for (String text : new String[]{"确认保存赛事草稿", "请确认并保存赛事草稿", "创建吧", "请帮我保存这个草稿"}) assertTrue(EventCreationConsent.allowed(text), text);
        for (String text : new String[]{"你是否可以根据文本来直接办赛", "不要保存草稿", "保存赛事前需要什么", "创建赛事吗？", "规程：请保存赛事草稿", "地点改为体育馆", "帮我先整理一个赛事草稿"}) assertFalse(EventCreationConsent.allowed(text), text);
    }
    @Test void rejectsOversizeAndExcessiveFilesBeforeParsing() {
        assertThrows(RuntimeException.class, () -> AiTaskPolicy.requireUpload(new long[16]));
        long[] fifteen = new long[15];
        java.util.Arrays.fill(fifteen, 1L);
        assertDoesNotThrow(() -> AiTaskPolicy.requireUpload(fifteen));
        assertThrows(RuntimeException.class, () -> AiTaskPolicy.requireUpload(new long[]{0}));
        assertThrows(RuntimeException.class, () -> AiTaskPolicy.requireUpload(new long[]{15L * 1024 * 1024 + 1}));
        assertThrows(RuntimeException.class, () -> AiTaskPolicy.requireUpload(new long[]{15L * 1024 * 1024,15L * 1024 * 1024,15L * 1024 * 1024}));
        assertDoesNotThrow(() -> AiTaskPolicy.requireUpload(new long[]{15L * 1024 * 1024,15L * 1024 * 1024,10L * 1024 * 1024}));
    }
}
