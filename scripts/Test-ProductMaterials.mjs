// Real isolated HTTP/storage/model checks. Tokens and document bytes stay in memory; output contains only bounded evidence.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';
const root=process.cwd(),out=path.join(root,'.local/product-release-20261011');
const runtime=JSON.parse(fs.readFileSync(path.join(root,'.local/phase1-implementation/verification-runtime.json'),'utf8'));
const session=JSON.parse(fs.readFileSync(path.join(root,'.local/phase1-implementation/verification-session.json'),'utf8'));
const fixture=JSON.parse(fs.readFileSync(path.join(root,'.local/demo-20261011/scenario.json'),'utf8'));
if(runtime.port!==8082||!/^aisports_verify_phase1_[a-f0-9]{32}$/.test(runtime.database)||session.database!==runtime.database)throw Error('Expected isolated AISports runtime');
const base='http://127.0.0.1:8082',clientId='e5cd7e4891bf95d1d19206ce24a7b32e',eventId=fixture.eventId;
const file=path.join(out,'materials-progress.json'),runId=crypto.randomUUID();fs.mkdirSync(out,{recursive:true});
const progress=fs.existsSync(file)?JSON.parse(fs.readFileSync(file,'utf8')):{database:runtime.database,eventId,steps:{},checks:[],unobserved:[]};
if(progress.database!==runtime.database||progress.eventId!==eventId)throw Error('Recovery state does not match isolated event');
function save(){const tmp=file+'.'+runId+'.tmp',fd=fs.openSync(tmp,'wx');try{fs.writeFileSync(fd,JSON.stringify(progress,null,2));fs.fsyncSync(fd);}finally{fs.closeSync(fd);}fs.renameSync(tmp,file);}
function pass(name,condition=true,details={}){assert.ok(condition,name);const index=progress.checks.findIndex(c=>c.name===name),prior=index<0?null:progress.checks[index],at=new Date().toISOString(),check={name,status:'PASS',at,...(prior?{firstObservedAt:prior.firstObservedAt||prior.at}:{}),...details};if(index<0)progress.checks.push(check);else progress.checks[index]=check;save();console.log('PASS '+name);}
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const api=async(actor,route,method='GET',input)=>{const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),90000);try{
const r=await fetch(base+route,{method,signal:controller.signal,headers:{clientid:clientId,...(actor?.token?{Authorization:'Bearer '+actor.token}:{}),...(input instanceof FormData?{}:input!==undefined?{'Content-Type':'application/json'}:{})},...(input!==undefined?{body:input instanceof FormData?input:JSON.stringify(input)}:{})});
const value=await r.json();return {http:r.status,...value};}finally{clearTimeout(timer);}};
async function ok(actor,route,method='GET',input){const r=await api(actor,route,method,input);if(r.code!==200)throw Error(`Operation rejected: ${route}, code ${r.code}`);return r.data;}
const current=()=>ok(session.organizer,`/sports/b/events/${eventId}/materials`);
async function action(code,input,key){return ok(session.organizer,`/sports/platform/actions/${code}/execute`,'POST',{input,requestKey:key});}
async function once(slot,code,input){progress.steps[slot]??={requestKey:crypto.randomUUID(),input};save();const step=progress.steps[slot];const result=await action(code,step.input,step.requestKey);step.complete=true;step.receiptId=result.receiptId;step.resultVersion=result.result?.version;save();return result;}
async function upload(slot,purpose){if(progress.steps[slot]?.fileId)return progress.steps[slot].fileId;
const art=fs.readFileSync(path.join(root,'plus-ui/public/images/sports/badminton-hero-v1.webp')),data=new FormData();data.append('file',new Blob([art],{type:'image/webp'}),'isolated-cover.webp');
const r=await ok(session.organizer,`/sports/b/media?purpose=${purpose}`,'POST',data);progress.steps[slot]={fileId:String(r.fileId),sha256:sha(art)};save();return String(r.fileId);}
function queryRead(sql){const exe='C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin/psql.exe';const r=spawnSync(exe,['-X','-h','127.0.0.1','-p',process.env.POSTGRES_PORT||'25432','-U',process.env.POSTGRES_USER,'-d',runtime.database,'-At','-v','ON_ERROR_STOP=1'],{input:sql,encoding:'utf8',env:{...process.env,PGPASSWORD:process.env.POSTGRES_PASSWORD}});if(r.status!==0)throw Error('Isolated read-only fixture lookup failed');return r.stdout.trim();}
async function checkLengthBoundary(){
  let workspace=await current();const kind='script';
  // Only hashes/versions enter the checkpoint. Original model text is recovered from its private stored history.
  const original=workspace.materials[kind];assert.ok(original?.content,'An existing script is required for restoration');
  progress.steps.length_boundary??={requestKey:crypto.randomUUID(),originalVersion:original.version,originalContentSha256:sha(original.content),originalTitleSha256:sha(original.title),expectedVersion:original.version,factDigest:workspace.factDigest};save();
  const step=progress.steps.length_boundary;
  let legal='# 文稿长度边界验收附录（隔离测试）\n\n这份附录仅临时核验保存上限，不是赛事现场脚本。验证后恢复原有文稿为新的人工版本；不得发布或按此办理。\n\n';
  for(let i=1;legal.length<10000;i++)legal+=`\n岗位记录 ${String(i).padStart(4,'0')}：责任人【待确认】；交接时间【待确认】；核对事项包括场地、报到、器材和异常登记；处理状态仅作为隔离测试字段。`;
  legal=legal.slice(0,9999)+'核';assert.equal(legal.length,10000);
  const before=workspace.materials[kind].version;
  const refused=await api(session.organizer,'/sports/platform/actions/event.material.save/execute','POST',{input:{eventId,kind,expectedVersion:before,factDigest:workspace.factDigest,title:'上限之外的临时文稿',content:legal+'核'},requestKey:crypto.randomUUID()});
  pass('10001-character material is rejected without changing its stored version',refused.code!==200&&/内容过长|正文最多10000/.test(String(refused.msg||''))&&(await current()).materials[kind].version===before);
  if(!step.complete){const r=await action('event.material.save',{eventId,kind,expectedVersion:step.expectedVersion,factDigest:step.factDigest,title:'文稿长度边界验收附录（隔离测试）',content:legal},step.requestKey);step.complete=true;step.receiptId=r.receiptId;step.resultVersion=r.result.version;save();}
  workspace=await current();const editions=[workspace.materials[kind],...workspace.materials[kind].history];
  const boundary=editions.find(d=>d.version===step.resultVersion);
  pass('10000-character manual material actually saves at the supported boundary',boundary?.source==='manual'&&boundary.content.length===10000&&sha(boundary.content)===sha(legal));
  if(!progress.steps.length_restore?.complete){
    const prior=editions.find(d=>d.version===step.originalVersion&&sha(d.content)===step.originalContentSha256&&sha(d.title)===step.originalTitleSha256);
    assert.ok(prior,'Original text remains in private history');
    if(!progress.steps.length_restore)assert.equal(workspace.materials[kind].version,step.resultVersion,'Do not overwrite an intervening user edit while restoring');
    progress.steps.length_restore??={requestKey:crypto.randomUUID(),expectedVersion:workspace.materials[kind].version,factDigest:workspace.factDigest};save();
    const restore=progress.steps.length_restore;
    const r=await action('event.material.save',{eventId,kind,expectedVersion:restore.expectedVersion,factDigest:restore.factDigest,title:prior.title,content:prior.content},restore.requestKey);
    restore.complete=true;restore.receiptId=r.receiptId;restore.resultVersion=r.result.version;save();
  }
  const restored=(await current()).materials[kind];
  pass('the original script returns as a new manual version after the length test',restored.version===progress.steps.length_restore.resultVersion&&restored.source==='manual'&&sha(restored.content)===step.originalContentSha256&&sha(restored.title)===step.originalTitleSha256);
}
try{
  const proofFiles=['java-verified-tests-rerun.log','ai-node-verified-suite.log',...fs.readdirSync(out).filter(n=>/^migration-.*\.json$/.test(n))];
  const hashes=proofFiles.map(name=>({name,sha256:sha(fs.readFileSync(path.join(out,name)))}));
  const candidate={at:new Date().toISOString(),scope:'Candidate UI activation on isolated 8082 only; not main-environment activation or final business acceptance',database:runtime.database,jarSha256:sha(fs.readFileSync(path.join(root,'backend/ruoyi-admin/target/ruoyi-admin.jar'))),evidence:hashes};
  const candidateName=`materials-candidate-${runId}.json`;const candidateBytes=JSON.stringify(candidate,null,2);fs.writeFileSync(path.join(out,candidateName),candidateBytes);const evidenceHash=sha(candidateBytes);
  const catalog=await ok(session.admin,'/sports/platform/management');
  for(const code of ['event.material.save','event.material.generate','event.cover.save']){
    const row=catalog.definitions.find(r=>r.definition.code===code);assert.ok(row&&row.definition.agent===false,'New capability keeps agent channel unavailable');
    await ok(session.admin,'/sports/platform/management/release','POST',{code,channel:'ui',enabled:true,definitionHash:row.definitionHash,evidenceHash});
  }
  const activated=await ok(session.admin,'/sports/platform/management');
  pass('the three current UI candidates are activated only in isolated 8082',['event.material.save','event.material.generate','event.cover.save'].every(code=>activated.activations.some(a=>a.code===code&&a.channel==='ui'&&a.enabled&&a.source_hash===catalog.definitions.find(d=>d.definition.code===code).definitionHash)),{candidateSha256:evidenceHash,candidateFile:candidateName});
  let workspace=await current();pass('ordinary organizer reads private draft workspace',workspace.eventId===String(eventId)&&workspace.aiAvailable===true);
  const deniedRead=await api(session.people[1],`/sports/b/events/${eventId}/materials`);pass('participant cannot read organizer working documents',deniedRead.code!==200);
  const deniedWrite=await api(session.people[1],'/sports/platform/actions/event.material.save/execute','POST',{input:{eventId,kind:'plan',expectedVersion:0,factDigest:workspace.factDigest,title:'拒绝测试',content:'不应保存'},requestKey:crypto.randomUUID()});pass('participant cannot execute organizer material writes',deniedWrite.code!==200);
  if(!progress.steps.manual?.complete){const v=workspace.materials.plan?.version||0;await once('manual','event.material.save',{eventId,kind:'plan',expectedVersion:v,factDigest:workspace.factDigest,title:'界面验收手稿（模拟）',content:'本稿为隔离赛事的人工编辑测试，不表示真实赛事已执行。\n\n- 负责人确认场地和裁判安排\n- 参赛者本人确认资料及声明\n- 真实收退款与短信仍须另行验收'});}
  workspace=await current();const handwritten=[workspace.materials.plan,...(workspace.materials.plan?.history||[])].find(d=>d.version===progress.steps.manual.resultVersion);pass('manual working document saves with actual manual origin',handwritten?.source==='manual'&&sha(handwritten.content)===sha(progress.steps.manual.input.content));
  const stale=await api(session.organizer,'/sports/platform/actions/event.material.save/execute','POST',{input:{eventId,kind:'plan',expectedVersion:Math.max(0,workspace.materials.plan.version-1),factDigest:workspace.factDigest,title:'过期改稿',content:'不应覆盖'},requestKey:crypto.randomUUID()});pass('stale document version is rejected without overwriting',stale.code!==200&&(await current()).materials.plan.version===workspace.materials.plan.version);
  const wrongDigest=await api(session.organizer,'/sports/platform/actions/event.material.save/execute','POST',{input:{eventId,kind:'plan',expectedVersion:workspace.materials.plan.version,factDigest:'0'.repeat(64),title:'旧事实改稿',content:'不应覆盖'},requestKey:crypto.randomUUID()});pass('stale event facts are rejected without overwriting',wrongDigest.code!==200&&(await current()).materials.plan.version===workspace.materials.plan.version);
  const refusedConsent=await api(session.organizer,'/sports/platform/actions/event.material.generate/execute','POST',{input:{eventId,kind:'plan',expectedVersion:workspace.materials.plan.version,factDigest:workspace.factDigest,consent:'unconfirmed'},requestKey:crypto.randomUUID()});pass('AI generation requires explicit material-use consent',refusedConsent.code!==200);
  for(const kind of ['plan','script','announcement','promotion']){
    workspace=await current();const slot='generate_'+kind;
    if(!progress.steps[slot]?.complete){await once(slot,'event.material.generate',{eventId,kind,expectedVersion:workspace.materials[kind]?.version||0,factDigest:workspace.factDigest,consent:'confirmed',note:'只按当前隔离模拟赛事真实字段写待核对草稿，缺少执行人员、报到安排与安全资源请明确标待确认；不要编造官方背书、已收款或已发布公告。'});}
    workspace=await current();const latest=workspace.materials[kind],step=progress.steps[slot],doc=[latest,...latest.history].find(d=>d.version===step.resultVersion);pass(`actual DeepSeek ${kind} draft persists with AI origin`,doc?.source==='ai'&&doc.content.length>100&&doc.version>0,{kind,version:doc.version,contentSha256:sha(doc.content),contentLength:doc.content.length});
    const before=latest.version,replayed=await action('event.material.generate',step.input,step.requestKey);pass(`same ${kind} request replays its receipt without new generation`,replayed.replayed===true&&replayed.receiptId===step.receiptId&&(await current()).materials[kind].version===before);
  }
  workspace=await current();pass('regenerated plan preserves prior handwritten version',workspace.materials.plan.history.some(d=>d.source==='manual'&&d.content.includes('人工编辑测试')));
  const imageId=await upload('banner_upload','event-banner');pass('cover source actually uploads to private image storage',/^\d+$/.test(imageId));
  workspace=await current();if(!progress.steps.cover?.complete)await once('cover','event.cover.save',{eventId,expectedVersion:workspace.eventVersion,fileId:imageId});
  // A later UI exercise can legitimately select a newer cover. Verify today's binding through a fresh versioned action.
  for(const [slot,step] of Object.entries(progress.steps).filter(([name,value])=>name.startsWith('cover_recheck_')&&!value.complete))await once(slot,'event.cover.save',step.input);
  const beforeCoverCheck=await ok(session.organizer,`/sports/b/events/${eventId}`);
  if(beforeCoverCheck.bannerFileId!==imageId){workspace=await current();await once('cover_recheck_'+workspace.eventVersion,'event.cover.save',{eventId,expectedVersion:workspace.eventVersion,fileId:imageId});}
  const card=await ok(session.organizer,`/sports/b/events/${eventId}`);pass('published event changes presentation cover without unpublishing',card.bannerFileId===imageId&&card.publicationStatus==='published');
  const publicImage=await fetch(`${base}/sports/public/events/${eventId}/media/banner`);const bytes=Buffer.from(await publicImage.arrayBuffer());pass('anonymous public cover returns the exact uploaded image bytes',publicImage.ok&&sha(bytes)===progress.steps.banner_upload.sha256,{fileId:imageId,imageSha256:sha(bytes)});
  const wrongFile=await upload('rules_upload','event-rules');workspace=await current();const purpose=await api(session.organizer,'/sports/platform/actions/event.cover.save/execute','POST',{input:{eventId,expectedVersion:workspace.eventVersion,fileId:wrongFile},requestKey:crypto.randomUUID()});pass('a rules image cannot be bound as a public event cover',purpose.code!==200&&(await ok(session.organizer,`/sports/b/events/${eventId}`)).bannerFileId===imageId);
  const staleCover=await api(session.organizer,'/sports/platform/actions/event.cover.save/execute','POST',{input:{eventId,expectedVersion:Math.max(0,workspace.eventVersion-1),fileId:imageId},requestKey:crypto.randomUUID()});pass('stale cover version is rejected',staleCover.code!==200);
  const promotionBefore=await ok(session.organizer,`/sports/b/events/${eventId}/promotion`);
  pass('missing image provider is reported independently of the available text model',promotionBefore.imageEnabled===false);
  const imageAttempt=await api(session.organizer,`/sports/b/events/${eventId}/promotion/visual`,'POST',{consent:true,style:'community',audience:'隔离测试',keywords:'封面服务不可用保护验证，不应生成实际图片'});
  const promotionAfter=await ok(session.organizer,`/sports/b/events/${eventId}/promotion`);
  pass('unavailable image generation preserves the existing chosen cover and visual',imageAttempt.code!==200&&promotionAfter.visualFileId===promotionBefore.visualFileId&&(await ok(session.organizer,`/sports/b/events/${eventId}`)).bannerFileId===imageId);
  const foreign=queryRead(`SELECT e.id::text FROM asp_event e WHERE e.organization_id<>${String(session.organizationId)} ORDER BY e.id LIMIT 1;`);
  if(foreign){const denied=await api(session.organizer,`/sports/b/events/${foreign}/materials`);pass('organizer cannot read another organizations event materials',denied.code!==200);}else{if(!progress.unobserved.includes('No second-organization event exists for live cross-organization document read; rejection covered by unit guard test only'))progress.unobserved.push('No second-organization event exists for live cross-organization document read; rejection covered by unit guard test only');save();}
  const endCatalog=await ok(session.admin,'/sports/platform/management');const newCodes=new Set(['event.material.save','event.material.generate','event.cover.save']);pass('the new material and cover agent channels remain closed',!endCatalog.activations.some(a=>newCodes.has(a.code)&&a.channel==='agent'&&a.enabled));
  await checkLengthBoundary();
  const report={runId,at:new Date().toISOString(),scope:'Real isolated PostgreSQL/Redis/MinIO/Java/DeepSeek HTTP; synthetic event and people. No main capability activation, real payment, SMS or image-provider success.',database:runtime.database,eventId,checks:progress.checks,unobserved:progress.unobserved,failures:0};fs.writeFileSync(path.join(out,`materials-http-${runId}.json`),JSON.stringify(report,null,2));console.log(`Verified ${progress.checks.length} isolated material/media checks. Report saved privately.`);
}catch(error){const report={runId,at:new Date().toISOString(),scope:'Isolated candidate verification',database:runtime.database,eventId,checks:progress.checks,failure:{name:error instanceof assert.AssertionError?error.message:'Operation failed; current checkpoint is retained',kind:error.name,code:error.code||''}};fs.writeFileSync(path.join(out,`materials-http-failed-${runId}.json`),JSON.stringify(report,null,2));console.error('Material/media verification failed; checkpoint and sanitized evidence retained.');process.exitCode=1;}
