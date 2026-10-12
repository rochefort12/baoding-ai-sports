package org.dromara.sports.event.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.event.ai.SportsEventRunAiTaskService.ConfirmDraft;
import java.util.Objects;

/** Never invent legal text or infer participant acknowledgement from a model. Human confirmation is revision-bound. */
public final class AiDeclarationProposal {
    private AiDeclarationProposal() { }
    public static AiDraftReadiness.Ready readiness(ObjectMapper mapper,String proposal,AiDraftReadiness.Ready ready) {
        try {
            var declaration=mapper.readTree(proposal==null?"{}":proposal).path("event").path("declarationText");
            return readiness(declaration,ready);
        }catch(Exception unreadable){return ready;}
    }
    public static AiDraftReadiness.Ready readiness(com.fasterxml.jackson.databind.JsonNode declaration,AiDraftReadiness.Ready ready) {
            if ("conflict".equals(declaration.path("status").asText())) {
                var issues=new java.util.ArrayList<>(ready.blockingIssues());
                issues.add(new AiDraftReadiness.Issue("DECLARATION_CONFLICT","declarationText","参赛声明有多种写法，请核对原文并明确采用哪一版"));
                return new AiDraftReadiness.Ready(false,java.util.List.copyOf(issues),"请先核对参赛声明冲突，再确认保存。",ready.checkedAt());
            }
            return ready;
    }
    public static void requireMatch(ObjectMapper mapper,String proposal,ConfirmDraft requested,ConfirmDraft candidate,Integer version) {
        try {
            var declaration=mapper.readTree(proposal==null?"{}":proposal).path("event").path("declarationText");
            if ("conflict".equals(declaration.path("status").asText())) throw new ServiceException("参赛声明存在冲突，请先核对原文并明确采用哪一版",409);
            String source=Objects.toString(candidate.declarationText(),"");
            if (!Objects.equals(source,Objects.toString(requested.declarationText(),""))) throw new ServiceException("确认的参赛声明与当前草稿不一致，请先修改草稿后重新确认",409);
            if (source.isBlank()) {
                if (Boolean.TRUE.equals(requested.declarationAckRequired())) throw new ServiceException("没有参赛声明原文，不能开启成员确认；请先补充声明内容",409);
                return;
            }
            if (!"filled".equals(declaration.path("status").asText()) || !declaration.path("sources").isArray() || declaration.path("sources").isEmpty())
                throw new ServiceException("参赛声明缺少可核对来源，请先补充原文",409);
            if (requested.expectedVersion()==null || !Objects.equals(requested.expectedVersion(),version)) throw new ServiceException("草稿已更新，请重新核对参赛声明与确认方式",409);
            if (requested.declarationAckRequired()==null) throw new ServiceException("请明确是否要求每位成员阅读并确认原文参赛声明",409);
        }catch(ServiceException failure){throw failure;}
        catch(Exception failure){throw new ServiceException("参赛声明草稿无法核对，请重新读取",409);}
    }
}
