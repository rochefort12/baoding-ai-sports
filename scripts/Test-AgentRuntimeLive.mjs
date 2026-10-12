// Real local model, MCP, database and ordinary-role acceptance. All business writes are new prefixed test objects.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {context,api,request,action,readSql,iso,createEvidence} from './lib/BusinessRegression.mjs';
const proof=createEvidence('agent-runtime');
const {evidence,check,save}=proof;
const runtime=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8'));
assert.equal(runtime.database,context.database);assert.equal(crypto.createHash('sha256').update(fs.readFileSync(runtime.jarPath)).digest('hex'),runtime.jarSHA256);
evidence.runtimeJarSha256=runtime.jarSHA256;
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const knownRun=value=>{assert.match(String(value),/^\d+$/);return String(value);};
const detail=(actor,id)=>api(actor,'/sports/agents/runs/'+knownRun(id));
const blocks=run=>run.messages.flatMap(message=>JSON.parse(message.blocks||'[]').map(block=>({messageId:message.id,...block})));
async function settled(actor,id,expected){
 const deadline=Date.now()+310000;
 while(Date.now()<deadline){const run=await detail(actor,id);if(run.status==='failed')throw Error('Real model run failed: '+run.stopReason);if(!['running','waiting_children'].includes(run.status)&&Number(readSql(`SELECT tokens_reserved FROM asp_agent_run WHERE id=${knownRun(id)};`))===0){if(expected)assert.equal(run.status,expected);return run;}await sleep(1500);}
 throw Error('Real task did not settle within its configured window.');
}
async function start(actor,goal,agentCode='platform'){const value=await api(actor,'/sports/agents/runs','POST',{goal,agentCode,consent:true});const id=knownRun(value.runId);(evidence.objects.runs??=[]).push(id);save();return id;}
let catalog,original;
const release=async(enabled)=>api(context.admin,'/sports/platform/management/release','POST',{code:'unit.create',channel:'agent',enabled,definitionHash:catalog.definitions.find(d=>d.definition.code==='unit.create').definitionHash,evidenceHash:crypto.createHash('sha256').update(JSON.stringify(evidence.checks)).digest('hex')});
try {
 catalog=await api(context.admin,'/sports/platform/management');context.definitions=catalog.definitions;
 original=catalog.activations.find(a=>a.code==='unit.create'&&a.channel==='agent');
 const transport=async(size)=>{const response=await fetch('http://127.0.0.1:8091/internal/agent',{method:'POST',signal:AbortSignal.timeout(10000),headers:{'Content-Type':'application/json','X-Ai-Internal-Token':process.env.AI_INTERNAL_TOKEN},body:JSON.stringify({model:'unapproved-test-model',runId:'1',backendPort:8082,padding:'x'.repeat(size)})});return {status:response.status,body:await response.json()};};
 const within=await transport(3*1024*1024),over=await transport(9*1024*1024);
 check('Agent transport accepts over 2MiB and explicitly rejects over 8MiB without a model call',within.status===422&&within.body.errorCode==='MODEL_FAILED'&&over.status===413&&over.body.errorCode==='MATERIAL_LIMIT');
 const runtimeTools=new Set(['sports_playbook','sports_capabilities','sports_preview','sports_execute','sports_propose','sports_delegate','sports_children','sports_recovery']);
 check('new tasks use locked revision 3 and eight controlled tools',catalog.agents.every(a=>Number(a.revision)===3&&JSON.parse(a.tool_catalog).entries.filter(t=>runtimeTools.has(t.name)).length===8));
 const actor=context.people[1];
 const baseline=await api(actor,'/sports/platform/actions/room.query/preview','POST',{});
 const parent=await start(actor,'请现在使用 sports_delegate 委派 teammates 找队友助手，只查询我本人当前集结情况（room.query，输入{}），子任务必须统计 rooms 数组中的房间数量和 offers 数组中的撮合方案数量；你随后读取实际子任务结果，以“房间数：数字，方案数：数字”向我汇总。请只委派一次，不创建、不修改任何业务对象；子任务还在办理时不要把创建任务当作完成。');
 const returned=await settled(actor,parent,'waiting_input');
 const children=JSON.parse(readSql(`SELECT COALESCE(json_agg(json_build_object('id',id::text,'status',status,'tokens',tokens_used)),'[]') FROM asp_agent_run WHERE parent_run_id=${parent};`));
 check('real model creates an authorized child and returns its result to parent',children.length===1&&children[0].status==='waiting_input'&&returned.steps.some(s=>s.kind==='delegate')&&returned.messages.filter(m=>m.role==='assistant').length>=2,{parent,child:children[0]?.id});
 const child=knownRun(children[0].id);
 const consumed=readSql(`SELECT (p.scope->'childVersions'->>c.id::text)::bigint=c.version FROM asp_agent_run p JOIN asp_agent_run c ON c.parent_run_id=p.id WHERE p.id=${parent} AND c.id=${child};`);
 const finalText=returned.messages.filter(m=>m.role==='assistant').at(-1).content;
 const rooms=Array.isArray(baseline.rooms)?baseline.rooms.length:null,offers=Array.isArray(baseline.offers)?baseline.offers.length:null;
 check('parent consumes the actual terminal child version before finishing',consumed==='t',{parent,child});
 check('parent summary contains actual queried counts',rooms!==null&&offers!==null&&new RegExp('房间.{0,6}'+rooms).test(finalText)&&new RegExp('方案.{0,6}'+offers).test(finalText),{roomCount:rooms,offerCount:offers,replyHash:crypto.createHash('sha256').update(finalText).digest('hex')});
 const childFacts=Number(readSql(`SELECT count(*) FROM asp_agent_step WHERE run_id=${child} AND kind='tool' AND name='room.query' AND status='succeeded';`));
 check('child actually reads current ordinary-user facts over MCP',childFacts>0,{baselineHash:crypto.createHash('sha256').update(JSON.stringify(baseline)).digest('hex')});
 const storedTools=JSON.parse(readSql(`SELECT COALESCE(json_agg(summary),'[]') FROM asp_agent_step WHERE run_id=${child} AND name='room.query' AND status='succeeded';`));
 check('read result and input survive a later model round',storedTools.some(s=>s.input&&s.result));
 const forbidden=await request(context.people[2],'/sports/agents/runs/'+parent);
 check('another ordinary participant cannot read a task or its derived facts',forbidden.code!==200);
 await api(actor,'/sports/agents/runs/'+child+'/stop','POST');
 check('stopping a child leaves its parent unchanged',readSql(`SELECT status FROM asp_agent_run WHERE id=${child};`)==='stopped'&&readSql(`SELECT status FROM asp_agent_run WHERE id=${parent};`)==='waiting_input');
 // Establish a current real UI transaction before temporarily opening this exact Agent write in the isolated DB.
 const types=await api(context.organizer,'/sports/platform/actions/type.catalog/preview','POST',{});
 const typeRows=Array.isArray(types)?types:(types.types??types.items??[]);const type=typeRows.find(t=>t.entry_type==='single'||t.entryType==='single')??typeRows[0];assert.ok(type?.id,'An active manual competition type is required');
 const draft={name:context.prefix+'-Agent运行核验',location:'本机隔离验证场地',projectName:'羽毛球',feeDescription:'免费项目',registrationOpensAt:iso(1),registrationClosesAt:iso(24),startsAt:iso(48),endsAt:iso(50),registrationReview:'manual',rulesText:'仅用于隔离环境核验，不发布真实赛事。',noticeText:'虚构测试对象',declarationText:'本人核对后办理',declarationAckRequired:true};
 const created=await action(context.organizer,'event.create',{draftJson:JSON.stringify(draft)});const eventId=knownRun(created.value.eventId??created.value.id);evidence.objects.eventId=eventId;save();
 const baseInput={eventId,competitionTypeId:String(type.id),name:context.prefix+'-UI基线项目',limitCount:'8',charged:false};
 const ui=await action(context.organizer,'unit.create',baseInput);
 check('current ordinary organizer UI write and multi-table state commit',ui.receipt.status==='succeeded'&&Number(readSql(`SELECT count(*) FROM asp_competition_unit WHERE event_id=${eventId};`))===1,{receiptId:ui.receipt.receiptId});
 await release(true);
 const input={...baseInput,name:context.prefix+'-Agent确认项目'};
 const writeRun=await start(context.organizer,'请按以下已完整核对的字段，用 unit.create 在这个已有赛事创建一个免费项目。必须使用 sports_propose 生成真实确认卡后停下，等我本人确认。不要改变赛事、费用或其他对象。输入：'+JSON.stringify(input));
 const pending=await settled(context.organizer,writeRun,'waiting_confirmation');const card=blocks(pending).find(b=>b.kind==='confirmation'&&b.code==='unit.create');assert.ok(card,'A server-authored human confirmation card is required');
 check('model prepares a real confirmation card without doing the write',Number(readSql(`SELECT count(*) FROM asp_competition_unit WHERE event_id=${eventId};`))===1,{runId:writeRun,messageId:card.messageId});
 await release(false);
 const denied=await request(context.organizer,`/sports/agents/runs/${writeRun}/confirm`,'POST',{messageId:card.messageId,accepted:true});
 check('revoked Agent channel rejects an old card despite working human UI permission',denied.code!==200&&Number(readSql(`SELECT count(*) FROM asp_competition_unit WHERE event_id=${eventId};`))===1,{businessCode:denied.code});
 await release(true);
 await api(context.organizer,`/sports/agents/runs/${writeRun}/confirm`,'POST',{messageId:card.messageId,accepted:true});
 await settled(context.organizer,writeRun,'waiting_input');
 const receipts=JSON.parse(readSql(`SELECT COALESCE(json_agg(json_build_object('id',id::text,'channel',channel,'runId',run_id::text,'requestKey',request_key)),'[]') FROM asp_action_execution WHERE run_id=${writeRun} AND action_code='unit.create' AND status='succeeded';`));
 check('confirmed execution retains Agent channel, run scope and one durable receipt',receipts.length===1&&receipts[0].channel==='agent'&&receipts[0].runId===writeRun&&Number(readSql(`SELECT count(*) FROM asp_competition_unit WHERE event_id=${eventId};`))===2,{receipt:receipts[0]});
 check('human consent is linked to the actual Agent run',Number(readSql(`SELECT count(*) FROM asp_action_confirmation WHERE run_id=${writeRun} AND action_code='unit.create' AND status='consumed';`))===1);
 const repeat=await request(context.organizer,`/sports/agents/runs/${writeRun}/confirm`,'POST',{messageId:card.messageId,accepted:true});
 check('repeated confirmation does not repeat the business write',repeat.code!==200&&Number(readSql(`SELECT count(*) FROM asp_competition_unit WHERE event_id=${eventId};`))===2);
 await api(context.organizer,`/sports/agents/runs/${writeRun}/answer`,'POST',{message:'请从 sports_recovery 恢复刚才的真实办理回执，只告诉我项目编号与下一步。不要再次创建，也不要准备新的确认卡。'});
 const resumed=await settled(context.organizer,writeRun,'waiting_input');
 check('a later model round recovers the saved receipt without repeating the write',resumed.messages.some(m=>m.role==='assistant'&&JSON.parse(m.blocks||'[]').some(b=>b.kind==='receipt'))&&Number(readSql(`SELECT count(*) FROM asp_competition_unit WHERE event_id=${eventId};`))===2&&Number(readSql(`SELECT count(*) FROM asp_agent_step WHERE run_id=${writeRun} AND kind='model' AND status='succeeded';`))>=3);
 check('root model usage is accumulated and settled after both parent and child rounds',Number(readSql(`SELECT SUM(tokens_used) FROM asp_agent_run WHERE root_run_id=${parent};`))>0&&Number(readSql(`SELECT SUM(tokens_reserved) FROM asp_agent_run WHERE root_run_id IN(${parent},${writeRun});`))===0);
 evidence.boundary='Real local DeepSeek/MCP/HTTP/PG acceptance with synthetic new objects; no real funds, official results, government approvals or main-channel write release.';
} catch(error){evidence.failure=error.message;save();throw error;}
finally {if(catalog){await release(Boolean(original?.enabled));evidence.agentWriteRestoredToOriginal=Boolean(original?.enabled);save();}}
proof.finish();
