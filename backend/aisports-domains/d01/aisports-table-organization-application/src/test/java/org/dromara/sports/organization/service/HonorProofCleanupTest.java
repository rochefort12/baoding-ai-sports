package org.dromara.sports.organization.service;

import org.dromara.sports.organization.domain.SportsFile;
import org.dromara.sports.organization.mapper.SportsFileMapper;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import java.time.OffsetDateTime;
import java.util.List;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import static org.junit.jupiter.api.Assertions.*;

/** Mocked scheduled-cleanup reference boundary, not a live deletion test. */
@Tag("local")
class HonorProofCleanupTest {
    final SportsFileMapper mapper=mock(SportsFileMapper.class);final OrganizationFileStore store=mock(OrganizationFileStore.class);final JdbcTemplate jdbc=mock(JdbcTemplate.class);final UnreferencedFileCleanup service=new UnreferencedFileCleanup(mapper,store,jdbc);
    void setup(long id){when(jdbc.queryForList(anyString(),eq(Long.class))).thenReturn(List.of());when(jdbc.queryForList(anyString(),eq(String.class))).thenReturn(List.of());var f=new SportsFile();f.setId(id);f.setObjectKey("synthetic/private-proof");f.setStatus("active");when(mapper.selectList(any())).thenReturn(List.of(f));}
    @Test void currentCertificationProofIsKept(){setup(501);when(jdbc.queryForList(contains("certification_details->'proofFileIds'"),eq(Long.class))).thenReturn(List.of(501L));assertEquals(0,service.cleanup(OffsetDateTime.now()));verifyNoInteractions(store);verify(mapper,never()).updateById(any(SportsFile.class));}
    @Test void historicalProofIsKeptAfterCorrectionOrRevocation(){setup(502);when(jdbc.queryForList(contains("jsonb_array_elements(certification_history)"),eq(Long.class))).thenReturn(List.of(502L));assertEquals(0,service.cleanup(OffsetDateTime.now()));verifyNoInteractions(store);verify(mapper,never()).updateById(any(SportsFile.class));}
}
