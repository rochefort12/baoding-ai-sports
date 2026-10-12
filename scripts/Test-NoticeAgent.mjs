// Exercise actual uploaded notices with an ordinary organizer and the configured model.
// Checkpoints never silently retry failed model rounds or recreate previously uploaded tasks.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {context,api,request,readSql} from './lib/BusinessRegression.mjs';
const root='docs/04-verification/notice-fixtures-20261012';
const manifest=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'),'utf8'));
const receiptPath=path.join(context.out,'notice-agent-receipt.json');
const proof=fs.existsSync(receiptPath)?JSON.parse(fs.readFileSync(receiptPath,'utf8')):{at:new Date().toISOString(),scope:'Actual isolated organizer material upload, configured DeepSeek model and persisted multi-turn dialogue; synthetic business, official notice-body derivatives only',database:context.database,runtime:JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8')).jarSHA256,manifestSha256:sha(fs.readFileSync(path.join(root,'manifest.json'))),cases:{},checks:[],passed:false};
assert.equal(proof.database,context.database);
assert.equal(proof.manifestSha256,sha(fs.readFileSync(path.join(root,'manifest.json'))));
const selected=process.argv.slice(2).filter(x=>!x.startsWith('--'));
const files=manifest.files.filter(f=>f.goal&&(!selected.length||selected.includes(f.id)));
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
function sha(b){return crypto.createHash('sha256').update(b).digest('hex');}
function save(){const temp=receiptPath+'.tmp';fs.writeFileSync(temp,JSON.stringify(proof,null,2));fs.renameSync(temp,receiptPath);}
function check(name,passed,details={}){proof.checks.push({name,passed:Boolean(passed),...details});save();console.log((passed?'PASS ':'FAIL ')+name);}
const last=run=>run.messages.filter(m=>m.role==='assistant').at(-1)?.content||'';
function snapshot(run,elapsed){return {id:run.id,status:run.status,stopReason:run.stopReason,elapsedSeconds:Math.round(elapsed/100)/10,tokensUsed:run.tokens_used??run.tokensUsed,messages:run.messages.map(m=>({id:m.id,role:m.role,content:m.content,blocks:m.blocks})),steps:run.steps.map(s=>({kind:s.kind,name:s.name,status:s.status,summary:s.summary}))};}
async function settled(id){const start=Date.now(),end=start+310000;while(Date.now()<end){const run=await api(context.organizer,'/sports/agents/runs/'+id);if(!['running','waiting_children'].includes(run.status)&&Number(readSql(`SELECT tokens_reserved FROM asp_agent_run WHERE id=${id};`))===0)return snapshot(run,Date.now()-start);await sleep(1700);}throw Error('Notice run did not settle within 310 seconds');}
async function upload(c){
 const entry=proof.cases[c.id]??={at:new Date().toISOString()};save();
 if(!entry.runId){
  assert.ok(!entry.uploadSubmitted,'Upload outcome unknown; inspect real run history before recovery');
  const list=c.id==='conflict'?[c,manifest.files.find(f=>f.id==='conflict-supplement')]:[c],form=new FormData();
  for(const f of list){const bytes=fs.readFileSync(path.join(root,f.name));assert.equal(sha(bytes),f.sha256);form.append('files',new Blob([bytes]),f.name);}
  form.append('goal',c.goal);form.append('consent','true');form.append('context','{}');entry.uploadSubmitted=true;entry.inputFiles=list.map(f=>({name:f.name,sha256:f.sha256,synthetic:f.synthetic,sourceUrl:f.sourceUrl,coverage:f.coverage}));save();
  const r=await fetch(context.backend+'/sports/agents/runs/materials',{method:'POST',headers:{clientid:context.clientId,Authorization:'Bearer '+context.organizer.token},body:form,signal:AbortSignal.timeout(120000)}),v=await r.json();entry.uploadHttp=r.status;entry.uploadCode=v.code;save();assert.equal(v.code,200,'Material upload rejected: '+v.code);assert.match(String(v.data.runId),/^\d+$/);entry.runId=String(v.data.runId);save();
 }
 if(!entry.initial){entry.initial=await settled(entry.runId);save();}
 return entry;
}
const counts=()=>JSON.parse(readSql("SELECT json_build_object('events',(SELECT count(*) FROM asp_event),'units',(SELECT count(*) FROM asp_competition_unit),'registrations',(SELECT count(*) FROM asp_registration),'receipts',(SELECT count(*) FROM asp_action_execution))::text;"));
proof.before??=counts();save();
for(const c of files){
 try{
  const e=await upload(c),t=last(e.initial).replace(/[*_`]/g,'');
  check(c.id+' initial real model completes without a failed state',e.initial.status==='waiting_input',{runId:e.runId,status:e.initial.status,stopReason:e.initial.stopReason,elapsedSeconds:e.initial.elapsedSeconds});
  check(c.id+' persists visible source hash and bounded coverage',e.inputFiles.every(f=>e.initial.messages.some(m=>String(m.blocks).includes(f.sha256))),{runId:e.runId});
  check(c.id+' has actual model usage',Number(readSql(`SELECT tokens_used FROM asp_agent_run WHERE id=${e.runId};`))>0,{tokens:Number(readSql(`SELECT tokens_used FROM asp_agent_run WHERE id=${e.runId};`))});
  check(c.id+' preserves requested notice facts',c.expect.every(value=>t.includes(value)),{expected:c.expect,replySha256:sha(t)});
  if(c.id==='charged')check('charged retains per-order fee and double seats',/每[单队组]|整[队组]|一[单队组]/.test(t)&&/混.{0,25}双|混双/.test(t)&&t.includes('60')&&t.includes('2'));
  if(c.id==='free')check('free does not demand payment evidence or actual funds confirmation',/(免费|0元)/.test(t)&&/(无需|不需要|不索取|不要求|无需提交).{0,14}(审核|付款|支付|收款)/.test(t));
  if(c.id==='missing')check('missing asks for absent date venue and cost instead of filling them',/(时间|日期)/.test(t)&&/(场地|地点)/.test(t)&&/(费用|收费|免费)/.test(t)&&/(补充|确认|待|请)/.test(t));
  if(c.id==='conflict')check('conflict returns both candidates pending human choice',t.includes('20')&&t.includes('16')&&/(确认|冲突|决定|分歧|未确定)/.test(t));
  if(c.id.startsWith('official-'))check(c.id+' preserves history and explicitly lacks original attachment authority',t.includes(c.id==='official-hlj'?'2025年10月3日至5日':'2026年8月1日至2日')&&/(附件|摘录|不含|未取得)/.test(t)&&/(不能|不可|不可以|不足|不适合|无法)/.test(t));
  if(c.followup&&e.initial.status==='waiting_input'){
   if(!e.continuation){assert.ok(!e.followupSubmitted,'Continuation outcome unknown; inspect original task');e.followupSubmitted=true;save();await api(context.organizer,'/sports/agents/runs/'+e.runId+'/answer','POST',{message:c.followup});e.continuation=await settled(e.runId);save();}
   const next=last(e.continuation).replace(/[*_`]/g,'');
   check(c.id+' continues the original task and retains both user turns',e.continuation.id===e.initial.id&&e.continuation.messages.filter(m=>m.role==='user').length===e.initial.messages.filter(m=>m.role==='user').length+1&&e.continuation.status==='waiting_input',{runId:e.runId,elapsedSeconds:e.continuation.elapsedSeconds});
   check(c.id+' merges the human decision with original project seats',e.continuation.status==='waiting_input'&&e.continuation.messages.filter(m=>m.role==='assistant').length>e.initial.messages.filter(m=>m.role==='assistant').length&&(c.id==='missing'?next.includes('26')&&next.includes('80')&&next.includes('10')&&next.includes('2'):next.includes('28')&&next.includes('70')&&next.includes('16')&&next.includes('2')),{replySha256:sha(next)});
  }
  if(!e.isolationChecked){const denied=await request(context.people[5],'/sports/agents/runs/'+e.runId);e.isolationChecked=true;check(c.id+' another ordinary account cannot read private materials or dialogue',denied.code!==200);}
 }catch(error){proof.cases[c.id].failures??=[];proof.cases[c.id].failures.push({at:new Date().toISOString(),reason:String(error.message).slice(0,350)});save();console.log('ERROR '+c.id+' preserved in evidence');}
}
proof.after=counts();check('notice analysis creates no event unit registration or action receipt',JSON.stringify(proof.before)===JSON.stringify(proof.after),{before:proof.before,after:proof.after});
proof.passed=proof.checks.every(c=>c.passed)&&Object.values(proof.cases).every(c=>!c.failures?.length);proof.finishedAt=new Date().toISOString();save();console.log('Evidence: '+receiptPath);if(!proof.passed)process.exitCode=1;
