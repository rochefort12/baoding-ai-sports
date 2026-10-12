package org.dromara.sports.api;

/**
 * 从资料创建赛事时，模型和 MCP 只能使用的读取与校验能力。
 * 不提供发布、取消、退款、确认到账或直接写表。
 */
public interface AiSceneToolApi {

    String describeEventCreateConstraints();

    String readEventCreateDocument(long taskId, int fileIndex, String blockLabel);

    String validateEventCreateProposal(String proposalJson);
}
