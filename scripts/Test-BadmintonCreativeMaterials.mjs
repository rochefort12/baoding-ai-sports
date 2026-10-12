// Real text model and object storage. Synthetic event, no automatic public announcement.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';
import {context as c,key,api,request,action,readSql,createEvidence} from './lib/BusinessRegression.mjs';
const test=createEvidence('badminton-creative');
const canonical=process.argv.includes('--canonical');
const source=JSON.parse(fs.readFileSync(path.join(c.out,canonical?'ai-canonical-entry-state.json':'funds-competition-fixed-state.json'),'utf8'));
const clockRetest=process.argv.includes('--r4');
const event=source.eventId,checkpoint=path.join(c.out,canonical?'canonical-creative-state.json':clockRetest?'creative-r4-state.json':'creative-state.json');
const s=fs.existsSync(checkpoint)?JSON.parse(fs.readFileSync(checkpoint,'utf8')):{runId:c.runId,eventId:event,actions:{},uploads:{}};
if(s.runId!==c.runId||s.eventId!==event)throw Error('Wrong material checkpoint');
const save=()=>fs.writeFileSync(checkpoint,JSON.stringify(s,null,2));
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const current=()=>api(c.organizer,`/sports/b/events/${event}/materials`);
async function mutate(slot,code,input){s.actions[slot]??={input,requestKey:key()};save();const entry=s.actions[slot];const r=await action(c.organizer,code,entry.input,entry.requestKey);entry.receiptId=r.receipt.receiptId;entry.resultVersion=r.value.version;entry.complete=true;save();return r;}
async function upload(slot,purpose){if(s.uploads[slot])return s.uploads[slot];const bytes=fs.readFileSync('plus-ui/public/images/sports/badminton-hero-v1.webp');const data=new FormData();data.append('file',new Blob([bytes],{type:'image/webp'}),'synthetic-badminton.webp');const r=await fetch(c.backend+'/sports/b/media?purpose='+purpose,{method:'POST',signal:AbortSignal.timeout(45000),headers:{clientid:c.clientId,Authorization:'Bearer '+c.organizer.token},body:data});const value=await r.json();if(value.code!==200)throw Error('Synthetic image upload rejected: '+value.code);s.uploads[slot]={fileId:String(value.data.fileId),sha256:hash(bytes)};save();return s.uploads[slot];}
try{
  let view=await current();test.check('ordinary organizer reads versioned factual material workspace',view.eventId===event&&view.aiAvailable&&/^[a-f0-9]{64}$/.test(view.factDigest));
  if(clockRetest){
    const raw=readSql(`SELECT registration_closes_at AT TIME ZONE 'Asia/Shanghai' FROM asp_event WHERE id=${event};`);
    const expected=raw.slice(0,16);
    test.check('material facts use the actual Beijing registration deadline',view.facts.registrationClosesAt===expected&&view.facts.timezone==='Asia/Shanghai',{expected,actual:view.facts.registrationClosesAt});
  }
  test.check('a participant cannot access private organizer working materials',(await request(c.people[5],`/sports/b/events/${event}/materials`)).code!==200);
  const foreign=readSql(`SELECT id FROM asp_event WHERE organization_id<>${c.organizationId} ORDER BY id DESC LIMIT 1;`);
  test.check('another organization event does not expose working drafts',Boolean(foreign)&&(await request(c.organizer,`/sports/b/events/${foreign}/materials`)).code!==200);
  const beforePublication=readSql(`SELECT publication_status||'|'||published_revision FROM asp_event WHERE id=${event};`);
  for(const kind of ['plan','script','announcement','promotion']){
    view=await current();const version=view.materials[kind]?.version||0;
    if(!s.actions[kind]?.complete)await mutate(kind,'event.material.generate',{eventId:event,kind,expectedVersion:version,factDigest:view.factDigest,consent:'confirmed',note:'以当前合成羽毛球赛事事实生成可核对工作草稿。实际人员、安全资源等没有依据的安排标为待确认；不编造官方背书、到账、现场比赛或通知已发送。'});
    const entry=s.actions[kind],now=await current(),doc=[now.materials[kind],...(now.materials[kind]?.history||[])].find(d=>d.version===entry.resultVersion);
    test.check('real DeepSeek '+kind+' persists as a traceable working draft',doc?.source==='ai'&&doc.content.length>100,{contentSha256:hash(doc?.content||''),version:doc?.version});
    const replay=await action(c.organizer,'event.material.generate',entry.input,entry.requestKey);
    test.check('repeating '+kind+' replays its receipt without another generated version',replay.receipt.replayed===true&&replay.receipt.receiptId===entry.receiptId&&(await current()).materials[kind].version===now.materials[kind].version);
  }
  view=await current();const old=view.materials.plan;
  const stale=await request(c.organizer,'/sports/platform/actions/event.material.save/execute','POST',{input:{eventId:event,kind:'plan',expectedVersion:old.version-1,factDigest:view.factDigest,title:'合成旧版本',content:'不应覆盖'},requestKey:key()});
  test.check('stale material editing does not overwrite a later version',stale.code!==200&&(await current()).materials.plan.version===old.version);
  const digest=await request(c.organizer,'/sports/platform/actions/event.material.save/execute','POST',{input:{eventId:event,kind:'plan',expectedVersion:old.version,factDigest:'0'.repeat(64),title:'合成旧事实',content:'不应覆盖'},requestKey:key()});
  test.check('old event facts cannot replace a current working draft',digest.code!==200&&(await current()).materials.plan.version===old.version);
  if(!s.actions.manual?.complete)await mutate('manual','event.material.save',{eventId:event,kind:'plan',expectedVersion:old.version,factDigest:view.factDigest,title:old.title,content:old.content+'\n\n人工核对记录：本机合成测试，现场岗位和资源仍须责任人确认。'});
  test.check('manual review preserves the prior AI source version',(await current()).materials.plan.history.some(h=>h.version===old.version&&h.source==='ai'));
  const image=await upload('banner','event-banner');view=await current();
  if(!s.actions.cover?.complete)await mutate('cover','event.cover.save',{eventId:event,expectedVersion:view.eventVersion,fileId:image.fileId});
  const cover=await fetch(c.backend+`/sports/public/events/${event}/media/banner`);const bytes=Buffer.from(await cover.arrayBuffer());
  test.check('public event cover returns exactly the human-uploaded file',cover.ok&&hash(bytes)===image.sha256);
  const wrong=await upload('rules','event-rules');view=await current();
  const denied=await request(c.organizer,'/sports/platform/actions/event.cover.save/execute','POST',{input:{eventId:event,expectedVersion:view.eventVersion,fileId:wrong.fileId},requestKey:key()});
  test.check('private rules image cannot become a public cover',denied.code!==200&&(await api(c.organizer,`/sports/b/events/${event}`)).bannerFileId===image.fileId);
  const promo=await api(c.organizer,`/sports/b/events/${event}/promotion`);
  if(!promo.imageEnabled){const unavailable=await request(c.organizer,`/sports/b/events/${event}/promotion/visual`,'POST',{consent:true,style:'community',audience:'合成本机测试',keywords:'验证不可用图像服务不改已有封面'});test.check('unconfigured image model refuses generation and preserves the selected cover',unavailable.code!==200&&(await api(c.organizer,`/sports/b/events/${event}`)).bannerFileId===image.fileId);test.evidence.imageProvider='External image generation not configured: success not claimed';}
  else test.evidence.imageProvider='Enabled but actual provider image-generation acceptance not executed in this text/storage test';
  test.check('working drafts and cover changes do not publish an announcement or revise frozen publication',readSql(`SELECT publication_status||'|'||published_revision FROM asp_event WHERE id=${event};`)===beforePublication);
  test.evidence.objects={eventId:event,coverFileId:image.fileId};test.finish();
}catch(error){test.evidence.failure=error.message;test.save();console.error(error.message);process.exitCode=1;}
