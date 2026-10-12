import test from 'node:test';
import assert from 'node:assert/strict';
import {runAgent} from './agent.mjs';

for(const confirmation of [false,true])test(`material menu exposes confirmation only when an eligible action exists: ${confirmation}`,async()=>{
 const playbook={sourceHash:'a'.repeat(64),toolCatalog:{entries:['sports_playbook','sports_capabilities','sports_propose'].map(name=>({name}))}};
 const calls=[];
 const fetchImpl=async(url,options)=>{
  const input=JSON.parse(options.body);
  if(url.includes('/mcp')){
   let result={};
   if(input.method==='tools/list')result={tools:playbook.toolCatalog.entries.map(entry=>({...entry,inputSchema:{type:'object'}}))};
   if(input.method==='tools/call'){
    calls.push(input.params.name);
    result={content:[{type:'text',text:JSON.stringify(input.params.name==='sports_playbook'?playbook:[{code:'fixture.action',confirmation,inputSchema:{type:'object'}}])}]};
   }
   return {ok:true,text:async()=>JSON.stringify({id:input.id,result})};
  }
  assert.equal(input.tools.some(tool=>tool.function.name==='sports_propose'),confirmation);
  assert.match(input.messages[0].content,/不把整理文字误认为需要持久化业务草稿/);
  assert.match(input.messages[0].content,/补充材料不会扩大用户先前授权/);
  return {ok:true,json:async()=>({usage:{total_tokens:20},choices:[{message:{content:JSON.stringify({reply:'已按人工决定整理，尚未创建赛事。',blocks:[]})}}]})};
 };
 const out=await runAgent({env:{DEEPSEEK_API_KEY:'test-fixture'},fetchImpl,body:{model:'deepseek-flash',runId:'1',backendPort:8082,instruction:'',currentTime:'2026-10-12',playbook,messages:[{role:'user',content:'只比较材料，不创建赛事'}]}});
 assert.equal(out.ok,true);assert.equal(out.tokens,20);assert.deepEqual(calls,['sports_playbook','sports_capabilities']);
});
