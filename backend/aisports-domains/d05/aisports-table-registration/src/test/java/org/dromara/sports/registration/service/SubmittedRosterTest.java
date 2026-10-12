package org.dromara.sports.registration.service;
import com.baomidou.mybatisplus.core.conditions.Wrapper;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.api.EventRegistrationApi;
import org.dromara.sports.registration.domain.*;
import org.dromara.sports.registration.mapper.*;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@Tag("local")
class SubmittedRosterTest {
    private final RegistrationService service = mock(RegistrationService.class, CALLS_REAL_METHODS);
    private final SportsRegistrationMapper registrations = mock(SportsRegistrationMapper.class);
    private final SportsCompetitionUnitMapper units = mock(SportsCompetitionUnitMapper.class);
    private final SportsRosterVersionMapper versions = mock(SportsRosterVersionMapper.class);
    private final SportsRosterMemberMapper members = mock(SportsRosterMemberMapper.class);
    private final EventRegistrationApi events = mock(EventRegistrationApi.class);
    private void setup(boolean allowed) {
        ReflectionTestUtils.setField(service,"registrationMapper",registrations); ReflectionTestUtils.setField(service,"unitMapper",units);
        ReflectionTestUtils.setField(service,"rosterVersionMapper",versions); ReflectionTestUtils.setField(service,"rosterMemberMapper",members);
        ReflectionTestUtils.setField(service,"eventRegistrationApi",events); ReflectionTestUtils.setField(service,"objectMapper",new ObjectMapper());
        var registration = new SportsRegistration(); registration.setId(1L); registration.setUnitId(2L); registration.setRosterRevision(1);
        var unit = new SportsCompetitionUnit(); unit.setId(2L); unit.setEventId(3L);
        when(registrations.selectById(1L)).thenReturn(registration); when(units.selectById(2L)).thenReturn(unit);
        when(events.managedGate(3L)).thenReturn(allowed ? Optional.of(mock(EventRegistrationApi.EventRegistrationGate.class)) : Optional.empty());
    }
    @Test void rejectsOutsideOrganizationBeforeReadingPersonalSnapshots() {
        setup(false); assertThrows(ServiceException.class, () -> service.submittedRoster(1L)); verifyNoInteractions(versions,members);
    }
    @Test void projectsOnlySubmittedWhitelistAndMarksLegacyFieldCoverage() {
        setup(true); var version = new SportsRosterVersion(); version.setId(4L);
        when(versions.selectOne(any(Wrapper.class))).thenReturn(version);
        var old = new SportsRosterMember(); old.setId(5L); old.setPersonSnapshot("{\"legalName\":\"测试成员\",\"gender\":\"male\",\"birthDate\":\"2000-01-01\",\"mobile\":\"16600000001\",\"hiddenSecret\":\"never-project\"}");
        var modern = new SportsRosterMember(); modern.setId(6L); modern.setPersonSnapshot("{\"legalName\":\"另一成员\",\"fields\":[{\"label\":\"参赛组别\",\"value\":\"青年\"}]}");
        when(members.selectList(any(Wrapper.class))).thenReturn(List.of(old,modern));
        var data = service.submittedRoster(1L); assertEquals("2000-01-01",data.get(0).birthDate()); assertFalse(data.get(0).fieldsCaptured());
        assertTrue(data.get(1).fieldsCaptured()); assertEquals("青年",data.get(1).fields().get(0).value()); assertFalse(data.toString().contains("never-project"));
    }
    @Test void missingOrCorruptSnapshotIsNotReportedAsEmptySuccess() {
        setup(true); assertThrows(ServiceException.class, () -> service.submittedRoster(1L));
        var version = new SportsRosterVersion(); version.setId(4L); when(versions.selectOne(any(Wrapper.class))).thenReturn(version);
        var member = new SportsRosterMember(); member.setPersonSnapshot("broken"); when(members.selectList(any(Wrapper.class))).thenReturn(List.of(member));
        assertThrows(ServiceException.class, () -> service.submittedRoster(1L));
    }
}
