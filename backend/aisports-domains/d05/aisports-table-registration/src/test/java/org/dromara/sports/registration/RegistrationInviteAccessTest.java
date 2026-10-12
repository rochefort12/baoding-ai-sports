package org.dromara.sports.registration;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.PlatformAccountApi;
import org.dromara.sports.registration.domain.*;
import org.dromara.sports.registration.mapper.*;
import org.dromara.sports.registration.service.RegistrationService;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.util.*;
import java.util.function.Supplier;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;

/** 邀请链接不能扩大名单授权；使用真实 JSON 投影，数据库依赖隔离。 */
@Tag("local")
class RegistrationInviteAccessTest {
    private final Map<Class<?>,Object> deps = new HashMap<>();
    private final RegistrationService service = create();
    private <T>T dep(Class<T> type) { return type.cast(deps.get(type)); }
    private RegistrationService create() {
        try {
            var c = RegistrationService.class.getDeclaredConstructors()[0];
            return (RegistrationService)c.newInstance(Arrays.stream(c.getParameterTypes()).map(t -> {
                Object dependency = t == ObjectMapper.class ? new ObjectMapper() : mock(t);
                deps.put(t,dependency); return dependency;
            }).toArray());
        } catch (ReflectiveOperationException e) { throw new AssertionError(e); }
    }
    private SportsRegistrationMember member(long account, String status, String name) {
        var m = new SportsRegistrationMember(); m.setAccountId(account); m.setRegistrationId(701L);
        m.setUnitId(501L); m.setStatus(status);
        m.setPersonSnapshot("{\"legalName\":\"" + name + "\",\"mobile\":\"private-phone\",\"health\":\"private-health\"}");
        return m;
    }
    private void facts(long account, String status) {
        when(dep(PlatformAccountApi.class).currentAccountId()).thenReturn(Optional.of(201L));
        when(dep(SportsRegistrationMemberMapper.class).selectOne(any())).thenReturn(member(account,status,"虚构本人"));
        var r = new SportsRegistration(); r.setId(701L); r.setStatus("draft");
        when(dep(SportsRegistrationMapper.class).selectById(701L)).thenReturn(r);
        var u = new SportsCompetitionUnit(); u.setId(501L); u.setName("虚构项目"); u.setEntryType("pair");
        when(dep(SportsCompetitionUnitMapper.class).selectById(501L)).thenReturn(u);
    }
    private void ignoringTenant(Runnable assertion) {
        try (var tenant = mockStatic(TenantHelper.class)) {
            tenant.when(() -> TenantHelper.ignore(any(Supplier.class))).thenAnswer(i -> ((Supplier<?>)i.getArgument(0)).get());
            assertion.run();
        }
    }
    @Test void anonymousDeniedBeforeDatabase() {
        when(dep(PlatformAccountApi.class).currentAccountId()).thenReturn(Optional.empty());
        assertThrows(ServiceException.class, () -> service.inviteView("fixture"));
        verifyNoInteractions(dep(SportsRegistrationMemberMapper.class),dep(SportsRegistrationMapper.class));
    }
    @Test void anotherAccountDeniedBeforeRosterOrEvent() {
        facts(999L,"confirmed"); ignoringTenant(() -> {
            assertThrows(ServiceException.class, () -> service.inviteView("fixture"));
            verifyNoInteractions(dep(SportsRegistrationMapper.class),dep(SportsCompetitionUnitMapper.class));
            verify(dep(SportsRegistrationMemberMapper.class),never()).selectList(any());
        });
    }
    @Test void missingTokenDeniedBeforeRegistration() {
        when(dep(PlatformAccountApi.class).currentAccountId()).thenReturn(Optional.of(201L));
        ignoringTenant(() -> {
            assertThrows(ServiceException.class, () -> service.inviteView("missing"));
            verifyNoInteractions(dep(SportsRegistrationMapper.class),dep(SportsCompetitionUnitMapper.class));
        });
    }
    @Test void missingRegistrationDenied() {
        facts(201L,"confirmed"); when(dep(SportsRegistrationMapper.class).selectById(701L)).thenReturn(null);
        ignoringTenant(() -> {
            assertThrows(ServiceException.class, () -> service.inviteView("fixture"));
            verifyNoInteractions(dep(SportsCompetitionUnitMapper.class));
            verify(dep(SportsRegistrationMemberMapper.class),never()).selectList(any());
        });
    }
    @Test void pendingMemberDoesNotReadPartners() {
        facts(201L,"pending_confirmation"); ignoringTenant(() -> {
            var view = service.inviteView("fixture"); assertTrue(view.canRespond()); assertTrue(view.members().isEmpty());
            verify(dep(SportsRegistrationMemberMapper.class),never()).selectList(any());
        });
    }
    @Test void confirmedMemberSeesMinimalRosterAndNoDeclinedMember() {
        facts(201L,"confirmed");
        when(dep(SportsRegistrationMemberMapper.class).selectList(any())).thenReturn(List.of(
            member(201L,"confirmed","虚构本人"),member(202L,"pending_confirmation","虚构伙伴"),member(203L,"declined","已拒绝者")));
        ignoringTenant(() -> {
            var view=service.inviteView("fixture"); assertFalse(view.canRespond()); assertEquals(2,view.members().size());
            assertTrue(view.members().get(0).selfMember()); assertFalse(view.members().get(1).selfMember());
            assertEquals("虚构伙伴",view.members().get(1).legalName());
            var json=dep(ObjectMapper.class).valueToTree(view);
            assertEquals(Set.of("legalName","status","selfMember"), fieldNames(json.get("members").get(0)));
            assertFalse(json.toString().contains("private-")); assertFalse(json.toString().contains("已拒绝者"));
        });
    }
    private Set<String> fieldNames(com.fasterxml.jackson.databind.JsonNode node) {
        Set<String> fields=new HashSet<>(); node.fieldNames().forEachRemaining(fields::add); return fields;
    }
}
