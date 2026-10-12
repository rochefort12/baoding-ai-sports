package org.dromara.sports.organization.service;

import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.organization.domain.SportsFile;
import org.dromara.sports.organization.mapper.SportsFileMapper;
import org.dromara.sports.api.StoredObjectApi;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.io.ByteArrayOutputStream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;

/** No live OSS used: tests private-purpose denial before any object read. */
@Tag("local")
class HonorProofStorageTest {
    final SportsFileMapper mapper=mock(SportsFileMapper.class);final StoredObjectApiImpl service=new StoredObjectApiImpl(mapper);
    SportsFile file(String purpose) {var f=new SportsFile();f.setId(5L);f.setOwnerAccountId(100L);f.setOwningTenantId("000000");f.setPurpose(purpose);f.setStatus("active");return f;}
    @Test void genericMediaCannotExposeHonorProof() {when(mapper.selectById(5L)).thenReturn(file(StoredObjectApi.HONOR_PROOF));assertThrows(ServiceException.class,()->service.read(5));assertThrows(ServiceException.class,()->service.readOwned(5,"000000"));}
    @Test void honorProofRequiresCorrectOwnerAndPurpose() {when(mapper.selectById(5L)).thenReturn(file(StoredObjectApi.HONOR_PROOF));assertThrows(ServiceException.class,()->service.readHonorProof(5,101));when(mapper.selectById(5L)).thenReturn(file(StoredObjectApi.PROFILE_AVATAR));assertThrows(ServiceException.class,()->service.readHonorProof(5,100));}
    @Test void oversizedUnknownAndOfficeProofsRejectBeforeStorage()throws Exception {assertThrows(ServiceException.class,()->service.keepHonorProof(100,new byte[5*1024*1024+1]));assertThrows(ServiceException.class,()->service.keepHonorProof(100,"not proof".getBytes()));var bytes=new ByteArrayOutputStream();try(var zip=new ZipOutputStream(bytes)){zip.putNextEntry(new ZipEntry("word/document.xml"));zip.write("<document/>".getBytes());zip.closeEntry();}assertThrows(ServiceException.class,()->service.keepHonorProof(100,bytes.toByteArray()));verifyNoInteractions(mapper);}
}
