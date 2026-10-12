package org.dromara.sports.registration.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.api.PlatformAccountApi;
import org.dromara.sports.registration.domain.*;
import org.dromara.sports.registration.mapper.*;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.util.*;
import java.util.function.Supplier;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 模拟依赖仅核对草稿/提交门槛，真实普通页面与事务回滚另有HTTP证据。 */
@Tag("local")
class FieldCatalogDraftBoundaryTest {
    private final Map<Class<?>,Object> deps = new HashMap<>();
    private final FieldCatalogService service = create();
    private SportsRegistration registration;
    private SportsRegistrationMember member;
    private SportsEventField field;
    private <T> T dep(Class<T> type) { return type.cast(deps.get(type)); }
    private FieldCatalogService create() {
        try {
            var constructor=FieldCatalogService.class.getDeclaredConstructors()[0];
            return (FieldCatalogService)constructor.newInstance(Arrays.stream(constructor.getParameterTypes()).map(type->{
                Object value=type==ObjectMapper.class?new ObjectMapper():mock(type);deps.put(type,value);return value;
            }).toArray());
        }catch(ReflectiveOperationException error){throw new AssertionError(error);}
    }
    private void facts(String type) {
        registration=new SportsRegistration();registration.setId(701L);registration.setUnitId(501L);registration.setStatus("draft");registration.setTenantId("owned-tenant");
        member=new SportsRegistrationMember();member.setId(601L);member.setRegistrationId(701L);member.setAccountId(201L);member.setStatus("confirmed");
        var unit=new SportsCompetitionUnit();unit.setId(501L);unit.setEventId(401L);
        field=new SportsEventField();field.setId(301L);field.setEventId(401L);field.setOrgFieldId(101L);field.setRequired(true);
        var definition=new SportsOrgField();definition.setId(101L);definition.setLabel("测试本人采集项");definition.setValueType(type);definition.setOptions("[\"右手\",\"左手\"]");
        when(dep(PlatformAccountApi.class).currentAccountId()).thenReturn(Optional.of(201L));
        when(dep(SportsRegistrationMapper.class).selectById(701L)).thenReturn(registration);
        when(dep(SportsRegistrationMemberMapper.class).selectOne(any())).thenReturn(member);
        when(dep(SportsRegistrationMemberMapper.class).selectById(601L)).thenReturn(member);
        when(dep(SportsCompetitionUnitMapper.class).selectById(501L)).thenReturn(unit);
        when(dep(SportsEventFieldMapper.class).selectById(301L)).thenReturn(field);
        when(dep(SportsEventFieldMapper.class).selectList(any())).thenReturn(List.of(field));
        when(dep(SportsOrgFieldMapper.class).selectById(101L)).thenReturn(definition);
    }
    private void tenant(Runnable work) {
        try(var helper=mockStatic(TenantHelper.class)){
            helper.when(()->TenantHelper.ignore(any(Supplier.class))).thenAnswer(i->((Supplier<?>)i.getArgument(0)).get());
            helper.when(()->TenantHelper.dynamic(eq("owned-tenant"),any(Supplier.class))).thenAnswer(i->((Supplier<?>)i.getArgument(1)).get());
            work.run();
        }
    }
    @Test void blankRequiredFieldCanRemainAnUnsavedValueInDraft() {
        facts("number");tenant(()->assertDoesNotThrow(()->service.saveMine(701L,List.of(new FieldCatalogService.ValueDraft(301L," ")))));
        verify(dep(SportsEntryFieldValueMapper.class),never()).insert(any(SportsEntryFieldValue.class));
    }
    @Test void clearingAnExistingRequiredDraftAnswerDeletesOnlyThatOwnValue() {
        facts("number");var old=new SportsEntryFieldValue();old.setId(801L);old.setValueText("3");
        when(dep(SportsEntryFieldValueMapper.class).selectOne(any())).thenReturn(old);
        tenant(()->assertDoesNotThrow(()->service.saveMine(701L,List.of(new FieldCatalogService.ValueDraft(301L,"")))));
        verify(dep(SportsEntryFieldValueMapper.class)).deleteById(801L);
    }
    @Test void nonemptyNumberStillRequiresANumber() { invalid("number","not-a-number"); }
    @Test void nonemptyDateStillRequiresAValidDate() { invalid("date","2026-99-99"); }
    @Test void nonemptyEnumerationStillRequiresAnAllowedChoice() { invalid("enum","未知选项"); }
    private void invalid(String type,String answer) {
        facts(type);tenant(()->assertThrows(ServiceException.class,()->service.saveMine(701L,List.of(new FieldCatalogService.ValueDraft(301L,answer)))));
        verify(dep(SportsEntryFieldValueMapper.class),never()).insert(any(SportsEntryFieldValue.class));
    }
    @Test void validPartialDraftPersistsAnOwnedTrimmedAnswerAndFieldSnapshot() {
        facts("number");tenant(()->service.saveMine(701L,List.of(new FieldCatalogService.ValueDraft(301L," 3 "))));
        var captured=ArgumentCaptor.forClass(SportsEntryFieldValue.class);verify(dep(SportsEntryFieldValueMapper.class)).insert(captured.capture());
        assertEquals(601L,captured.getValue().getRegistrationMemberId());assertEquals(301L,captured.getValue().getEventFieldId());assertEquals("3",captured.getValue().getValueText());assertEquals("number",captured.getValue().getTypeSnapshot());
    }
    @Test void formalSubmitStillRejectsMissingRequiredDraftAnswers() {
        facts("number");assertThrows(ServiceException.class,()->service.requireFilled(401L,List.of(member)));
        verify(dep(SportsEntryFieldValueMapper.class),never()).updateById(any(SportsEntryFieldValue.class));
    }
    @Test void alreadySubmittedEntryStillRejectsDraftEdits() {
        facts("number");registration.setStatus("submitted");tenant(()->assertThrows(ServiceException.class,()->service.saveMine(701L,List.of(new FieldCatalogService.ValueDraft(301L,"3")))));
        verifyNoInteractions(dep(SportsEntryFieldValueMapper.class));
    }
    @Test void personOutsideTheEntryStillCannotSaveAnyDraftAnswer() {
        facts("number");when(dep(SportsRegistrationMemberMapper.class).selectOne(any())).thenReturn(null);
        tenant(()->assertThrows(ServiceException.class,()->service.saveMine(701L,List.of(new FieldCatalogService.ValueDraft(301L,"3")))));
        verifyNoInteractions(dep(SportsEntryFieldValueMapper.class));
    }
}
