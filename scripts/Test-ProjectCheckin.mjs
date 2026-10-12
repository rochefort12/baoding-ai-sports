// Real isolated HTTP/UI. Retain the old attendance record; do not infer which project it represented.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';import {createRequire} from 'node:module';
import {context,api,request,key,iso,readSql} from './lib/BusinessRegression.mjs';
const root=path.resolve('.local/project-checkin-20261012');fs.mkdirSync(root,{recursive:true});
const run=process.env.AISPORTS_CHECKIN_RUN?path.resolve(process.env.AISPORTS_CHECKIN_RUN):path.join(root,key());assert.ok(run.startsWith(root+path.sep));fs.mkdirSync(run,{recursive:true});
const stateFile=path.join(run,'state.private.json');const s=fs.existsSync(stateFile)?JSON.parse(fs.readFileSync(stateFile,'utf8')):{steps:{},keys:{}};const save=()=>fs.writeFileSync(stateFile,JSON.stringify(s,null,2));
const rk=n=>{s.keys[n]??=key();save();return s.keys[n];};const remember=async(n,fn)=>{if(s[n]===undefined){s[n]=await fn();save();}return s[n];};const once=async(n,fn)=>{if(!s.steps[n]){await fn();s.steps[n]=true;save();}};
const legacy=process.argv.includes('--legacy'),uiOnly=process.argv.includes('--ui');const receipt={at:new Date().toISOString(),database:context.database,scope:'Isolated synthetic ordinary-role service exercise; no real user-event acceptance.',jarSha256:JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8').replace(/^\uFEFF/,'')).jarSHA256,checks:[],passed:false};const file=path.join(run,(legacy?'legacy':'repair')+'-'+key()+'.json');const persist=()=>fs.writeFileSync(file,JSON.stringify(receipt,null,2));
const check=(name,ok)=>{receipt.checks.push({name,passed:!!ok});persist();assert.ok(ok,name);console.log('PASS '+name);};
const session=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json','utf8').replace(/^\uFEFF/,''));
const login=async(phone,password)=>({token:(await api(null,'/auth/login','POST',{username:phone,password,grantType:'platform',tenantId:'900001',clientId:context.clientId})).access_token});
const imageDirectory=path.join(run,'ui-'+key());if(!legacy)fs.mkdirSync(imageDirectory);receipt.screenshots=[];
let browser;
try {
 const owner=await login(session.people[0].phone,session.password),org={token:(await api(owner,'/auth/organization/enter','POST',{})).access_token};
 const actors=await Promise.all(context.people.slice(0,3).map(p=>login(p.phone,context.password)));const identities=await Promise.all(actors.map(async p=>{const id=await api(p,'/sports/c/identity');return {...id.self,personId:readSql('SELECT person_id FROM asp_account WHERE id='+id.accountId+';')};}));
 const body=(u,i,n)=>({unitId:u,personId:identities[i].personId,requestKey:rk(n)});
 const rows=()=>api(org,'/sports/b/competition/events/'+s.event.id+'/eligible');
 const checked=async(u,i)=> (await rows()).find(r=>r.registrationId===s['r'+u+i].id);
 const count=()=>readSql('SELECT count(*) FROM asp_checkin WHERE event_id='+s.event.id+';');
 if(legacy){
  const makeEvent=label=>api(org,'/sports/b/events','POST',{name:label,location:'隔离模拟球馆',projectName:'羽毛球',feeDescription:'免费模拟测试',registrationOpensAt:iso(-1),registrationClosesAt:iso(23),startsAt:iso(24),endsAt:iso(27),registrationReview:'manual',rulesText:'合成项目报到验证，不举行真实比赛。',noticeText:'仅本地模拟。',declarationText:''});
  await remember('event',()=>makeEvent('项目分别报到（模拟）'+path.basename(run).slice(0,8)));await remember('otherEvent',()=>makeEvent('跨赛事报到边界（模拟）'+path.basename(run).slice(0,8)));
  for(const [n,event,name] of [['A',s.event,'单打甲（模拟）'],['B',s.event,'单打乙（模拟）'],['foreign',s.otherEvent,'其他赛事（模拟）']])await remember(n,()=>api(org,'/sports/b/registrations/units','POST',{eventId:event.id,name,entryType:'individual',minMembers:1,maxMembers:1,limitCount:8,charged:false,amount:0,paymentMode:'free',requestKey:rk('unit'+n)}));
  await once('published',()=>api(org,'/sports/b/events/'+s.event.id+'/publish','POST',{requestKey:rk('publish'),contactConfirmed:true,contactName:'模拟负责人',contactMethod:'仅本地测试'}));
  for(const u of ['A','B'])for(let i=0;i<3;i++){
   const r=await remember('r'+u+i,()=>api(actors[i],'/sports/c/registrations','POST',{unitId:s[u].id,requestKey:rk('reg'+u+i)}));
   await once('submit'+u+i,()=>api(actors[i],'/sports/c/registrations/'+r.id+'/submit','POST',{requestKey:r.requestKey}));await once('approve'+u+i,()=>api(org,'/sports/b/registrations/'+r.id+'/approve','POST'));
  }
  await remember('oldCheckin',()=>api(org,'/sports/b/competition/events/'+s.event.id+'/check-ins','POST',{personId:identities[0].personId,requestKey:rk('legacy')}));
  check('Old runtime reproduces one event-level check-in appearing in two projects',(await checked('A',0)).checkedIn&&(await checked('B',0)).checkedIn&&count()==='1');
  await remember('legacyFingerprint',async()=>readSql('SELECT md5(to_jsonb(c)::text) FROM asp_checkin c WHERE id='+s.oldCheckin.checkInId+';'));
 }else{
  assert.ok(s.oldCheckin,'Prepare legacy fixture before migration');
  if(!uiOnly){
  if(!process.argv.includes('--resume')){
  check('Migration preserves the complete old row with an explicit unknown project',readSql('SELECT md5((to_jsonb(c)-\'unit_id\')::text) FROM asp_checkin c WHERE id='+s.oldCheckin.checkInId+';')===s.legacyFingerprint&&readSql('SELECT unit_id IS NULL FROM asp_checkin WHERE id='+s.oldCheckin.checkInId+';')==='t');
  check('Old event attendance no longer marks every project checked in',!(await checked('A',0)).checkedIn&&!(await checked('B',0)).checkedIn&&(await checked('A',0)).legacyEventCheckin);
  check('Multi-project requests must choose a project',(await request(org,'/sports/b/competition/events/'+s.event.id+'/check-ins','POST',{personId:identities[1].personId,requestKey:key()})).code!==200&&count()==='1');
  check('A project from another event cannot be checked in',(await request(org,'/sports/b/competition/events/'+s.event.id+'/check-ins','POST',body(s.foreign.id,1,'foreign'))).code!==200&&count()==='1');
  check('An ordinary participant cannot operate organizer attendance',(await request(actors[0],'/sports/b/competition/events/'+s.event.id+'/check-ins','POST',body(s.A.id,0,'denied'))).code!==200&&count()==='1');
  const a=await remember('checkedA0',()=>api(org,'/sports/b/competition/events/'+s.event.id+'/check-ins','POST',body(s.A.id,0,'a0')));
  check('Checking into A leaves the same participant in B unchecked',(await checked('A',0)).checkedIn&&!(await checked('B',0)).checkedIn&&a.unitId===s.A.id);
  check('Replaying the A check-in returns exactly one same record',(await api(org,'/sports/b/competition/events/'+s.event.id+'/check-ins','POST',body(s.A.id,0,'a0'))).checkInId===a.checkInId&&count()==='2');
  check('The A request key cannot be reused to authorize B',(await request(org,'/sports/b/competition/events/'+s.event.id+'/check-ins','POST',{...body(s.B.id,0,'b0'),requestKey:rk('a0')})).code!==200&&!(await checked('B',0)).checkedIn);
  await remember('checkedB0',()=>api(org,'/sports/b/competition/events/'+s.event.id+'/check-ins','POST',body(s.B.id,0,'b0')));
  check('Both projects retain independent attendance records',count()==='3'&&(await checked('A',0)).checkedIn&&(await checked('B',0)).checkedIn&&readSql('SELECT count(DISTINCT unit_id) FROM asp_checkin WHERE event_id='+s.event.id+' AND person_id='+identities[0].personId+';')==='2');
  check('Multiple projects do not duplicate event attendance growth',readSql('SELECT count(*) FROM asp_growth_record WHERE event_id='+s.event.id+' AND person_id='+identities[0].personId+' AND milestone=\'checkin\' AND status=\'effective\';')==='1');
  await remember('checkedA1',()=>api(org,'/sports/b/competition/events/'+s.event.id+'/check-ins','POST',body(s.A.id,1,'a1')));
  check('A checked-in project blocks its own full withdrawal',(await request(actors[1],'/sports/c/registrations/'+s.rA1.id+'/withdraw','POST',{requestKey:rk('withdrawA'),reason:'合成撤回边界测试'})).code!==200);
  await once('withdrawB',()=>api(actors[1],'/sports/c/registrations/'+s.rB1.id+'/withdraw','POST',{requestKey:rk('withdrawB'),reason:'合成撤回边界测试'}));
  }else{
   assert.ok(s.steps.withdrawB&&!s.apiAccepted,'Resume only the retained post-withdrawal observation failure');
   const prior=fs.readdirSync(run).filter(f=>f.startsWith('repair-')&&f.endsWith('.json')).map(f=>({file:f,data:JSON.parse(fs.readFileSync(path.join(run,f),'utf8'))})).find(r=>!r.data.passed&&r.data.checks.length===12&&r.data.checks.slice(0,11).every(c=>c.passed));assert.ok(prior);
   receipt.priorEvidence={path:prior.file,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(run,prior.file))).digest('hex'),jarSha256:prior.data.jarSha256};receipt.checks.push(...prior.data.checks.slice(0,11).map(c=>({...c,observedIn:prior.file})));
  }
  check('The same person may withdraw an unattended different project',(await api(actors[1],'/sports/c/registrations')).find(r=>r.id===s.rB1.id).status==='draft'&&readSql('SELECT status FROM asp_roster_version WHERE registration_id='+s.rB1.id+';')==='superseded'&&readSql('SELECT used_count FROM asp_capacity_pool WHERE unit_id='+s.B.id+';')==='2');
  check('A withdrawn project is refused even when another project is checked in',(await request(org,'/sports/b/competition/events/'+s.event.id+'/check-ins','POST',body(s.B.id,1,'withdrawn'))).code!==200);
  check('Unknown historical attendance conservatively blocks full withdrawal',(await request(actors[0],'/sports/c/registrations/'+s.rB0.id+'/withdraw','POST',{requestKey:key(),reason:'历史未知项目模拟核查'})).code!==200);
  const concurrent=await Promise.all(['concurrent1','concurrent2'].map(n=>api(org,'/sports/b/competition/events/'+s.event.id+'/check-ins','POST',body(s.A.id,2,n))));
  check('Concurrent different keys create one project/person check-in',concurrent[0].checkInId===concurrent[1].checkInId&&readSql('SELECT count(*) FROM asp_checkin WHERE unit_id='+s.A.id+' AND person_id='+identities[2].personId+';')==='1');
  s.apiAccepted=file;save();persist();
  }else{assert.ok(s.apiAccepted,'Retained API acceptance required for read-only UI continuation');receipt.priorEvidence={path:path.relative(run,s.apiAccepted),sha256:crypto.createHash('sha256').update(fs.readFileSync(s.apiAccepted)).digest('hex')};}
  const {chromium}=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json')('playwright');browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
  for(const [device,viewport] of [['desktop',{width:1440,height:1000}],['mobile',{width:390,height:844}]]){
   const ctx=await browser.newContext({viewport}),page=await ctx.newPage();await page.goto(context.frontend+'/portal/login');await page.getByPlaceholder('请输入手机号').fill(session.people[0].phone);await page.getByPlaceholder('请输入密码').fill(session.password);await page.getByRole('button',{name:'登录',exact:true}).click();await page.waitForURL(u=>!u.pathname.includes('/login'));await page.goto(context.frontend+'/portal/organization?tab=status');await page.getByRole('button',{name:'进入办赛工作台'}).click();await page.waitForURL(u=>u.pathname.includes('/org-desk'));
   await page.goto(context.frontend+'/org-desk/workspace/'+s.event.id+'?task=checkin');await page.getByText('每个项目分别报到', {exact:false}).waitFor();
   const select=page.locator('.el-select').first();await select.click();await page.getByRole('option',{name:s.B.name,exact:true}).click();const row=page.locator(device==='mobile'?'.project-checkin-person':'.el-table__body tr').filter({hasText:identities[2].legalName});await row.waitFor();check(device+' selected B shows this participant unchecked after checking in A',(await row.innerText()).includes('未报到'));
   check(device+' project selection has no document horizontal overflow',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));await page.evaluate(()=>{for(const a of document.getAnimations())if(a.effect?.getTiming().iterations!==Infinity)a.finish();});await row.scrollIntoViewIfNeeded();const shot=path.join(imageDirectory,'checkin-'+device+'.png');await page.screenshot({path:shot});receipt.screenshots.push(shot);persist();
   if(device==='mobile'&&process.argv.includes('--click')){
    assert.ok(!s.uiCheckinDone,'Do not repeat a successful UI attendance mutation');
    const response=page.waitForResponse(r=>r.url().endsWith('/events/'+s.event.id+'/check-ins')&&r.request().method()==='POST');await row.getByRole('button',{name:'为本项目报到'}).click();const rr=await response,result=await rr.json();
    check('Mobile click sends the selected project and writes its own attendance',rr.request().postDataJSON().unitId===s.B.id&&result.code===200&&result.data.unitId===s.B.id);s.uiCheckinDone=result.data.checkInId;save();
    await page.waitForFunction(name=>Array.from(document.querySelectorAll('.project-checkin-person')).some(el=>el.textContent.includes(name)&&el.textContent.includes('已报到')),identities[2].legalName);
    check('Mobile confirms B without altering the existing A attendance',(await checked('B',2)).checkedIn&&(await checked('A',2)).checkedIn&&readSql('SELECT count(*) FROM asp_checkin WHERE event_id='+s.event.id+' AND person_id='+identities[2].personId+';')==='2');
    await page.locator('.el-message').waitFor({state:'hidden'});const saved=path.join(imageDirectory,'checkin-mobile-saved.png');await page.screenshot({path:saved});receipt.screenshots.push(saved);
   }
   await ctx.close();
  }
 }
 receipt.objects={eventId:s.event.id,unitIds:[s.A.id,s.B.id],legacyCheckinId:s.oldCheckin.checkInId};receipt.passed=true;receipt.finishedAt=new Date().toISOString();persist();console.log('Evidence: '+file);
}catch(error){receipt.failure=error.message;persist();throw error;}finally{await browser?.close();}
