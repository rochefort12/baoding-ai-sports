package org.dromara.sports.registration.service;

import lombok.RequiredArgsConstructor;
import org.dromara.sports.api.RegistrationGuideApi;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class RegistrationGuideApiImpl implements RegistrationGuideApi {

    private final RegistrationService registrationService;

    @Override
    public String myStatus(Long accountId, int offset) {
        return registrationService.guideSnapshot(accountId, offset);
    }
}
