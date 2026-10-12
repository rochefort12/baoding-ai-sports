package org.dromara.sports.mcp;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.dromara.sports.platform.core.*;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.web.bind.annotation.RestController;

/** No HTTP business route or raw SQL tool. The run filter supplies its restricted identity. */
@RestController
@RequiredArgsConstructor
public class RegisteredAgentTools {
    private final ActionDispatcher actions;
    private final AgentRunAccess runs;
    private final ObjectMapper json;
    private void guard(String name){if(TrustedRunContext.current()==null)throw BusinessSupport.fail("仅限已授权的助手运行",403);runs.tool(name,"started");}
    @FunctionalInterface private interface Call<T> {T execute() throws Exception;}
    private <T> T invoke(String name,Call<T> call) throws Exception {
        guard(name);
        try {T result=call.execute();runs.toolCompleted(name,"succeeded");return result;}
        catch(Exception failure){runs.toolCompleted(name,"failed");throw failure;}
    }
    private JsonNode business(String code,JsonNode input,String requestKey,Call<JsonNode> call)throws Exception {
        if(TrustedRunContext.current()==null)throw BusinessSupport.fail("仅限已授权的助手运行",403);
        runs.tool(code,"started",input,requestKey);
        try {var result=call.execute();runs.toolCompleted(code,"succeeded",input,result,requestKey);return result;}
        catch(Exception failure){runs.toolCompleted(code,"failed",input,json.createObjectNode().put("error","BUSINESS_REJECTED"),requestKey);throw failure;}
    }
    @Tool(name="sports_capabilities",description="查询本人当前可用能力、参数、前置与是否需要本人确认。不可选择其他身份。")
    public Object capabilities()throws Exception{return invoke("capabilities",actions::available);}
    @Tool(name="sports_playbook",description="读取本次锁定的技能、业务流程、当前角色已登记并开放的能力及人工入口。引导不授予执行权限。")
    public JsonNode playbook()throws Exception{return invoke("playbook",runs::playbook);}
    @Tool(name="sports_preview",description="核对办理对象及缺项。inputJson必须是能力所要求的JSON对象，不可猜测编号。")
    public JsonNode preview(String code,String inputJson)throws Exception{var input=json.readTree(inputJson);return business(code,input,null,()->actions.preview(code,input));}
    @Tool(name="sports_execute",description="执行不需要本人确认的已开放能力。需要确认的能力请使用sports_propose。requestKey在重试时保持相同。")
    public JsonNode execute(String code,String inputJson,String requestKey)throws Exception{var input=json.readTree(inputJson);var stable=runs.requestKey(code,input,requestKey);return business(code,input,stable,()->actions.execute(code,input,stable,null));}
    @Tool(name="sports_propose",description="准备本人确认卡；不会替本人发布、报名或审核。用户需核对具体内容并点击确认。")
    public JsonNode propose(String code,String inputJson)throws Exception{return invoke(code,()->runs.propose(code,json.readTree(inputJson)));}
    @Tool(name="sports_delegate",description="必要时委派已授权的职能助手，权限与对象范围不能扩大。简单任务直接办理。")
    public JsonNode delegate(String agentCode,String goal)throws Exception{return invoke("delegate",()->runs.delegate(agentCode,goal));}
    @Tool(name="sports_children",description="读取本次任务的直接委派结果、失败或待本人确认状态。最多等待10秒，不能读取别人的任务。")
    public JsonNode children(int waitSeconds)throws Exception{return invoke("children",()->runs.children(waitSeconds));}
    @Tool(name="sports_recovery",description="恢复本次任务当前仍授权的真实办理回执和原请求编号。成功动作不重放；旧事实需核对当前版本。")
    public JsonNode recovery()throws Exception{return invoke("recovery",runs::recovery);}
}
