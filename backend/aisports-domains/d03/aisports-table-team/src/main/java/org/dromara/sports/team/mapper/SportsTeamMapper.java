package org.dromara.sports.team.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.dromara.sports.team.domain.SportsTeam;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Param;

public interface SportsTeamMapper extends BaseMapper<SportsTeam> {
    /** PG 队伍行锁使邀请接受与队长转让、解散、移除在同一权威边界内串行。 */
    @Select("SELECT * FROM asp_team WHERE id = #{id} FOR UPDATE")
    SportsTeam lockTeam(@Param("id") Long id);
}
