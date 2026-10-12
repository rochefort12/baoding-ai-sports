// Two-stage isolated verification. Root alone publishes the five read-only Agent candidates between stages.
// Never changes business facts, creates fixtures, opens channels, or logs credentials/model replies.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';import {spawnSync} from 'node:child_process';
const mode=process.argv.includes('--model')?'model':'direct',root=process.cwd(),out=path.join(root,'.local/agent-playbook-20261011');fs.mkdirSync(out,{recursive:true});
const runtime=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8')),session=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json','utf8'));
assert.ok(runtime.port===8082&&/^aisports_verify_phase1_[a-f0-9]{32}$/.test(runtime.database)&&session.database===runtime.database,'Isolated runtime required');
for(const value of [session.organizationId,session.sportId,...session.people.map(p=>p.id)])assert.match(String(value),/^[1-9][0-9]{0,18}$/,'Trusted isolated fixture identifiers required');
const selected=['event.mine','growth.card','registration.mine','room.query','type.catalog'],base='http://127.0.0.1:8082',clientId='e5cd7e4891bf95d1d19206ce24a7b32e',attempt=crypto.randomUUID(),currentChecks=[];
const checkpoint=path.join(out,'read-facts-progress.json'),progress=fs.existsSync(checkpoint)?JSON.parse(fs.readFileSync(checkpoint,'utf8')):{database:runtime.database,checks:[],runs:{}};assert.equal(progress.database,runtime.database);
const sha=value=>crypto.createHash('sha256').update(typeof value==='string'?value:JSON.stringify(value)).digest('hex');
function durable(){const tmp=checkpoint+'.'+attempt+'.tmp',fd=fs.openSync(tmp,'wx');try{fs.writeFileSync(fd,JSON.stringify(progress,null,2));fs.fsyncSync(fd);}finally{fs.closeSync(fd);}fs.renameSync(tmp,checkpoint);}
function check(name,condition,extra={}){assert.ok(condition,name);const row={name,status:'PASS',at:new Date().toISOString(),...extra},previous=progress.checks.findIndex(c=>c.name===name);if(previous<0)progress.checks.push(row);else progress.checks[previous]=row;currentChecks.push(row);durable();console.log('PASS '+name);}
function sql(statement){const result=spawnSync('C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin/psql.exe',['-X','-h','127.0.0.1','-p',process.env.POSTGRES_PORT||'25432','-U',process.env.POSTGRES_USER,'-d',runtime.database,'-At','-v','ON_ERROR_STOP=1'],{input:statement,encoding:'utf8',env:{...process.env,PGPASSWORD:process.env.POSTGRES_PASSWORD}});assert.equal(result.status,0,'Read-only database verification unavailable');return result.stdout.trim();}
function facts(){return sql(['event','team_room','registration','fee_obligation','payment','refund','result_version','growth_record','title_equipment'].map(t=>`SELECT '${t}='||count(*)||':'||COALESCE(sum(version),0) FROM asp_${t};`).join('\n'));}
async function api(actor,route,method='GET',input){const result=await fetch(base+route,{method,headers:{clientid:clientId,Authorization:'Bearer '+actor.token,...(input?{'Content-Type':'application/json'}:{})},...(input?{body:JSON.stringify(input)}:{})});return {http:result.status,...await result.json()};}
async function ok(actor,route,method='GET',input){const result=await api(actor,route,method,input);assert.equal(result.code,200,'Authorized read or task rejected');return result.data;}
const blocks=m=>typeof m.blocks==='string'?JSON.parse(m.blocks):m.blocks||[];
async function settled(actor,id){const deadline=Date.now()+310000;while(Date.now()<deadline){const result=await ok(actor,`/sports/agents/runs/${id}`);if(result.status!=='running'){if(result.status==='failed')throw Object.assign(Error('Model task failed'),{safeCode:result.stopReason||'UNKNOWN'});return result;}await new Promise(resolve=>setTimeout(resolve,1000));}throw Object.assign(Error('Model task timed out'),{safeCode:'MODEL_TIMEOUT'});}
async function run(slot,actor,goal,context={}){
  if(!progress.runs[slot]){const result=await ok(actor,'/sports/agents/runs','POST',{goal,context,consent:true});progress.runs[slot]={id:result.runId};durable();}
  else if(slot==='personal-facts'&&process.argv.includes('--continue-facts')&&!progress.runs[slot].factReadContinuation){
    const prior=await ok(actor,`/sports/agents/runs/${progress.runs[slot].id}`);
    assert.equal(prior.status,'waiting_input','Continue the retained incomplete read task only after it has settled');
    // Append once to the original task. A crash after sending cannot silently create or retry another task.
    progress.runs[slot].factReadContinuation={at:new Date().toISOString(),status:'prepared',priorReplySha256:sha(final(prior)?.content||''),priorUserMessages:prior.messages.filter(m=>m.role==='user').length};durable();
    await ok(actor,`/sports/agents/runs/${prior.id}/answer`,'POST',{message:goal});progress.runs[slot].factReadContinuation.status='submitted';durable();
  }
  else if(process.argv.includes('--resume-failed')){const prior=await ok(actor,`/sports/agents/runs/${progress.runs[slot].id}`);if(prior.status==='failed'){progress.runs[slot].failures??=[];progress.runs[slot].failures.push({at:new Date().toISOString(),stopReason:prior.stopReason||'UNKNOWN'});durable();await ok(actor,`/sports/agents/runs/${prior.id}/answer`,'POST',{message:'请继续原目标，重新核对当前权限并实际读取事实。本轮只查，不执行任何业务写动作。'});}}
  return settled(actor,progress.runs[slot].id);
}
const final=r=>r.messages.filter(m=>m.role==='assistant').at(-1),success=(r,code)=>r.steps.some(s=>s.kind==='tool'&&s.name===code&&s.status==='succeeded');
try{
  const catalog=await ok(session.admin,'/sports/platform/management'),definitions=selected.map(code=>catalog.definitions.find(d=>d.definition.code===code));
  check('five selected actions are registered server-authorized read-only contracts',definitions.every(d=>d?.definition.agent&&!d.definition.mutation&&!d.definition.confirmation&&d.definition.writes.length===0),{definitionHashes:Object.fromEntries(definitions.map(d=>[d.definition.code,d.definitionHash]))});
  const eventDefinition=definitions.find(d=>d.definition.code==='event.mine').definition;
  check('event mine schema admits optional string event id and rejects undeclared actor fields',eventDefinition.inputSchema.properties.eventId?.type==='string'&&!eventDefinition.inputSchema.required.includes('eventId')&&eventDefinition.inputSchema.additionalProperties===false);
  const startFacts=facts(),startChannels=catalog.activations.filter(a=>a.channel==='agent'&&a.enabled).map(a=>a.code).sort();
  const participant=session.people[0],outsider=session.people[5];
  const [types,growth,rooms,registrations,events]=await Promise.all([ok(participant,'/sports/types'),ok(participant,'/sports/growth/card?sportId='+session.sportId),ok(participant,'/sports/rooms'),ok(participant,'/sports/c/registrations'),ok(session.organizer,'/sports/b/events')]);
  check('ordinary participant reads real types personal growth rooms and own registrations',types.sports.some(s=>s.id===String(session.sportId))&&types.types.length>0&&Number.isFinite(Number(growth.points))&&Array.isArray(rooms.rooms)&&Array.isArray(registrations));
  check('ordinary organizer reads only its existing events',events.length>0&&events.every(e=>sql(`SELECT organization_id FROM asp_event WHERE id=${e.id};`)===String(session.organizationId)));
  const roomId=sql(`SELECT r.id FROM asp_team_room r JOIN asp_team_room_member m ON m.room_id=r.id AND m.status='active' WHERE m.account_id=${participant.id} AND NOT EXISTS(SELECT 1 FROM asp_team_room_member other WHERE other.room_id=r.id AND other.account_id=${outsider.id} AND other.status='active') ORDER BY r.id LIMIT 1;`);
  assert.match(roomId,/^[1-9][0-9]*$/,'Existing room isolation fixture required');
  check('current member reads a room while another participant is denied',(await ok(participant,'/sports/rooms/'+roomId)).members.length>0&&(await api(outsider,'/sports/rooms/'+roomId)).code===403);
  const teamId=sql(`SELECT t.id FROM asp_team t JOIN asp_team_member m ON m.team_id=t.id AND m.status='active' JOIN asp_account a ON a.person_id=m.person_id WHERE a.id=${participant.id} AND NOT EXISTS(SELECT 1 FROM asp_team_member other JOIN asp_account oa ON oa.person_id=other.person_id WHERE other.team_id=t.id AND oa.id=${outsider.id} AND other.status='active') ORDER BY t.id LIMIT 1;`);
  assert.match(teamId,/^[1-9][0-9]*$/,'Existing team isolation fixture required');
  check('active team member reads team growth while a nonmember is denied',(await ok(participant,`/sports/growth/card?sportId=${session.sportId}&teamId=${teamId}`)).ownerId===teamId&&(await api(outsider,`/sports/growth/card?sportId=${session.sportId}&teamId=${teamId}`)).code===403);
  const foreignEvent=sql(`SELECT id FROM asp_event WHERE organization_id<>${session.organizationId} ORDER BY id LIMIT 1;`);
  let foreignResult;
  if(/^[1-9][0-9]*$/.test(foreignEvent))foreignResult=await api(session.organizer,'/sports/b/events/'+foreignEvent);
  else{
    const secondaryAccount=sql(`SELECT p.account_id FROM asp_account_tenant_principal p WHERE p.status='active' AND p.tenant_id<>(SELECT tenant_id FROM asp_organization WHERE id=${session.organizationId}) ORDER BY p.id LIMIT 1;`),secondary=session.people.find(p=>p.id===secondaryAccount);
    assert.ok(secondary,'Existing secondary ordinary organizer fixture required');
    const entered=await ok(secondary,'/auth/organization/enter','POST',{}),secondOrganizer={token:entered.accessToken||entered.access_token};assert.ok(secondOrganizer.token,'Existing ordinary organization session required');
    foreignResult=await api(secondOrganizer,'/sports/b/events/'+events[0].id);
  }
  check('ordinary organizer cannot read another organization event',foreignResult.code!==200&&foreignResult.code!==401);
  const noActorOverride=await api(participant,'/sports/platform/actions/registration.mine/preview','POST',{accountId:outsider.id});
  check('registered registration query rejects browser supplied other-account override',noActorOverride.code===400);
  if(mode==='model'){
    assert.ok(progress.directEvidenceHash,'Run direct stage and root candidate release before real model stage');
    check('only the five candidate read actions are Agent enabled',JSON.stringify(startChannels)===JSON.stringify(selected));
    const personRun=await run('personal-facts',participant,`请使用已登记的查询能力实际读取我的羽毛球成长、报名和参赛房间。sportId=${session.sportId}。本轮只查，不做报名、匹配或佩戴。答复请明确写「成长积分：数字」「报名单数：数字」「集结房间数：数字」，再给一个具体下一步；不要猜数字。`),personReply=final(personRun).content.replace(/[*_`]/g,'');
    const lockedScope=JSON.parse(sql(`SELECT scope->'capabilities' FROM asp_agent_run WHERE id=${personRun.id};`)),liveDefinitions=await ok(participant,'/sports/platform/capabilities');
    check('retained personal task scope and current registry admit its requested read actions',['growth.card','registration.mine','room.query'].every(code=>lockedScope.includes(code)&&liveDefinitions.some(d=>d.code===code&&d.agent&&!d.mutation)),{runId:personRun.id,scopeCapabilities:lockedScope.sort(),roleEligibleReadCodes:liveDefinitions.filter(d=>d.agent&&!d.mutation).map(d=>d.code).sort(),effectiveCandidateReadCodes:startChannels.filter(code=>lockedScope.includes(code)&&liveDefinitions.some(d=>d.code===code)).sort(),scopeBoundary:'Snapshot is narrowed again by actual agent grants, current channels and fresh role permissions; definition.agent alone is not an enabled channel'});
    check('real model reads three personal facts through current MCP actions',['growth.card','registration.mine','room.query'].every(code=>success(personRun,code)),{runId:personRun.id,replySha256:sha(personReply)});
    check('real model reports exact participant growth registration and room counts',new RegExp(`成长积分[：:]\\s*${growth.points}(?!\\d)`).test(personReply)&&new RegExp(`报名单数[：:]\\s*${registrations.length}(?!\\d)`).test(personReply)&&new RegExp(`集结房间数[：:]\\s*${rooms.rooms.length}(?!\\d)`).test(personReply));
    const typeRun=await run('type-facts',participant,'请实际查询开放运动和比赛类型目录，说明羽毛球双打准确需要几个人。只读查询，不建房不报名。答复带「双打人数：数字」。');
    check('real model reads competition type catalog and reports correct pair size',success(typeRun,'type.catalog')&&/双打人数[：:]\s*2(?!\d)/.test(final(typeRun).content),{runId:typeRun.id,replySha256:sha(final(typeRun).content)});
    const eventId=String(events[0].id),eventDetail=await ok(session.organizer,'/sports/b/events/'+eventId);
    const orgRun=await run('organizer-facts',session.organizer,`请实际查询我管理的赛事详情，eventId=${eventId}。只读，不修改不发布。答复请复述当前赛事名称和一项真实发布检查，再告诉我下一步需要核对什么。`,{eventId});
    check('real model reads organization-owned event and reports its actual name',success(orgRun,'event.mine')&&final(orgRun).content.includes(eventDetail.name),{runId:orgRun.id,replySha256:sha(final(orgRun).content)});
    check('read tasks do not forge confirmation or mutation receipts',[personRun,typeRun,orgRun].every(r=>r.status==='waiting_input'&&r.messages.every(m=>blocks(m).every(b=>!['confirmation','receipt'].includes(b.kind)))));
    const denied=await api(outsider,`/sports/agents/runs/${personRun.id}`);check('another participant cannot read the real fact task history',denied.code!==200);
  }
  const after=await ok(session.admin,'/sports/platform/management');check(mode+' stage leaves business versions and Agent channels unchanged',facts()===startFacts&&JSON.stringify(after.activations.filter(a=>a.channel==='agent'&&a.enabled).map(a=>a.code).sort())===JSON.stringify(startChannels));
  const evidence={at:new Date().toISOString(),mode,scope:'Real isolated services and synthetic business data; no fact writes or capability activation',checks:currentChecks,priorDirectEvidence:mode==='model'?{file:progress.directEvidenceFile,sha256:progress.directEvidenceHash}:undefined,failures:0,unobserved:mode==='direct'?['Agent channels and real model business reads are not proved by direct HTTP checks']:['No business mutation, confirmation, real bank or formal competition acceptance inferred']};
  const target=path.join(out,`read-facts-${mode}-${attempt}.json`);fs.writeFileSync(target,JSON.stringify(evidence,null,2));if(mode==='direct'){progress.directEvidenceHash=sha(fs.readFileSync(target,'utf8'));progress.directEvidenceFile=path.relative(root,target).replaceAll('\\','/');durable();}console.log('Verified '+mode+' stage; sanitized immutable read evidence appended.');
}catch(error){fs.writeFileSync(path.join(out,`read-facts-failed-${mode}-${attempt}.json`),JSON.stringify({at:new Date().toISOString(),mode,checks:progress.checks,failure:{name:error.name,safeCode:error.safeCode||'VERIFICATION_FAILED',assertion:error.name==='AssertionError'?error.message:'Operation failed; original task IDs retained'}},null,2));console.error('Read verification failed; sanitized evidence and original task IDs retained.');process.exitCode=1;}
