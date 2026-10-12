package org.dromara.sports.registration.service;

import com.baomidou.mybatisplus.core.conditions.Wrapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.api.FeeApi;
import org.dromara.sports.registration.domain.SportsRegistration;
import org.dromara.sports.registration.mapper.SportsRegistrationMapper;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@Tag("local")
class RegistrationOperationsTest {
    private final RegistrationService registrations = mock(RegistrationService.class);
    private final SportsRegistrationMapper mapper = mock(SportsRegistrationMapper.class);
    private final FeeApi fees = mock(FeeApi.class);
    private final RegistrationOperationsApiImpl api = new RegistrationOperationsApiImpl(registrations,mapper,fees);
    @Test void unauthorizedEventStopsBeforeAnyRegistrationOrFinancialRead() {
        when(registrations.listManagedUnits(9L)).thenThrow(new ServiceException("拒绝"));
        assertThrows(ServiceException.class, () -> api.summarize(9L));
        verifyNoInteractions(mapper,fees);
    }
    @Test void submittedDraftWithdrawnAndSettledAreCountedIndependently() {
        when(registrations.listManagedUnits(9L)).thenReturn(List.of(new RegistrationService.UnitCard(7L,9L,"测试项目","pair",2,2,24,3)));
        var submitted = row(1,"submitted",true);
        var approved = row(2,"approved",true);
        var draft = row(3,"draft",false);
        var withdrawn = row(4,"withdrawn",true);
        when(mapper.selectList(any(Wrapper.class))).thenReturn(List.of(submitted,approved,draft,withdrawn));
        when(fees.current("test-tenant",1L)).thenReturn(Optional.of(fee("open",true,null)));
        when(fees.current("test-tenant",2L)).thenReturn(Optional.of(fee("settled",false,null)));
        when(fees.current("test-tenant",3L)).thenReturn(Optional.empty());
        when(fees.current("test-tenant",4L)).thenReturn(Optional.of(fee("void",true,18L)));
        var s = api.summarize(9L);
        assertEquals(2,s.currentEntries()); assertEquals(1,s.pendingReview());
        assertEquals(1,s.unpaidEntries()); assertEquals(1,s.declaredEntries());
        assertEquals(1,s.pendingFunds()); assertEquals(3,s.occupied()); assertEquals(24,s.capacity());
        assertEquals(7,s.trend().size()); assertEquals(3,s.trend().stream().mapToLong(d->d.count()).sum());
    }
    @Test void failedFinancialReadDoesNotFabricateZeroCounts() {
        when(registrations.listManagedUnits(9L)).thenReturn(List.of(new RegistrationService.UnitCard(7L,9L,"测试项目","individual",1,1,20,1)));
        when(mapper.selectList(any(Wrapper.class))).thenReturn(List.of(row(1,"submitted",true)));
        when(fees.current(anyString(),anyLong())).thenThrow(new ServiceException("费用读取失败"));
        assertThrows(ServiceException.class, () -> api.summarize(9L));
    }
    private SportsRegistration row(long id,String state,boolean submitted) {
        var r = new SportsRegistration(); r.setId(id); r.setUnitId(7L); r.setTenantId("test-tenant"); r.setStatus(state);
        if(submitted) r.setSubmittedAt(OffsetDateTime.now(ZoneOffset.ofHours(8)));
        return r;
    }
    private FeeApi.ObligationView fee(String state,boolean declared,Long action) {
        return new FeeApi.ObligationView(5L,6L,BigDecimal.TEN,"offline",state,"测试",declared,action);
    }
}
