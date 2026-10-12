package org.dromara.sports.event.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;

/**
 * 任务上的一份原始资料。文件本体在对象存储。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_ai_task_file")
public class SportsAiTaskFile extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long taskId;

    private Long fileId;

    private Integer sortOrder;

    private String mediaKind;

    private String originalName;

    private Integer pageCount;

    @Version
    private Integer version;
}
