// Ordinary synthetic accounts against the already prepared isolated trial. Do not rerun successful mutations.
import fs from 'node:fs'; import path from 'node:path'; import crypto from 'node:crypto'; import assert from 'node:assert/strict'; import {createRequire} from 'node:module';
import {context,api,request,key,readSql} from './lib/BusinessRegression.mjs';
const allowed=path.resolve('.local/team-invite-experience-20261012');
const root=path.resolve(process.env.AISPORTS_TEAM_SHARE_ROOT||path.join(allowed,key()));
assert.ok(root.startsWith(allowed+path.sep),'Explicit private invitation trial root'); fs.mkdirSync(root,{recursive:true});
const stateFile=path.join(root,'state.private.json');
const state=fs.existsSync(stateFile)?JSON.parse(fs.readFileSync(stateFile,'utf8')):{label:'分享邀请演练（模拟）'+key().slice(0,8),stages:{}};
const saveState=()=>fs.writeFileSync(stateFile,JSON.stringify(state,null,2)); saveState();
const output=path.join(root,'flow-'+key()); fs.mkdirSync(output);
const receipt={at:new Date().toISOString(),database:context.database,scope:'Actual isolated HTTP, ordinary-account desktop/mobile join confirmation. Synthetic team; no SMS, actual WeChat mini-program or new account registration claimed.',jarSha256:JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8').replace(/^\uFEFF/,'')).jarSHA256,checks:[],screenshots:[],passed:false};
const save=()=>fs.writeFileSync(path.join(output,'receipt.json'),JSON.stringify(receipt,null,2));
const check=(name,ok)=>{receipt.checks.push({name,passed:!!ok});save();assert.ok(ok,name);console.log('PASS '+name);};
const marked=stage=>{state.stages[stage]={at:new Date().toISOString(),receipt:path.relative(root,path.join(output,'receipt.json')),jarSha256:receipt.jarSha256};saveState();};
const continuing=stage=>{if(!state.stages[stage])return false;receipt.continuedStages??=[];receipt.continuedStages.push({stage,...state.stages[stage]});save();return true;};
const safeCall=async(...args)=>{try{return await api(...args);}catch(error){throw new Error(String(error.message).replace(/[a-f0-9]{64}/g,'[invite]'));}};
const login=async(person)=>({token:(await safeCall(null,'/auth/login','POST',{username:person.phone,password:context.password,grantType:'platform',tenantId:'900001',clientId:context.clientId})).access_token});
const ids=(value)=>{assert.match(String(value),/^\d+$/);return String(value);};
const {chromium}=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json')('playwright');
let browser,page;
async function stable(){await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));await page.waitForFunction(()=>document.getAnimations().every(a=>a.effect?.getTiming().iterations===Infinity||a.playState!=='running'));await page.locator('.el-message').waitFor({state:'hidden'});}
async function screenshot(name){await stable();const file=path.join(output,name+'.png');await page.screenshot({path:file});receipt.screenshots.push({file:path.relative(root,file),sha256:crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')});save();}
try{
 const actors=await Promise.all(context.people.slice(0,5).map(login));const [captain,desktop,mobile,concurrent,other]=actors;
 if(!state.teamId){const mine=await safeCall(captain,'/sports/c/teams');const recovered=mine.memberships.filter(t=>t.name===state.label&&t.membershipStatus==='active');assert.ok(recovered.length<=1,'Unique named synthetic fixture');state.teamId=ids(recovered[0]?.teamId||(await safeCall(captain,'/sports/c/teams','POST',{name:state.label})).id);saveState();}
 const teamId=ids(state.teamId);receipt.objects={teamId};save();
 if(!state.share){state.share=await safeCall(captain,`/sports/c/teams/${teamId}/share-invitation`,'POST',{replace:false});saveState();}
 const token=state.share.path.split('/').at(-1);assert.match(token,/^[a-f0-9]{64}$/);
 const shareId=ids(state.share.id);const previewRoute='/sports/public/team-invitations/'+token;const acceptRoute='/sports/c/teams/share-invitations/'+token+'/accept';
 if(!continuing('initial')){
  const preview=await safeCall(null,previewRoute);check('Anonymous preview reveals only team identity, expiry and effective state',preview.status==='pending'&&preview.teamName===state.label&&Object.keys(preview).sort().join(',')==='expiresAt,status,teamId,teamName');
  check('Captain copying again retains one unexpired grant',(await safeCall(captain,`/sports/c/teams/${teamId}/share-invitation`,'POST',{replace:false})).id===shareId);
  check('Non-captain cannot read or replace a share credential',(await request(other,`/sports/c/teams/${teamId}/share-invitation`)).code!==200&&(await request(other,`/sports/c/teams/${teamId}/share-invitation`,'POST',{replace:true})).code!==200);
  check('Invalid token and missing explicit confirmation are refused',(await request(null,'/sports/public/team-invitations/invalid')).code!==200&&(await request(other,acceptRoute,'POST',{confirmed:false})).code!==200);marked('initial');
 }
 browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
 if(!state.stages.revoked && !continuing('captainShareUi')){
  const ctx=await browser.newContext({viewport:{width:1440,height:1000},permissions:['clipboard-read','clipboard-write']});page=await ctx.newPage();
  await page.goto(context.frontend+'/portal/login');await page.getByPlaceholder('请输入手机号').fill(context.people[0].phone);await page.getByPlaceholder('请输入密码').fill(context.password);await page.getByRole('button',{name:'登录',exact:true}).click();await page.waitForURL(u=>u.pathname!=='/portal/login');
  await page.goto(context.frontend+'/portal/teams/'+teamId);await page.locator('.team-share-manager').waitFor();await page.getByRole('button',{name:'复制入队邀请链接',exact:true}).waitFor();
  const copied=page.waitForResponse(r=>r.url().endsWith(`/sports/c/teams/${teamId}/share-invitation`)&&r.request().method()==='POST');await page.getByRole('button',{name:'复制入队邀请链接',exact:true}).click();const response=await(await copied).json();assert.equal(response.code,200,'Actual captain copy action succeeded');marked('captainShareUi');
  check('Captain actual team page copies the same authorized share without a duplicate grant',response.data.id===shareId&&await page.evaluate(expected=>navigator.clipboard.readText().then(value=>value===location.origin+expected),state.share.path));
  await screenshot('captain-share-desktop');await ctx.close();
 }
 for(const [device,index,actor,viewport] of [['desktop',1,desktop,{width:1440,height:1000}],['mobile',2,mobile,{width:390,height:844}]]){
  if(continuing(device+'Join'))continue;
  const ctx=await browser.newContext({viewport});page=await ctx.newPage();let joinRequests=0;
  page.on('request',r=>{if(r.url().includes('/share-invitations/')&&r.url().endsWith('/accept')&&r.method()==='POST')joinRequests++;});
  await page.goto(context.frontend+state.share.path);await page.getByRole('heading',{name:state.label,exact:true}).waitFor();
  check(device+' anonymous share page keeps invitation through registration without sending SMS',await page.getByRole('link',{name:'注册账号',exact:true}).count()===1);
  await page.getByRole('link',{name:'注册账号',exact:true}).click();await page.waitForURL(u=>u.pathname==='/portal/register');
  check(device+' actual registration page preserves exact safe return target',new URL(page.url()).searchParams.get('returnTo')===state.share.path);
  await page.goto(context.frontend+state.share.path);await page.getByRole('link',{name:'登录并继续',exact:true}).click();await page.waitForURL(u=>u.pathname==='/portal/login');
  check(device+' login preserves exact invitation target',new URL(page.url()).searchParams.get('returnTo')===state.share.path);
  await page.getByPlaceholder('请输入手机号').fill(context.people[index].phone);await page.getByPlaceholder('请输入密码').fill(context.password);await page.getByRole('button',{name:'登录',exact:true}).click();await page.waitForURL(u=>u.pathname===state.share.path);
  const dialog=page.getByRole('dialog',{name:'确认加入队伍'});await dialog.waitFor();await stable();
  const self=(await safeCall(actor,'/sports/c/identity')).self;
  check(device+' login opens explicit confirmation with correct team and own actual profile before writing',(await dialog.innerText()).includes(state.label)&&(await dialog.innerText()).includes(self.legalName)&&joinRequests===0);
  check(device+' confirmation is readable without clipped footer or horizontal overflow',await dialog.evaluate(el=>{const r=el.getBoundingClientRect();return r.x>=0&&r.y>=0&&r.bottom<=innerHeight+1&&document.documentElement.scrollWidth<=innerWidth+1;}));await screenshot('join-review-'+device);
  await dialog.getByRole('button',{name:'暂不加入',exact:true}).click();check(device+' declining the prompt makes no join request',joinRequests===0);
  await page.getByRole('button',{name:'查看并确认加入',exact:true}).click();const response=page.waitForResponse(r=>r.url().endsWith(acceptRoute)&&r.request().method()==='POST');await dialog.getByRole('button',{name:'确认加入队伍',exact:true}).click();const result=await(await response).json();assert.equal(result.code,200,'Actual UI join succeeded');marked(device+'Join');
  check(device+' actual confirmation joins once and shows the team entry',joinRequests===1&&(await safeCall(actor,'/sports/c/teams')).memberships.some(m=>m.teamId===teamId&&m.membershipStatus==='active'));await page.getByRole('link',{name:'查看队伍',exact:true}).waitFor();await screenshot('joined-'+device);await ctx.close();
 }
 if(!continuing('concurrentJoin')){const responses=await Promise.all([request(concurrent,acceptRoute,'POST',{confirmed:true}),request(concurrent,acceptRoute,'POST',{confirmed:true})]);assert.ok(responses.every(r=>r.code===200),'Concurrent acceptance responses');marked('concurrentJoin');check('Concurrent acceptance yields one current member and one source acceptance',responses.filter(r=>!r.data.alreadyMember).length===1&&readSql(`SELECT count(*) FROM asp_team_invitation WHERE share_invitation_id=${shareId};`)==='3');}
 if(!state.stages.revoked)check('All accepted invitees remain distinct current members and retry adds no acceptance',(await safeCall(captain,`/sports/c/teams/${teamId}`)).members.filter(m=>m.status==='active').length===(state.stages.removed?3:4)&&(await safeCall(desktop,acceptRoute,'POST',{confirmed:true})).alreadyMember&&readSql(`SELECT count(*) FROM asp_team_invitation WHERE share_invitation_id=${shareId};`)==='3');
 if(!continuing('removed')){const identity=await safeCall(mobile,'/sports/c/identity');const target=(await safeCall(captain,`/sports/c/teams/${teamId}`)).members.find(m=>m.accountId===identity.accountId&&m.status==='active');assert.ok(target);state.removedMemberId=ids(target.id);saveState();await safeCall(captain,`/sports/c/teams/${teamId}/members/${target.id}/remove`,'POST');marked('removed');}
 check('Removed invitee cannot regain membership by replaying old shared authorization',(await request(mobile,acceptRoute,'POST',{confirmed:true})).code!==200);
 check('Removed invitee receives their own persistent membership-change notice',(await safeCall(mobile,'/sports/c/notices')).some(n=>n.businessType==='team-member-removed'&&n.businessId===state.removedMemberId&&n.targetPath==='/portal/teams'));
 if(!continuing('revoked')){await safeCall(captain,`/sports/c/teams/${teamId}/share-invitation/revoke`,'POST');marked('revoked');}
 check('Revoked link is invalid in anonymous preview and cannot add another person',(await safeCall(null,previewRoute)).status==='revoked'&&(await request(other,acceptRoute,'POST',{confirmed:true})).code!==200);
 if(!continuing('rotated')){state.replacement=await safeCall(captain,`/sports/c/teams/${teamId}/share-invitation`,'POST',{replace:true});saveState();marked('rotated');}
 check('Replacing a link creates a new random grant while old authorization stays revoked',state.replacement.id!==shareId&&(await safeCall(null,'/sports/public/team-invitations/'+state.replacement.path.split('/').at(-1))).status==='pending'&&(await safeCall(null,previewRoute)).status==='revoked');
 receipt.externalBoundary='Real SMS, a newly registered account completing its profile and a deployed WeChat mini-program were not executed. Existing independent ordinary accounts used real login and current complete profiles.';
 receipt.passed=true;receipt.finishedAt=new Date().toISOString();save();console.log('Evidence: '+output);
}catch(error){receipt.failure=String(error.message).replace(/[a-f0-9]{64}/g,'[invite]');save();await page?.screenshot({path:path.join(output,'failure.png')}).catch(()=>{});throw new Error(receipt.failure);}finally{await browser?.close();}
