// Re-evaluate overly literal historical-date assertions and resume the original failed task after the gateway fix.
import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';import crypto from 'node:crypto';
import {context,api,readSql,createEvidence} from './lib/BusinessRegression.mjs';
const proof=createEvidence('notice-recovery');
const initial=JSON.parse(fs.readFileSync(path.join(context.out,'notice-agent-initial.json'),'utf8'));
proof.evidence.originalReceiptSha256=crypto.createHash('sha256').update(fs.readFileSync(path.join(context.out,'notice-agent-initial.json'))).digest('hex');
proof.evidence.gatewaySha256=crypto.createHash('sha256').update(fs.readFileSync('ai-gateway/agent.mjs')).digest('hex');
const final=run=>run.messages.filter(m=>m.role==='assistant').at(-1)?.content||'';
try{
 for(const code of ['official-yantian','official-hlj']){
  const entry=initial.cases[code],text=final(entry.initial);
  proof.check(code+' original reply preserves historical year and refuses unsupported current event',entry.initial.status==='waiting_input'&&text.includes(code==='official-hlj'?'2025年10月3日至5日':'2026年8月1日至2日')&&/(不能|无法)/.test(text)&&/(摘录|附件)/.test(text),{runId:entry.runId,boundary:'Rechecks already saved actual answer; no repeat model call. Prior fixed-word assertion failures remain.'});
 }
 const entry=initial.cases.conflict,id=entry.runId;assert.match(id,/^\d+$/);
 const before=await api(context.organizer,'/sports/agents/runs/'+id),assistantBefore=before.messages.filter(m=>m.role==='assistant').length;
 assert.equal(before.status,'failed');assert.equal(before.stopReason,'BUDGET_LIMIT');
 proof.evidence.objects.runId=id;proof.evidence.priorFailure={status:before.status,reason:before.stopReason,assistantBefore};proof.save();
 await api(context.organizer,'/sports/agents/runs/'+id+'/answer','POST',{message:'继续我刚才在原任务做出的人工决定：采用补充通知，2026年12月28日09:00至17:00、混合双打每单70元、限16单、每单2人；原通知27日/50元/20单作废，其他内容保持。只整合材料给我待核对方案，不需要保存草稿或委派，不创建不发布。'});
 let run;const end=Date.now()+310000,start=Date.now();
 do{run=await api(context.organizer,'/sports/agents/runs/'+id);if(!['running','waiting_children'].includes(run.status)&&readSql(`SELECT tokens_reserved FROM asp_agent_run WHERE id=${id};`)==='0')break;await new Promise(r=>setTimeout(r,1700));}while(Date.now()<end);
 proof.evidence.current={id:run.id,status:run.status,stopReason:run.stopReason,elapsedSeconds:Math.round((Date.now()-start)/100)/10,messages:run.messages.map(m=>({id:m.id,role:m.role,content:m.content,blocks:m.blocks})),steps:run.steps.map(s=>({kind:s.kind,name:s.name,status:s.status,summary:s.summary}))};proof.save();
 const reply=final(run);
 proof.check('failed conflict resumes the same run with a new visible answer',run.id===id&&run.status==='waiting_input'&&run.messages.filter(m=>m.role==='assistant').length===assistantBefore+1,{runId:id,status:run.status,stopReason:run.stopReason});
 proof.check('recovered answer retains human selected date per-order price quota and pair size',/2026年12月28日/.test(reply)&&/70/.test(reply)&&/16/.test(reply)&&/2人/.test(reply));
 proof.check('recovery creates no business write receipt',readSql(`SELECT count(*) FROM asp_action_execution WHERE run_id=${id};`)==='0');
 proof.finish();
}catch(e){proof.evidence.failure=String(e.message).slice(0,350);proof.save();process.exitCode=1;console.log('Notice recovery failed; evidence retained');}
