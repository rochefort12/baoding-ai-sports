package org.dromara.sports.registration;

import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

@Tag("local")
class DeclarationAckRulesTest {
    @Test
    void emptyStatementDoesNotRequireAClick() {
        assertFalse(DeclarationAckRules.required(true, "  ", null));
        assertFalse(DeclarationAckRules.required(false, "请遵守赛场秩序", 1L));
    }

    @Test
    void textOrFileRequiresAClickAndAChangedFileNeedsAnother() {
        assertTrue(DeclarationAckRules.required(true, "参赛前请阅读免责声明", null));
        String first = DeclarationAckRules.digest("参赛前请阅读免责声明", null);
        String same = DeclarationAckRules.digest("  参赛前请阅读免责声明  ", null);
        String changed = DeclarationAckRules.digest("参赛前请阅读免责声明", 9L);
        assertEquals(64, first.length());
        assertEquals(first, same);
        assertNotEquals(first, changed);
    }
}
