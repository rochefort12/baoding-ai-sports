package org.dromara.sports.team.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.io.Serial;
import java.io.Serializable;

/**
 * 运动目录。建队只用来确认羽毛球这一行。类名避开报名模块的同名实体别名。
 */
@Data
@TableName("asp_sport")
public class TeamSportCatalog implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private String code;

    private String status;
}
