package org.dromara.sports.team.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.dromara.sports.team.domain.TeamSportCatalog;

/**
 * 建队只读取运动目录。类名避开报名模块里的同名 Mapper 和实体别名。
 */
public interface TeamSportCatalogMapper extends BaseMapper<TeamSportCatalog> {
}
