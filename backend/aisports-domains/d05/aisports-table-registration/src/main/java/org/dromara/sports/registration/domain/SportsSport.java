package org.dromara.sports.registration.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.io.Serial;
import java.io.Serializable;

/**
 * 运动目录。报名只用来确认羽毛球这一行，不在这里维护目录。
 */
@Data
@TableName("asp_sport")
public class SportsSport implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private String code;

    private String status;
}
