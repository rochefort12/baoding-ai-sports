package org.dromara.sports.finance.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.io.Serial;
import java.io.Serializable;

/**
 * 收费页用来显示竞赛单元名称。不在这里修改报名坐标。
 */
@Data
@TableName("asp_competition_unit")
public class BillingUnit implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private String tenantId;

    private Long eventId;

    private String name;
}
