package org.dromara.sports.event.service;

import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.api.RegistrationOperationsApi;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.util.List;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@Tag("local")
class EventOperationsTest {
    private final EventPublicationService events = mock(EventPublicationService.class);
    private final RegistrationOperationsApi registrations = mock(RegistrationOperationsApi.class);
    private final EventOperationsService service = new EventOperationsService(events, registrations);
    @Test void noReviewChargedSubmissionWaitsForPaymentInsteadOfQualificationReview() {
        var event = event("normal","none");
        when(events.listManaged()).thenReturn(List.of(event));
        when(registrations.summarize(9L)).thenReturn(new RegistrationOperationsApi.Summary(1,1,1,1,0,1,20,List.of()));
        var row = service.snapshot().events().get(0);
        assertEquals(0,row.pendingReview());assertEquals(1,row.unpaidEntries());assertEquals(1,row.declaredEntries());
    }
    @Test void cancellationStopsQualificationButKeepsFinancialSettlementTodo() {
        var event = event("cancelled","manual");
        when(events.listManaged()).thenReturn(List.of(event));
        when(registrations.summarize(9L)).thenReturn(new RegistrationOperationsApi.Summary(1,1,0,0,1,0,20,List.of()));
        var row = service.snapshot().events().get(0);
        assertEquals(0,row.pendingReview());assertEquals(1,row.pendingFunds());
    }
    @Test void organizationDeniedDoesNotReadRegistrationCounts() {
        when(events.listManaged()).thenThrow(new ServiceException("组织授权拒绝"));
        assertThrows(ServiceException.class,service::snapshot);
        verifyNoInteractions(registrations);
    }
    private EventPublicationService.EventCard event(String holding,String review) {
        var e = mock(EventPublicationService.EventCard.class);
        when(e.id()).thenReturn(9L);when(e.holdingStatus()).thenReturn(holding);
        when(e.phase()).thenReturn("registration");when(e.registrationReview()).thenReturn(review);
        return e;
    }
}
