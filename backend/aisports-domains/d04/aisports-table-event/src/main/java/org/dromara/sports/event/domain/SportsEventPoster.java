package org.dromara.sports.event.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.tenant.core.TenantEntity;

import java.io.Serial;

/**
 * 一场赛事的一份宣传材料。来源编号不代表已经发到微信或 QQ。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_event_poster")
public class SportsEventPoster extends TenantEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long eventId;

    private String channelName;

    private String format;

    private String sourceCode;

    private String copyHeadline;

    private String copyInvitation;

    private String copyBody;

    private String factDigest;

    private String linkPath;

    /** 只属于宣传材料，不覆盖赛事公开封面；subject变化后不再采用旧主视觉。 */
    private Long visualFileId;
    private String visualSubjectDigest;
    private String visualRequestDigest;
    private String visualStyle;

    @Version
    private Integer version;
}
