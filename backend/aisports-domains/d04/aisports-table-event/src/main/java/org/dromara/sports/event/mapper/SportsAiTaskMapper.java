package org.dromara.sports.event.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Select;
import org.dromara.sports.event.domain.SportsAiTask;

public interface SportsAiTaskMapper extends BaseMapper<SportsAiTask> {

    @Select("SELECT id FROM asp_ai_task WHERE id = #{id} FOR UPDATE")
    Long lockById(Long id);
}
