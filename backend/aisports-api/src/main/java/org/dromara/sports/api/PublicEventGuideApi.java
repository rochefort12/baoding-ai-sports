package org.dromara.sports.api;

/**
 * 公开赛事检索。模型和 MCP 只提交条件，分页和排序由实现完成。
 */
public interface PublicEventGuideApi {

    String searchPublic(String text, String project, String phase, boolean includeCancelled, int offset);

    String readPublic(long eventId);
}
