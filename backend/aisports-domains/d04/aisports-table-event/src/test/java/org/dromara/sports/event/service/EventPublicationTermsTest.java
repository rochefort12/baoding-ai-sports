package org.dromara.sports.event.service;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.*;
import static org.junit.jupiter.api.Assertions.*;
@Tag("local")
class EventPublicationTermsTest {
    final ObjectMapper mapper=new ObjectMapper();
    @Test void draftIsNotPublicConsentAndLegacyOmissionPreservesSource() {
        String draft=EventPublicationTerms.draft(mapper,"{}",601L,"来源联系人","organizer@simulation.invalid","截止前全额退款");
        assertTrue(EventPublicationTerms.isDraft(EventPublicationTerms.read(mapper,draft)));
        assertEquals("截止前全额退款",EventPublicationTerms.refund(mapper,draft,"平台办理说明"));
        assertEquals(draft,EventPublicationTerms.draft(mapper,draft,601L,null,null,null));
    }
    @Test void confirmedPromiseCannotChangeAndLegacyDoesNotInventOwnerRules() {
        String frozen="{\"organizationId\":601,\"contactName\":\"原联系人\",\"contactMethod\":\"原渠道\",\"refundTerms\":\"全额退款\",\"confirmedAt\":\"2026-10-11T12:00:00+08:00\"}";
        assertFalse(EventPublicationTerms.isDraft(EventPublicationTerms.read(mapper,frozen)));
        assertThrows(org.dromara.common.core.exception.ServiceException.class,()->EventPublicationTerms.draft(mapper,frozen,601L,null,null,"不退款"));
        assertEquals(frozen,EventPublicationTerms.draft(mapper,frozen,601L,"原联系人","原渠道","全额退款"));
        assertEquals("平台办理说明",EventPublicationTerms.refund(mapper,"{}","平台办理说明"));
    }
}
