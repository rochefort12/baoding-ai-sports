package org.dromara.sports.registration.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.sports.platform.core.ScopedJdbc;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.mock;

/** A submitted entry must be able to freeze required field snapshots atomically. */
@Tag("local")
class RegistrationActionWriteScopeTest {
    private final RegistrationActionProvider provider = new RegistrationActionProvider(
        mock(RegistrationService.class), mock(ScopedJdbc.class), new ObjectMapper());

    @Test void submissionIncludesFieldSnapshotWriteButNotGlobalProfileWrite() {
        var definition = provider.capabilities().stream().filter(row -> row.code().equals("registration.submit")).findFirst().orElseThrow();
        assertTrue(definition.writes().contains("asp_entry_field_value"));
        assertFalse(definition.writes().contains("asp_person"));
        assertFalse(definition.writes().contains("asp_profile_display"));
    }

    @Test void queryingMyEntriesDoesNotAcquireSnapshotWrites() {
        var definition = provider.capabilities().stream().filter(row -> row.code().equals("registration.mine")).findFirst().orElseThrow();
        assertTrue(definition.writes().isEmpty());
    }
}
