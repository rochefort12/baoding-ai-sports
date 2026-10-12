package org.dromara.sports.tables.d02.profile_display;

import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.api.StoredObjectApi;
import org.dromara.sports.platform.core.BusinessSupport;
import org.dromara.sports.platform.core.ScopedJdbc;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Tag;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** 身份及存储模拟；验证授权和失败留存，不代替真实MinIO上传。 */
@Tag("local")
class ProfileAvatarServiceTest {
    private final ScopedJdbc db=mock(ScopedJdbc.class);
    private final StoredObjectApi objects=mock(StoredObjectApi.class);
    private final ProfileAvatarService avatars=new ProfileAvatarService(db,objects);

    @Test void anonymousCannotReadPrivateAvatar(){
        when(db.one(anyString(),eq(20L))).thenReturn(Map.of("avatar_file_id",42L,"public_visible",false));
        assertThrows(ServiceException.class,()->avatars.image(20L,true));
        verifyNoInteractions(objects);
    }

    @Test void unrelatedParticipantCannotReadOrBindAnotherAvatar(){
        try(var identity=mockStatic(BusinessSupport.class,CALLS_REAL_METHODS)){
            identity.when(BusinessSupport::account).thenReturn(10L);
            when(db.one(anyString(),eq(20L))).thenReturn(Map.of("avatar_file_id",42L,"public_visible",false));
            when(db.count(anyString(),eq(10L),eq(20L))).thenReturn(0L);
            assertThrows(ServiceException.class,()->avatars.image(20L,false));
            verifyNoInteractions(objects);
        }
    }

    @Test void currentTeammateReadsOnlyTargetOwnedAvatar(){
        try(var identity=mockStatic(BusinessSupport.class,CALLS_REAL_METHODS)){
            identity.when(BusinessSupport::account).thenReturn(10L);
            when(db.one(anyString(),eq(20L))).thenReturn(Map.of("avatar_file_id",42L,"public_visible",false));
            when(db.count(anyString(),eq(10L),eq(20L))).thenReturn(1L);
            var image=new StoredObjectApi.ImageBody("image/png",new byte[]{1});
            when(objects.readProfileAvatar(42L,20L)).thenReturn(image);
            assertSame(image,avatars.image(20L,false));
            verify(objects).readProfileAvatar(42L,20L);
        }
    }

    @Test void closingPublicCardImmediatelyBlocksAnonymousImage(){
        when(db.one(anyString(),eq(20L))).thenReturn(Map.of("avatar_file_id",42L,"public_visible",true),Map.of("avatar_file_id",42L,"public_visible",false));
        when(objects.readProfileAvatar(42L,20L)).thenReturn(new StoredObjectApi.ImageBody("image/png",new byte[]{1}));
        assertNotNull(avatars.image(20L,true));
        assertThrows(ServiceException.class,()->avatars.image(20L,true));
        verify(objects,times(1)).readProfileAvatar(42L,20L);
    }

    @Test void storageFailurePreservesOldAvatarAndNickname(){
        try(var identity=mockStatic(BusinessSupport.class,CALLS_REAL_METHODS)){
            identity.when(BusinessSupport::account).thenReturn(10L);
            when(db.count(anyString(),eq(10L))).thenReturn(1L);
            when(db.one(anyString(),eq(10L))).thenReturn(Map.of("version",3));
            when(objects.keepProfileAvatar(eq(10L),any())).thenThrow(new ServiceException("对象存储暂时不可用"));
            assertThrows(ServiceException.class,()->avatars.upload(new byte[]{1,2,3},3));
            verify(db,never()).update(anyString(),any(),any(),any());
        }
    }

    @Test void staleVersionRejectsBeforeObjectUpload(){
        try(var identity=mockStatic(BusinessSupport.class,CALLS_REAL_METHODS)){
            identity.when(BusinessSupport::account).thenReturn(10L);
            when(db.count(anyString(),eq(10L))).thenReturn(1L);
            when(db.one(anyString(),eq(10L))).thenReturn(Map.of("version",4));
            assertThrows(ServiceException.class,()->avatars.upload(new byte[]{1},3));
            verifyNoInteractions(objects);
        }
    }
}
