package org.dromara.sports.organization.service;

import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.api.StoredObjectApi;
import org.dromara.sports.organization.domain.SportsFile;
import org.dromara.sports.organization.mapper.SportsFileMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Tag;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.*;

@Tag("local")
class ProfileAvatarStorageTest {
    private final SportsFileMapper files=mock(SportsFileMapper.class);
    private final StoredObjectApiImpl store=new StoredObjectApiImpl(files);

    @Test void avatarBindingCannotReuseAnotherAccountsFile(){
        var file=avatar();file.setOwnerAccountId(20L);when(files.selectById(42L)).thenReturn(file);
        assertThrows(ServiceException.class,()->store.readProfileAvatar(42L,10L));
    }

    @Test void organizerGenericImageReadCannotExposePrivateAvatar(){
        when(files.selectById(42L)).thenReturn(avatar());
        assertThrows(ServiceException.class,()->store.read(42L));
        assertThrows(ServiceException.class,()->store.readOwned(42L,"000000"));
    }

    @Test void existingProofCannotBeBoundAsAvatar(){
        var file=avatar();file.setPurpose(StoredObjectApi.PAYMENT_PROOF);when(files.selectById(42L)).thenReturn(file);
        assertThrows(ServiceException.class,()->store.readProfileAvatar(42L,10L));
    }

    @Test void nonImageIsRejectedBeforeObjectStorage(){
        assertThrows(ServiceException.class,()->store.keepProfileAvatar(10L,"<svg>payload</svg>".getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        verifyNoInteractions(files);
    }

    private SportsFile avatar(){var file=new SportsFile();file.setId(42L);file.setOwnerAccountId(10L);file.setPurpose(StoredObjectApi.PROFILE_AVATAR);file.setOwningTenantId("000000");file.setStatus("active");return file;}
}
