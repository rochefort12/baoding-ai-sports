package org.dromara.sports.competition;

import com.baomidou.mybatisplus.core.metadata.TableInfoHelper;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.MybatisConfiguration;
import org.apache.ibatis.builder.MapperBuilderAssistant;
import org.dromara.common.tenant.helper.TenantHelper;
import org.dromara.sports.competition.domain.CompetitionCheckin;
import org.dromara.sports.competition.mapper.*;
import org.dromara.sports.competition.service.CompetitionWithdrawalApiImpl;
import org.junit.jupiter.api.*;
import java.util.List;
import java.util.function.Supplier;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** An attendance fact from another project cannot lock an otherwise legal full withdrawal. */
@Tag("local")
class ProjectWithdrawalScopeTest {
    @BeforeAll static void metadata(){TableInfoHelper.initTableInfo(new MapperBuilderAssistant(new MybatisConfiguration(),"fixture"),CompetitionCheckin.class);}
    private boolean blocked(Long attendedUnit, boolean hasMatch){
        var matches=mock(CompetitionMatchEntryMapper.class);var checkins=mock(CompetitionCheckinMapper.class);
        when(matches.selectCount(any())).thenReturn(hasMatch?1L:0L);
        when(checkins.selectCount(any())).thenAnswer(i->{
            LambdaQueryWrapper<CompetitionCheckin> q=i.getArgument(0);String sql=q.getSqlSegment();
            assertTrue(sql.contains("unit_id")&&sql.contains("IS NULL"));assertTrue(q.getParamNameValuePairs().containsValue(501L));
            return attendedUnit==null||attendedUnit==501L?1L:0L;
        });
        try(var tenant=mockStatic(TenantHelper.class)){
            tenant.when(()->TenantHelper.dynamic(eq("fixture"),any(Supplier.class))).thenAnswer(i->((Supplier<?>)i.getArgument(1)).get());
            return new CompetitionWithdrawalApiImpl(matches,checkins).blocksFullWithdrawal("fixture",901L,501L,701L,List.of(401L));
        }
    }
    @Test void anotherProjectDoesNotBlock(){assertFalse(blocked(502L,false));}
    @Test void sameProjectBlocks(){assertTrue(blocked(501L,false));}
    @Test void unknownLegacyProjectRemainsConservative(){assertTrue(blocked(null,false));}
    @Test void existingFixtureStillBlocks(){assertTrue(blocked(502L,true));}
}
