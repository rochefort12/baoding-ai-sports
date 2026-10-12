// Real ordinary-role booking; all writes are labelled synthetic and confined to the prepared isolated database.
import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';import {createRequire} from 'node:module';
import {context,api,request,key,iso,readSql,createEvidence} from './lib/BusinessRegression.mjs';
const trial=createEvidence('team-booking');const {check,evidence,directory,save}=trial;
evidence.jarSha256=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8').replace(/^\uFEFF/,'')).jarSHA256;
const session=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json','utf8').replace(/^\uFEFF/,''));
const login=async(phone,password)=>({token:(await api(null,'/auth/login','POST',{username:phone,password,grantType:'platform',tenantId:'900001',clientId:context.clientId})).access_token});
const {chromium}=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json')('playwright');
let browser,page;
async function stable(p){await p.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));await p.waitForFunction(()=>document.getAnimations().every(a=>a.effect?.getTiming().iterations===Infinity||a.playState!=='running'));await p.locator('.el-message').waitFor({state:'hidden'});}
async function shot(name){await stable(page);const target=path.join(directory,name+'.png');await page.screenshot({path:target});evidence.screenshots??=[];evidence.screenshots.push(target);save();}
try{
 const owner=await login(session.people[0].phone,session.password);const org={token:(await api(owner,'/auth/organization/enter','POST',{})).access_token};
 const [a,b,c,d]=await Promise.all(context.people.slice(0,4).map(p=>login(p.phone,context.password)));
 const resumePath=process.env.AISPORTS_TEAM_BOOKING_RESUME;
 const prior=resumePath?JSON.parse(fs.readFileSync(path.join(resumePath,'receipt.json'),'utf8')):null;
 if(prior){assert.ok(path.resolve(resumePath).startsWith(path.resolve(context.out)+path.sep));assert.ok(!prior.passed&&prior.objects.units?.length===4&&prior.checks.length===5,'Only the preserved pre-booking failure may resume here');evidence.priorEvidence={path:path.relative(context.out,resumePath),sha256:(await import('node:crypto')).createHash('sha256').update(fs.readFileSync(path.join(resumePath,'receipt.json'))).digest('hex')};}
 const team=prior?await api(a,'/sports/c/teams/'+prior.objects.teamId):await api(a,'/sports/c/teams','POST',{name:'队伍一站报名（模拟）'+path.basename(directory).slice(-8)});const label=team.name;evidence.objects.teamId=team.id;save();
 if(!prior)for(const actor of [b,c]){const home=await api(actor,'/sports/c/teams/'+team.id+'/applications','POST');const application=home.myApplications.find(x=>x.teamId===team.id&&x.status==='pending');assert.ok(application);await api(a,'/sports/c/teams/applications/'+application.id+'/approve','POST');}
 const candidates=await api(a,'/sports/c/teams/'+team.id+'/candidates');const cap=candidates.find(p=>p.role==='captain');const others=candidates.filter(p=>p.role!=='captain');assert.equal(others.length,2);
 const event=prior?{id:prior.objects.eventId}:await api(org,'/sports/b/events','POST',{name:label,location:'隔离演练球馆',projectName:'羽毛球',feeDescription:'免费模拟测试',registrationOpensAt:iso(-1),registrationClosesAt:iso(23),startsAt:iso(24),endsAt:iso(27),registrationReview:'manual',rulesText:'本地合成报名，不举行真实赛事。',noticeText:'测试人员与名单均为模拟。',declarationText:''});evidence.objects.eventId=event.id;save();
 const units={};const unitNames=['desktop','mobile','validation','legacy'];if(prior){const existing=await api(org,'/sports/b/registrations/units?eventId='+event.id);for(let i=0;i<4;i++)units[unitNames[i]]=existing.find(u=>u.id===prior.objects.units[i]);}else for(const n of unitNames)units[n]=await api(org,'/sports/b/registrations/units','POST',{eventId:event.id,name:'双打名单验证 '+n+'（模拟）',entryType:'pair',minMembers:2,maxMembers:2,limitCount:8,charged:false,amount:0,paymentMode:'free',requestKey:key()});
 if(!prior)await api(org,'/sports/b/events/'+event.id+'/publish','POST',{requestKey:key(),contactConfirmed:true,contactName:'模拟负责人',contactMethod:'仅本地测试'});evidence.objects.units=Object.values(units).map(u=>u.id);save();
 const regCount=unit=>Number(readSql('SELECT count(*) FROM asp_registration WHERE unit_id='+unit+';'));
 for(const [name,actor,body] of [
  ['Non-captain cannot prepare team roster',b,{unitId:units.validation.id,teamId:team.id,memberAccountIds:others.map(p=>p.accountId)}],
  ['Duplicate players cannot create a partial booking',a,{unitId:units.validation.id,teamId:team.id,memberAccountIds:[cap.accountId,cap.accountId]}],
  ['Too many players cannot create a partial booking',a,{unitId:units.validation.id,teamId:team.id,memberAccountIds:candidates.map(p=>p.accountId)}],
  ['An unrelated account cannot be injected into the roster',a,{unitId:units.validation.id,teamId:team.id,memberAccountIds:[cap.accountId,(await api(d,'/sports/c/identity')).accountId]}]
 ]){check(name,(await request(actor,'/sports/c/registrations','POST',{...body,requestKey:key()})).code!==200&&regCount(units.validation.id)===0);}
 browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
 for(const [device,viewport] of [['desktop',{width:1440,height:1000}],['mobile',{width:390,height:844}]]){
  const ctx=await browser.newContext({viewport});page=await ctx.newPage();let fieldCalls=0;page.on('request',r=>{if(/\/sports\/c\/registrations\/\d+\/fields/.test(r.url()))fieldCalls++;});
  await page.goto(context.frontend+'/portal/login');await page.getByPlaceholder('请输入手机号').fill(context.people[0].phone);await page.getByPlaceholder('请输入密码').fill(context.password);await page.getByRole('button',{name:'登录',exact:true}).click();await page.waitForURL(u=>!u.pathname.includes('/login'));
  await page.goto(context.frontend+'/portal/registration/apply?eventId='+event.id+'&unitId='+units[device].id);
  let dialog=page.getByRole('dialog',{name:'选择报名方式与队伍'});await dialog.waitFor();await dialog.getByRole('button',{name:new RegExp(label)}).click();await dialog.locator('.team-booking-members .el-checkbox').first().waitFor();await stable(page);
  check(device+' choosing a team lists all members without creating a booking',await dialog.locator('.team-booking-members .el-checkbox').count()===3&&regCount(units[device].id)===0);
  const memberLabel=p=>dialog.locator('.team-booking-members .el-checkbox').filter({hasText:p.legalName});await memberLabel(cap).click();for(const person of others)await memberLabel(person).click();
  await dialog.getByRole('button',{name:'核对本次名单'}).click();dialog=page.getByRole('dialog',{name:'确认本次报名名单'});await dialog.waitFor();await stable(page);
  check(device+' second confirmation shows full actual roster and fee before any write',(await dialog.innerText()).includes(others[0].legalName)&&(await dialog.innerText()).includes(others[1].legalName)&&await dialog.locator('.team-booking-members article').count()===2&&regCount(units[device].id)===0);
  check(device+' team dialog has no clipped footer or horizontal overflow',await dialog.evaluate(el=>{const r=el.getBoundingClientRect();return r.x>=0&&r.y>=0&&r.bottom<=innerHeight+1&&document.documentElement.scrollWidth<=innerWidth+1;}));await shot('team-review-'+device);
  const created=page.waitForResponse(r=>r.url().endsWith('/sports/c/registrations')&&r.request().method()==='POST');await dialog.getByRole('button',{name:'确认名单，继续报名'}).click();const entryResponse=await(await created).json();assert.equal(entryResponse.code,200);const entry=entryResponse.data;
  await page.waitForURL(u=>u.pathname==='/portal/registration/detail/'+entry.id);await page.getByRole('heading',{name:'本次参赛名单'}).waitFor();await stable(page);
  check(device+' roster populated atomically with self-confirmation invitations and no capacity',entry.members.length===2&&entry.members.every(m=>m.status==='pending_confirmation'&&!!m.inviteToken)&&regCount(units[device].id)===1&&readSql('SELECT used_count FROM asp_capacity_pool WHERE unit_id='+units[device].id+';')==='0');
  check(device+' non-playing captain never requests participant-only fields',fieldCalls===0&&(await page.locator('.participant-list').innerText()).includes(others[0].legalName)&&(await page.locator('.participant-list').innerText()).includes(others[1].legalName));await shot('team-draft-'+device);
  const payload={unitId:units[device].id,teamId:team.id,memberAccountIds:others.map(p=>p.accountId),requestKey:entry.requestKey};
  check(device+' repeated preparation returns one current booking',(await api(a,'/sports/c/registrations','POST',payload)).id===entry.id&&regCount(units[device].id)===1);
  check(device+' same preparation key cannot change the selected roster',(await request(a,'/sports/c/registrations','POST',{...payload,memberAccountIds:[cap.accountId,others[0].accountId]})).code!==200);
  const invitations=await Promise.all([b,c].map(actor=>api(actor,'/sports/c/registrations/received')));for(let i=0;i<2;i++){const invite=invitations[i].find(x=>x.registrationId===entry.id);assert.ok(invite);await api([b,c][i],'/sports/c/registrations/invites/'+invite.inviteToken+'/confirm','POST');}
  await page.reload();await page.getByRole('button',{name:'正式提交报名',exact:true}).click();dialog=page.getByRole('dialog',{name:'确认正式提交报名'});await dialog.waitFor();await stable(page);
  check(device+' formal confirmation shows both named and confirmed participants',await dialog.locator('.team-booking-members article').count()===2&&(await dialog.innerText()).includes(others[0].legalName)&&(await dialog.innerText()).includes(others[1].legalName)&&(await api(a,'/sports/c/registrations')).find(e=>e.id===entry.id).status==='draft');await shot('team-submit-'+device);
  const submitted=page.waitForResponse(r=>r.url().endsWith('/'+entry.id+'/submit')&&r.request().method()==='POST');await dialog.getByRole('button',{name:'确认提交报名'}).click();const response=await(await submitted).json();check(device+' captain completes actual formal booking with one frozen roster and capacity',response.code===200&&response.data.status==='submitted'&&readSql('SELECT used_count FROM asp_capacity_pool WHERE unit_id='+units[device].id+';')==='1'&&readSql('SELECT count(*) FROM asp_roster_version WHERE registration_id='+entry.id+';')==='1');
  check(device+' preparation replay never resets submitted state',(await api(a,'/sports/c/registrations','POST',payload)).status==='submitted');await ctx.close();
 }
 const legacy=await api(a,'/sports/c/registrations','POST',{unitId:units.legacy.id,teamId:team.id,requestKey:key()});assert.equal(legacy.members.length,0);
 const filled=await api(a,'/sports/c/registrations','POST',{unitId:units.legacy.id,teamId:team.id,memberAccountIds:[cap.accountId,others[0].accountId],requestKey:key()});check('An existing empty legacy draft is filled once, without a duplicate booking',filled.id===legacy.id&&filled.members.length===2&&filled.members.filter(m=>m.selfMember&&m.status==='confirmed').length===1&&regCount(units.legacy.id)===1);
 check('A different second request cannot silently replace the existing roster',(await request(a,'/sports/c/registrations','POST',{unitId:units.legacy.id,teamId:team.id,memberAccountIds:others.map(p=>p.accountId),requestKey:key()})).code!==200&&(await api(a,'/sports/c/registrations')).find(e=>e.id===legacy.id).members.length===2);
 trial.finish();
}catch(cause){evidence.failure=cause.message;save();await page?.screenshot({path:path.join(directory,'failure.png')}).catch(()=>{});throw cause;}finally{await browser?.close();}
