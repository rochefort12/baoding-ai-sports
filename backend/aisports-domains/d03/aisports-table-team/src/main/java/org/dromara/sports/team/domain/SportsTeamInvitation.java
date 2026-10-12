package org.dromara.sports.team.domain;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;
import lombok.EqualsAndHashCode;
import org.dromara.common.mybatis.core.domain.BaseEntity;

import java.io.Serial;

/**
 * 指定一人的入队邀请。本人接受后才成为成员。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("asp_team_invitation")
public class SportsTeamInvitation extends BaseEntity {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId
    private Long id;

    private Long teamId;

    private Long inviterAccountId;

    /** 分享授权的队长稳定档案，转让或账号停止后不复用旧授权。 */
    private Long inviterPersonId;

    private Long targetPersonId;

    /** direct 为指定本人；share 为队长明确授权的可转发入队链接。 */
    private String invitationKind;

    /** 256 位随机分享凭据，只向当前队长回显；不得写入通知、日志或匿名响应。 */
    private String inviteToken;

    private java.time.OffsetDateTime expiresAt;

    /** 分享接受记录对应的来源；防止已退队或已移除的人重放同一链接。 */
    private Long shareInvitationId;

    private String status;

    @Version
    private Integer version;
}
