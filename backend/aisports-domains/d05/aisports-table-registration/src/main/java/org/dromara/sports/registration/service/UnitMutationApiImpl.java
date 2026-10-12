package org.dromara.sports.registration.service;
import org.dromara.sports.api.UnitMutationApi;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.math.BigDecimal;
@Service @RequiredArgsConstructor
public class UnitMutationApiImpl implements UnitMutationApi {
 private final RegistrationService registrations;
 public Long create(Long event,String name,String entryType,int min,int max,int limit,String requestKey,boolean charged,BigDecimal amount,String mode,String instruction,Long qr){return registrations.createUnit(new RegistrationService.UnitDraft(event,name,entryType,min,max,limit,requestKey,charged,amount,mode,instruction,qr)).id();}
}
