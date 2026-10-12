package org.dromara.sports.event.ai;

import org.dromara.sports.platform.core.ActionContext;
import org.dromara.sports.platform.core.SportsAction;
import org.dromara.sports.platform.core.SqlScope;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.web.multipart.MultipartFile;

import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

/** Tests the actual upload entry boundary through the SQL guard, not a permissive mock. */
@Tag("local")
class AiUploadSqlScopeTest {
    @AfterEach void clear() { ActionContext.clear(); }

    @Test void uploadedPrivateSourceAndSourceLinksAreDeclaredWhileUnrelatedObjectsRemainDenied() throws Exception {
        var definition = SportsEventRunAiTaskService.class.getMethod("upload", MultipartFile[].class, boolean.class)
            .getAnnotation(SportsAction.class);
        ActionContext.bind(new ActionContext("synthetic", "platform", 1L, null, "ui", definition.value(),
            "test", null, Set.of(definition.reads()), Set.of(definition.writes())));
        assertDoesNotThrow(() -> SqlScope.check("INSERT INTO asp_file(id,purpose) VALUES(1,'ai-source')", true, true));
        assertDoesNotThrow(() -> SqlScope.check("SELECT id FROM asp_file WHERE id=1", false, true));
        assertDoesNotThrow(() -> SqlScope.check("INSERT INTO asp_ai_task_file(id,task_id,file_id) VALUES(2,3,1)", true, true));
        assertThrows(RuntimeException.class, () -> SqlScope.check("UPDATE asp_agent_definition SET status='enabled'", true, true));
    }

    @Test void confirmationCanReadOwnedSourceAndStoreDerivedCoverWithoutOpeningAgentAdministration() throws Exception {
        var definition = SportsEventRunAiTaskService.class.getMethod("confirm", long.class, SportsEventRunAiTaskService.ConfirmDraft.class)
            .getAnnotation(SportsAction.class);
        ActionContext.bind(new ActionContext("synthetic", "platform", 1L, null, "ui", definition.value(),
            "test", null, Set.of(definition.reads()), Set.of(definition.writes())));
        assertDoesNotThrow(() -> SqlScope.check("SELECT id FROM asp_file WHERE purpose='ai-source' AND id=1", false, true));
        assertDoesNotThrow(() -> SqlScope.check("INSERT INTO asp_file(id,purpose) VALUES(2,'event-banner')", true, true));
        assertThrows(RuntimeException.class, () -> SqlScope.check("UPDATE asp_agent_definition SET status='enabled'", true, true));
    }
}
