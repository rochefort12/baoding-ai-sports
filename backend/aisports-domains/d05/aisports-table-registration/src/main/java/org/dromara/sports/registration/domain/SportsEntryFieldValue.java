package org.dromara.sports.registration.domain;

import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.mybatis.handler.JsonbTypeHandler;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;

/**
 * 报名成员自己填写的采集项。提交时记下当时的名称、类型和选项。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "asp_entry_field_value", autoResultMap = true)
public class SportsEntryFieldValue extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long registrationMemberId;

    private Long eventFieldId;

    private String valueText;

    private String labelSnapshot;

    private String typeSnapshot;

    @TableField(typeHandler = JsonbTypeHandler.class)
    private String optionsSnapshot;

    @Version
    private Integer version;
}
