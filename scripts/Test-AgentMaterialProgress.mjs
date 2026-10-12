import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {context,api,request,readSql} from './lib/BusinessRegression.mjs';

const out=path.resolve('.local/agent-material-progress-20261012','live-'+crypto.randomUUID());fs.mkdirSync(out,{recursive:true});
const state=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json','utf8').replace(/^\uFEFF/,''));
const expected=JSON.parse(fs.readFileSync('.local/local-trial-20261012/source-expectations.private.json','utf8'));
const runtime=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8').replace(/^\uFEFF/,''));
const report={at:new Date().toISOString(),scope:'Existing isolated database, ordinary organizer/participant, original user Word, actual provider and authenticated SSE. No event creation, publishing, funds or results.',database:context.database,jarSha256:runtime.jarSHA256,checks:[],objects:{},streams:[],passed:false};
function save(){fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify(report,null,2));}
function check(name,condition,details={}){report.checks.push({name,passed:!!condition,...details});save();assert.ok(condition,name);console.log('PASS '+name);}
const norm=value=>String(value).replace(/\s+/g,'');
async function login(phone){const value=await api(null,'/auth/login','POST',{username:phone,password:state.password,grantType:'platform',tenantId:'900001',clientId:context.clientId});return {token:value.access_token};}
const headers=actor=>({clientid:context.clientId,Authorization:'Bearer '+actor.token});
function observe(actor,route){
  const controller=new AbortController(),snapshots=[];let failure;
  const done=(async()=>{try{const response=await fetch(context.backend+route,{headers:{...headers(actor),Accept:'text/event-stream'},signal:controller.signal});assert.ok(response.ok&&response.headers.get('content-type')?.includes('text/event-stream'),'Authenticated streaming response');const reader=response.body.getReader(),decoder=new TextDecoder();let buffer='';while(true){const read=await reader.read();if(read.done)break;buffer+=decoder.decode(read.value,{stream:true});let end;while((end=buffer.indexOf('\n\n'))>=0){const block=buffer.slice(0,end);buffer=buffer.slice(end+2);if(block.startsWith('event: unavailable'))throw Error('Stream authorization lost');if(!block.startsWith('event: snapshot'))continue;const value=JSON.parse(block.split('\n').find(l=>l.startsWith('data:')).slice(5));snapshots.push(value);report.streams.push({route,at:new Date().toISOString(),status:value.status,stepCount:value.steps?.length||0,messageCount:value.messages?.length||0});save();if(!['running','waiting_children','UPLOADED','PROCESSING'].includes(value.status))return;}}}catch(error){if(!controller.signal.aborted)failure=String(error.message).slice(0,160);}})();
  return {snapshots,done,stop:()=>controller.abort(),get failure(){return failure;}};
}
async function waitUntil(predicate,milliseconds=240000){const deadline=Date.now()+milliseconds;while(!predicate()){if(Date.now()>deadline)throw Error('Expected saved progress did not arrive within the bounded wait');await new Promise(r=>setTimeout(r,400));}}
async function taskReady(id,trace){await waitUntil(()=>trace.failure||trace.snapshots.some(s=>!['UPLOADED','PROCESSING'].includes(s.status)));assert.ok(!trace.failure,trace.failure);await trace.done;return api(context.organizer,`/sports/b/ai/tasks/${id}`);}
async function runReady(id,trace){await waitUntil(()=>trace.failure||trace.snapshots.some(s=>!['running','waiting_children'].includes(s.status)));assert.ok(!trace.failure,trace.failure);await trace.done;return api(context.organizer,`/sports/agents/runs/${id}`);}
try{
  check('Runtime is the same isolated database and current immutable package',runtime.database===context.database&&runtime.port===8082);
  const actor=await login(state.people[0].phone);context.organizer={token:(await api(actor,'/auth/organization/enter','POST',{})).access_token};
  assert.ok(context.organizer.token,'Ordinary organization session');
  const other=await login(state.people[1].phone);
  const baseline=readSql("SELECT json_build_object('events',(SELECT count(*) FROM asp_event),'commands',(SELECT count(*) FROM asp_execution_command))::text;");
  const sourceId='2109468287808057346';const before=await api(context.organizer,`/sports/b/ai/tasks/${sourceId}`);fs.writeFileSync(path.join(out,'source-before.private.json'),JSON.stringify(before));
  const needsRecovery=before.status==='FAILED'||process.env.AISPORTS_RECHECK_SOURCE==='1';check('Original task and failure history remain available',(['FAILED','PENDING_CONFIRMATION'].includes(before.status))&&!before.resultObjectId,{previousErrorCode:before.errorCode,alreadyRecovered:!needsRecovery});
  report.objects.sourceTask=sourceId;
  if(needsRecovery){const retry=await api(context.organizer,`/sports/b/ai/tasks/${sourceId}/retry`,'POST',{});check('Retry returns original task promptly in PROCESSING state',retry.id===sourceId&&retry.status==='PROCESSING');}
  const denied=await fetch(context.backend+`/sports/b/ai/tasks/${sourceId}/stream`,{headers:headers(other)});check('Other ordinary participant cannot read organizer task stream',!denied.headers.get('content-type')?.includes('text/event-stream'));
  let trace=observe(context.organizer,`/sports/b/ai/tasks/${sourceId}/stream`);await waitUntil(()=>trace.failure||trace.snapshots.length>=(needsRecovery?2:1),25000);check(needsRecovery?'Real stage changes arrive before the source task finishes':'Accepted source task is read without replaying recognition',!trace.failure&&(needsRecovery?trace.snapshots.some(s=>s.status==='PROCESSING'):trace.snapshots[0].status==='PENDING_CONFIRMATION'));trace.stop();await trace.done;
  trace=observe(context.organizer,`/sports/b/ai/tasks/${sourceId}/stream`);const source=await taskReady(sourceId,trace);fs.writeFileSync(path.join(out,'source-after.private.json'),JSON.stringify(source));
  check('Original task recovery survives SSE disconnect and reaches candidate review',source.status==='PENDING_CONFIRMATION'&&!source.resultObjectId,{actualStatus:source.status,errorCode:source.errorCode});
  const extraction=JSON.parse(source.extraction),proposal=JSON.parse(source.proposal);check('Legacy extraction and all original visual references remain available',extraction.version===3&&!!extraction.previousExtraction&&extraction.files[0].visuals.length===13);
  const declaration=proposal.event?.declarationText?.value||'';check('All twelve original declaration clauses are retained in order',norm(declaration).includes(norm(expected.declarationClauses.join('\n'))),{expectedClauses:12,expectedCharacters:expected.declarationClauses.join('').length,actualCharacters:declaration.length});
  const sourceSteps=trace.snapshots.at(-1).steps,visualSteps=sourceSteps.filter(s=>s.name==='material_image'&&s.status==='succeeded');check('Every one of thirteen embedded references has an explicit recognition status',new Set(visualSteps.map(s=>JSON.parse(s.summary).index)).size===13);
  const unitNames=proposal.units.map(u=>u.name?.value||'');fs.writeFileSync(path.join(out,'candidate-matrix.private.json'),JSON.stringify({unitNames,event:proposal.event},null,2));
  check('Short form fields contain actual values rather than whole source paragraphs',proposal.event?.projectName?.value==='羽毛球'&&String(proposal.event?.contactName?.value||'').length<=80&&String(proposal.event?.contactMethod?.value||'').length<=200);
  check('Adult matrix and youth matrix are recovered from embedded tables',unitNames.some(n=>/18.{0,5}34|A组/.test(n)&&/男.*单/.test(n))&&unitNames.some(n=>/45.{0,5}54|C组/.test(n)&&/混.*双/.test(n))&&unitNames.some(n=>/U9|9岁以下/i.test(n)&&/女.*单/.test(n))&&unitNames.some(n=>/U15|13.{0,5}14/i.test(n)&&/男.*双/.test(n)),{projectCount:unitNames.length});
  const maleSingle=/男(?:子)?.*单|男单/,femaleSingle=/女(?:子)?.*单|女单/,maleDouble=/男(?:子)?.*双|男双/,femaleDouble=/女(?:子)?.*双|女双/,mixed=/混(?:合)?.*双|混双/;
  const matrix=[[/A组|18.{0,5}34/,[maleSingle,femaleSingle,maleDouble,femaleDouble,mixed]],[/B组|35.{0,5}44/,[maleSingle,femaleSingle,maleDouble,femaleDouble,mixed]],[/C组|45.{0,5}54/,[maleDouble,femaleDouble,mixed]],[/D组|55/,[maleDouble,femaleDouble,mixed]],[/U9|9岁以下/i,[maleSingle,femaleSingle]],[/U11/i,[maleSingle,femaleSingle,maleDouble,femaleDouble]],[/U13/i,[maleSingle,femaleSingle,maleDouble,femaleDouble]],[/U15/i,[maleSingle,femaleSingle,maleDouble,femaleDouble]],[/青年|16.{0,5}17/,[maleSingle,femaleSingle,maleDouble,femaleDouble]]];
  check('All 34 independently inspected adult/youth matrix cells are retained',matrix.every(([group,forms])=>forms.every(form=>unitNames.some(name=>group.test(name)&&form.test(name)))),{expectedAdult:16,expectedYouth:18});
  const raw=fs.readFileSync('.local/local-trial-20261012/task-2109468287808057346-source.docx');check('Original source bytes are unchanged',crypto.createHash('sha256').update(raw).digest('hex')==='0b2140be2f395b2f1c7659c28ee77022ce02637b5cfda50d2530d28cacd2c646');
  const data=new FormData();data.append('goal','仅整理全部材料，不创建赛事：列出成人和青少年各年龄组实际比赛项目、不同比赛日期、按人/兼项/亲子优惠/CP的收费条件，完整引用12条参赛声明，并指出截止日期、名额及未能识别位置。');data.append('consent','true');data.append('files',new Blob([raw]),'复杂分组规程.docx');
  const uploaded=await fetch(context.backend+'/sports/agents/runs/materials',{method:'POST',headers:headers(context.organizer),body:data});const created=await uploaded.json();assert.equal(created.code,200);const runId=created.data.runId;report.objects.genericRun=runId;save();
  const rejected=await fetch(context.backend+`/sports/agents/runs/${runId}/stream`,{headers:headers(other)});check('Other ordinary participant cannot read generic run stream',!rejected.headers.get('content-type')?.includes('text/event-stream'));
  const runTrace=observe(context.organizer,`/sports/agents/runs/${runId}/stream`);const run=await runReady(runId,runTrace);fs.writeFileSync(path.join(out,'generic-after.private.json'),JSON.stringify(run));
  check('Generic agent completes full-source reading with live progress',run.status==='waiting_input'&&run.steps.filter(s=>s.name==='material_image').length===13,{actualStatus:run.status,stopReason:run.stopReason});
  const reply=run.messages.filter(m=>m.role==='assistant').at(-1)?.content||'';check('Generic reply preserves source pricing conditions and distinct dates',/200/.test(reply)&&/100/.test(reply)&&/160|八折|8折/.test(reply)&&/CP|情侣/.test(reply)&&/11月7|11\/7|11-07|11\.7/.test(reply)&&/11月14|11\/14|11-14|11\.14/.test(reply));
  check('Generic reply includes all twelve declaration clauses',expected.declarationClauses.every(clause=>norm(reply).includes(norm(clause))));
  const cachedCount=run.steps.filter(s=>s.name==='material_image').length;await api(context.organizer,`/sports/agents/runs/${runId}/answer`,'POST',{message:'沿用原材料和已完成的读取结果，只把缺项和下一步列清楚，继续不要创建赛事。'});
  const resumedTrace=observe(context.organizer,`/sports/agents/runs/${runId}/stream`);const resumed=await runReady(runId,resumedTrace);fs.writeFileSync(path.join(out,'generic-resumed.private.json'),JSON.stringify(resumed));
  check('Same generic run resumes without replaying business work',resumed.id===runId&&resumed.status==='waiting_input'&&resumed.steps.filter(s=>s.name==='material_image').length===cachedCount+13);
  const after=readSql("SELECT json_build_object('events',(SELECT count(*) FROM asp_event),'commands',(SELECT count(*) FROM asp_execution_command))::text;");check('Material recovery creates no event or business execution command',after===baseline);
  check('Original failure invocation history remains present',Number(readSql(`SELECT count(*) FROM asp_ai_invocation WHERE task_id=${sourceId} AND error_code='SOURCE_FIELDS_INCOMPLETE' AND attempt_no=1;`))>0);
  report.passed=true;
}catch(error){report.failure=String(error.message).replaceAll(state.password,'[REDACTED]').replace(/Bearer\s+\S+/gi,'Bearer [REDACTED]').slice(0,350);process.exitCode=1;console.log('FAIL '+report.failure);}finally{report.finishedAt=new Date().toISOString();save();console.log('Evidence: '+out);}
