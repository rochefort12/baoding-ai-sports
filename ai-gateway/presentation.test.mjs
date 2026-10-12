import test from 'node:test';import assert from 'node:assert/strict';import {runAgent} from './agent.mjs';
test('empty JSON presentation retries once without replaying successful tools',async()=>{
 const playbook={sourceHash:'hash',toolCatalog:{entries:[{name:'sports_playbook'},{name:'sports_capabilities'},{name:'sports_execute'}]}};let modelCalls=0,writes=0;
 const fetchImpl=async(url,options)=>{const input=JSON.parse(options.body);if(url.includes('/mcp')){let result={};if(input.method==='tools/list')result={tools:playbook.toolCatalog.entries.map(t=>({name:t.name,inputSchema:{type:'object'}}))};if(input.method==='tools/call'){if(input.params.name==='sports_playbook')result=playbook;else if(input.params.name==='sports_capabilities')result=[];else{writes++;result={receiptId:'39',status:'succeeded'};}}return {ok:true,text:async()=>JSON.stringify({id:input.id,result})};}
 modelCalls++;if(modelCalls>2){assert.equal(input.tools,undefined);assert.equal(input.tool_choice,undefined);assert.equal(input.response_format.type,'json_object');}
 const message=modelCalls===1?{tool_calls:[{id:'one',function:{name:'sports_execute',arguments:'{"code":"test","inputJson":"{}","requestKey":"same"}'}}]}:modelCalls===2?{content:'真实回执39已返回'}:modelCalls===3?{content:''}:{content:'{"reply":"真实回执39已返回。","blocks":[]}'};
 return {ok:true,json:async()=>({usage:{total_tokens:100},choices:[{message}]})};};
 const out=await runAgent({env:{DEEPSEEK_API_KEY:'test'},fetchImpl,body:{runId:'1',backendPort:8082,model:'deepseek-flash',runToken:'test',playbook,messages:[]}});assert.equal(out.ok,true);assert.equal(out.tokens,400);assert.equal(modelCalls,4);assert.equal(writes,1);
});
