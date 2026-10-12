// Real isolated ordinary-role exercise. No clock/date bypass, no SQL mutation, no user-event edits.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';import {createRequire} from 'node:module';
import {context,api,request,key,action,versionOf,readSql} from './lib/BusinessRegression.mjs';
const run=process.env.AISPORTS_AWARD_RUN || path.resolve('.local/honor-repair-20261012',crypto.randomUUID());
fs.mkdirSync(run,{recursive:true});const file=path.join(run,'state.private.json');
const s=fs.existsSync(file)?JSON.parse(fs.readFileSync(file,'utf8')):{keys:{},steps:{}};const save=()=>fs.writeFileSync(file,JSON.stringify(s,null,2));
const remember=async(n,fn)=>{if(s[n]===undefined){s[n]=await fn();save();}return s[n];};
const once=async(n,fn)=>{if(!s.steps[n]){await fn();s.steps[n]=true;save();}};
const rk=n=>{s.keys[n]??=key();save();return s.keys[n];};
const phase=process.argv.includes('--legacy')?'legacy': 'repair';const output=path.join(run,phase+'-'+key()+'.json');
const receipt={at:new Date().toISOString(),database:context.database,scope:'Real isolated services and separate ordinary-role sessions; synthetic event/results only. No real tournament acceptance.',checks:[],passed:false,jarSha256:JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8').replace(/^\uFEFF/,'')).jarSHA256};
const check=(name,ok)=>{receipt.checks.push({name,passed:!!ok});fs.writeFileSync(output,JSON.stringify(receipt,null,2));assert.ok(ok,name);console.log('PASS '+name);};
const session=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json','utf8').replace(/^\uFEFF/,''));
const login=async(phone,password)=>({token:(await api(null,'/auth/login','POST',{username:phone,password,grantType:'platform',tenantId:'900001',clientId:context.clientId})).access_token});
let browser;
try{
 const platform=await login(session.people[0].phone,session.password);const org={token:(await api(platform,'/auth/organization/enter','POST',{})).access_token};
 const [a,b,c]=await Promise.all(context.people.slice(0,3).map(p=>login(p.phone,context.password)));
 const own=async()=> (await api(a,'/sports/c/proofs')).filter(p=>p.eventName===s.label);
 const pending=()=>api(org,'/sports/proof-review/events/'+s.event.id);
 const allAwards=()=>api(org,'/sports/proof-review/events/'+s.event.id+'?includeVerified=true');
 const act=async(code,input,n)=>(await action(org,code,input,rk(n))).value;
 if(phase==='legacy'){
  s.label??='奖项连续更正演练 '+path.basename(run).slice(0,8)+'（模拟）';s.start??=new Date(Date.now()+150000).toISOString();save();
  const end=new Date(new Date(s.start).getTime()+7200000).toISOString();
  const event=await remember('event',()=>api(org,'/sports/b/events','POST',{name:s.label,location:'隔离模拟球馆',projectName:'羽毛球',feeDescription:'免费模拟演练',registrationOpensAt:new Date(Date.now()-3600000).toISOString(),registrationClosesAt:new Date(new Date(s.start).getTime()-45000).toISOString(),startsAt:s.start,endsAt:end,registrationReview:'manual',rulesText:'隔离合成场次，不举行真实比赛。',noticeText:'仅本地验证，结果为模拟。',declarationText:''}));
  const unit=async n=>api(org,'/sports/b/registrations/units','POST',{eventId:event.id,name:n,entryType:'individual',minMembers:1,maxMembers:1,limitCount:8,charged:false,amount:0,paymentMode:'free',requestKey:rk(n)});
  await remember('main',()=>unit('单打项目甲（模拟）'));await remember('other',()=>unit('单打项目乙（模拟）'));
  await once('published',()=>api(org,'/sports/b/events/'+event.id+'/publish','POST',{requestKey:rk('publish'),contactConfirmed:true,contactName:'模拟负责人',contactMethod:'仅本地，不实际联系'}));
  for(const [n,actor,u] of [['a',a,s.main],['b',b,s.main],['aOther',a,s.other],['cOther',c,s.other]]){
   const r=await remember(n,()=>api(actor,'/sports/c/registrations','POST',{unitId:u.id,requestKey:rk('reg-'+n)}));
   await once('submit-'+n,()=>api(actor,'/sports/c/registrations/'+r.id+'/submit','POST',{requestKey:r.requestKey}));await once('approve-'+n,()=>api(org,'/sports/b/registrations/'+r.id+'/approve','POST'));
  }
  for(const [n,code,u,regA,regB] of [['m1','01',s.main,s.a,s.b],['m2','02',s.main,s.a,s.b],['m3','01',s.other,s.aOther,s.cOther]]){
   const m=await remember(n,()=>api(org,'/sports/b/competition/units/'+u.id+'/matches','POST',{code,registrationA:regA.id,registrationB:regB.id,requestKey:rk('match-'+n)}));
   await once('score-'+n,()=>api(org,'/sports/b/competition/matches/'+m.matchId+'/result','POST',{summary:'2:1',games:'21:18|18:21|21:17',outcomeA:'win',outcomeB:'loss',requestKey:rk('score-'+n)}));
  }
  while(Date.now()<new Date(s.start).getTime()){console.log('Waiting for real event start; no date/clock changes.');await new Promise(r=>setTimeout(r,Math.min(15000,new Date(s.start).getTime()-Date.now()+100)));}
  for(const n of ['m1','m2','m3'])await once('final-'+n,()=>api(org,'/sports/b/competition/matches/'+s[n].matchId+'/finalize','POST',{requestKey:rk('final-'+n)}));
  for(const [n,r,title] of [['oldFirst',s.a,'第一名'],['oldSecond',s.a,'第二名-1'],['oldOther',s.aOther,'第一名']]){
   await remember(n,()=>api(org,'/sports/b/competition/awards','POST',{registrationId:r.id,title,basis:'本轮合成正式赛果人工核实',requestKey:rk(n)}));
  }
  check('Old runtime reproduces two active placing titles in one registration',(await own()).filter(p=>p.unitName==='单打项目甲（模拟）').length===2);
  receipt.objects={eventId:s.event.id,unitId:s.main.id,matches:[s.m1.matchId,s.m2.matchId,s.m3.matchId]};
 } else {
  assert.ok(s.event&&s.oldSecond,'Prepare legacy reproduction before candidate activation.');
  if(s.steps.correct1){
   const prior=fs.readdirSync(run).filter(f=>f.startsWith('repair-')&&f.endsWith('.json')).map(f=>({file:f,data:JSON.parse(fs.readFileSync(path.join(run,f),'utf8'))})).find(r=>!r.data.passed&&r.data.checks.length===8);
   assert.ok(prior,'Preserved successful pre-gate observations required for resume');
   receipt.priorEvidence={file:prior.file,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(run,prior.file))).digest('hex'),jarSha256:prior.data.jarSha256};
   receipt.checks.push(...prior.data.checks.map(c=>({...c,observedIn:prior.file})));
  }else{
  check('Legacy duplicates project as one current placing with another project preserved',(await own()).length===2&&(await own()).some(p=>p.title==='第二名-1'));
  const past=await api(a,'/sports/c/proofs?history=true');check('Legacy superseded placing is history and no longer downloadable',past.some(p=>p.eventName===s.label&&p.title==='第一名'&&p.unitName==='单打项目甲（模拟）'&&p.status==='replaced')&&(await request(a,'/sports/c/proofs/'+past.find(p=>p.eventName===s.label&&p.status==='replaced').honorId)).code!==200);
  check('A new title cannot create a second active final placing',(await request(org,'/sports/b/competition/awards','POST',{registrationId:s.a.id,title:'第三名',basis:'合成重复名次尝试',requestKey:key(),awardKind:'placing'})).code!==200);
  await remember('special',()=>api(org,'/sports/b/competition/awards','POST',{registrationId:s.a.id,title:'体育精神奖',basis:'仅依场次02的合成专项表现',requestKey:rk('special'),awardKind:'special',basisMatchIds:[s.m2.matchId]}));
  check('Special award stays independent of final placing',(await own()).length===3);
  }
  await once('correct1',()=>act('result.correct',{matchId:s.m1.matchId,expectedVersion:versionOf('asp_match',s.m1.matchId),summary:'1:2',games:'18:21|21:18|17:21',outcomeA:'loss',outcomeB:'win',reason:'本轮合成场次01复核'},'correct1'));
  let reviews=await pending();check('First correction queues one placing claim with names, project and matching representative version',reviews.length===1&&reviews[0].award_kind==='placing'&&reviews[0].names&&reviews[0].unit_name==='单打项目甲（模拟）'&&Number(reviews[0].version)===versionOf('asp_honor',reviews[0].id));
  check('Unrelated special match and other project remain current',(await own()).length===2&&(await own()).some(p=>p.title==='体育精神奖')&&(await own()).some(p=>p.unitName==='单打项目乙（模拟）'));
  check('Closure counts claims rather than historical/person rows',(await api(org,'/sports/closure/events/'+s.event.id)).proofsAwaitingReview===1);
  check('Other participant cannot see private review',(await request(b,'/sports/proof-review/events/'+s.event.id)).code!==200);
  const stale=await remember('staleInput',async()=>({honorId:reviews[0].id,expectedVersion:Number(reviews[0].version),decision:'reissue',title:'第三名',reason:'合成依据快照',basisFingerprint:reviews[0].basis_fingerprint}));
  await once('evidenceChange',()=>act('result.correct',{matchId:s.m1.matchId,expectedVersion:versionOf('asp_match',s.m1.matchId),summary:'1:2',games:'18:21|21:18|17:21',outcomeA:'loss',outcomeB:'win',reason:'补充独立合成场次的依据变化检查'},'evidenceChange'));
  let staleConfirmation=await api(org,'/sports/platform/actions/honor.resolve/confirm','POST',stale);
  check('Changed result evidence rejects an otherwise unchanged pending honor version',(await request(org,'/sports/platform/actions/honor.resolve/execute','POST',{input:stale,requestKey:key(),confirmationId:staleConfirmation})).code!==200);
  reviews=await pending();const row=reviews[0],input={honorId:row.id,expectedVersion:Number(row.version),decision:'reissue',title:'第三名',reason:'采用最新合成正式赛果核实最终名次',basisFingerprint:row.basis_fingerprint};
  await once('reissue1',()=>act('honor.resolve',input,'reissue1'));
  const signed=(await own()).find(p=>p.title==='第三名');
  check('Reissue creates one current placing and revokes all legacy same-claim copies',!!signed&&(await own()).length===3&&readSql("SELECT count(*) FROM asp_honor WHERE registration_id="+s.a.id+" AND title IN('第一名','第二名-1') AND status='verified';")==='0');
  const before=(await own()).length;await act('honor.resolve',input,'reissue1');check('Same reissue request is idempotent',(await own()).length===before);
  check('Repeated reissue with a new key cannot use a stale honor',(await request(org,'/sports/platform/actions/honor.resolve/execute','POST',{input,requestKey:key(),confirmationId:await api(org,'/sports/platform/actions/honor.resolve/confirm','POST',input)})).code!==200);
  await once('void2',()=>act('result.void',{matchId:s.m2.matchId,expectedVersion:versionOf('asp_match',s.m2.matchId),reason:'本轮合成场次02撤销无效结果'},'void2'));
  reviews=await pending();check('Voiding actual basis queues placing and its dependent special award only',reviews.length===2&&(await own()).length===1);
  const special=reviews.find(p=>p.award_kind==='special'),bad={honorId:special.id,expectedVersion:Number(special.version),decision:'reissue',title:'体育精神奖',reason:'不能借用场次01代替已撤销场次02',basisFingerprint:special.basis_fingerprint};
  check('Another confirmed match cannot substitute a void award dependency',(await request(org,'/sports/platform/actions/honor.resolve/execute','POST',{input:bad,requestKey:key(),confirmationId:await api(org,'/sports/platform/actions/honor.resolve/confirm','POST',bad)})).code!==200);
  await once('restore2',()=>act('result.correct',{matchId:s.m2.matchId,expectedVersion:versionOf('asp_match',s.m2.matchId),summary:'2:1',games:'21:18|18:21|21:17',outcomeA:'win',outcomeB:'loss',reason:'本轮合成场次02恢复有效正式结果'},'restore2'));
  for(const h of await pending())await once('resolved-'+h.id,()=>act('honor.resolve',{honorId:h.id,expectedVersion:Number(h.version),decision:'reissue',title:h.award_kind==='placing'?'第二名':'体育精神奖',reason:'按恢复后的最新合成正式赛果再次核实',basisFingerprint:h.basis_fingerprint},'resolved-'+h.id));
  check('Multiple corrections leave one effective placing, one special and another project award',(await own()).length===3&&(await pending()).length===0);
  check('All superseded proof URLs stay invalid',(await api(a,'/sports/c/proofs?history=true')).filter(p=>p.eventName===s.label&&!p.current).length>=3&&(await request(a,'/sports/c/proofs/'+signed.honorId)).code!==200);
  check('Unrelated participant and anonymous visitors cannot read private proof',(await request(c,'/sports/c/proofs/'+(await own())[0].honorId)).code!==200&&(await request(null,'/sports/c/proofs/'+(await own())[0].honorId)).code!==200);
  receipt.objects={eventId:s.event.id,unitId:s.main.id,matches:[s.m1.matchId,s.m2.matchId,s.m3.matchId]};save();
 }
 receipt.passed=true;receipt.finishedAt=new Date().toISOString();fs.writeFileSync(output,JSON.stringify(receipt,null,2));console.log('Evidence: '+output);
}catch(e){receipt.failure=e.message;fs.writeFileSync(output,JSON.stringify(receipt,null,2));throw e;}finally{await browser?.close();}

