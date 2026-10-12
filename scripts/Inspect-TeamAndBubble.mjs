// Read completed ordinary-role bookings and inspect both launchers; never resubmit a booking or send an AI task.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';import {createRequire} from 'node:module';
import {context,api,readSql,createEvidence} from './lib/BusinessRegression.mjs';
const trial=createEvidence('team-bubble-final'),{check,evidence,directory,save}=trial;
const base='.local/business-regression-20261011/a006561dd66540c2b383415b02480f2c/team-booking-1791790284512-ecda7495';
const prior=JSON.parse(fs.readFileSync(path.join(base,'receipt.json'),'utf8'));assert.ok(prior.passed);
evidence.prior={path:base+'/receipt.json',sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(base,'receipt.json'))).digest('hex')};evidence.jarSha256=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8').replace(/^\uFEFF/,'')).jarSHA256;
const session=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json','utf8').replace(/^\uFEFF/,''));
const actor={token:(await api(null,'/auth/login','POST',{username:context.people[0].phone,password:context.password,grantType:'platform',tenantId:'900001',clientId:context.clientId})).access_token};
const entries=await api(actor,'/sports/c/registrations');const current=prior.objects.units.slice(0,2).map(u=>entries.find(e=>e.unitId===u));assert.ok(current.every(Boolean));
check('Final runtime retains both submitted team bookings with two confirmed players',current.every(e=>e.status==='submitted'&&e.members.length===2&&e.members.every(m=>m.status==='confirmed')));
check('Final runtime retains one frozen roster and one occupied place for each booking',current.every(e=>readSql('SELECT count(*) FROM asp_roster_version v JOIN asp_registration r ON r.id=v.registration_id AND r.roster_revision=v.revision WHERE r.id='+e.id+' AND v.status<>\'superseded\';')==='1'&&readSql('SELECT used_count FROM asp_capacity_pool WHERE unit_id='+e.unitId+';')==='1'));
const {chromium}=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json')('playwright');const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});let page;
async function stable(){await page.evaluate(()=>{for(const a of document.getAnimations())if(a.effect?.getTiming().iterations!==Infinity)a.finish();});await page.locator('.el-message').waitFor({state:'hidden'});}
async function bubble(selector,device,role){
 const b=page.locator(selector);await b.waitFor({state:'visible'});await stable();const shape=await b.evaluate(el=>{const r=el.getBoundingClientRect();return {text:el.textContent.trim(),image:el.querySelector('img')?.complete&&el.querySelector('img').naturalWidth>0,bg:getComputedStyle(el).backgroundColor,w:r.width,h:r.height,left:r.left,right:r.right,bottom:r.bottom,width:innerWidth,height:innerHeight};});
 check(device+' '+role+' launcher is only the original asset within its compact viewport',shape.text===''&&shape.image&&shape.bg==='rgba(0, 0, 0, 0)'&&shape.w<=64&&shape.h<=64&&shape.left>=0&&shape.right<=shape.width&&shape.bottom<=shape.height);
 await b.click();const win=page.locator(role==='organizer'?'.b-ai-window':'.assistant-window');await win.waitFor({state:'visible'});check(device+' '+role+' icon opens the existing assistant window',await b.getAttribute('aria-expanded')==='true');await win.getByRole('button',{name:'关闭聊天窗口'}).click();await win.waitFor({state:'hidden'});await stable();
 const image=path.join(directory,role+'-'+device+'.png');await page.screenshot({path:image});evidence.screenshots??=[];evidence.screenshots.push(image);save();
}
try{
 for(const [device,viewport] of [['desktop',{width:1440,height:1000}],['mobile',{width:390,height:844}]]){
  const c=await browser.newContext({viewport});page=await c.newPage();let fields=0;page.on('request',r=>{if(/\/sports\/c\/registrations\/\d+\/fields/.test(r.url()))fields++;});
  await page.goto(context.frontend+'/portal/login');await page.getByPlaceholder('请输入手机号').fill(context.people[0].phone);await page.getByPlaceholder('请输入密码').fill(context.password);await page.getByRole('button',{name:'登录',exact:true}).click();await page.waitForURL(u=>!u.pathname.includes('/login'));await page.goto(context.frontend+'/portal/registration/detail/'+current[0].id);await page.getByRole('heading',{name:'本次参赛名单'}).waitFor();await stable();
  check(device+' non-playing captain sees both named frozen players without participant-only field calls',await page.locator('.participant-list article').count()===2&&fields===0&&!(await page.locator('body').innerText()).includes('你不在这条报名里'));
  await bubble('.assistant-bubble',device,'participant');await c.close();
  const o=await browser.newContext({viewport});page=await o.newPage();await page.goto(context.frontend+'/portal/login');await page.getByPlaceholder('请输入手机号').fill(session.people[0].phone);await page.getByPlaceholder('请输入密码').fill(session.password);await page.getByRole('button',{name:'登录',exact:true}).click();await page.waitForURL(u=>!u.pathname.includes('/login'));await page.goto(context.frontend+'/portal/organization?tab=status');await page.getByRole('button',{name:'进入办赛工作台'}).click();await page.waitForURL(u=>u.pathname.includes('/org-desk'));await page.goto(context.frontend+'/org-desk/workspace/'+prior.objects.eventId+'?task=checkin');await bubble('.b-ai-launcher',device,'organizer');await o.close();
 }
 trial.finish();
}catch(error){evidence.failure=error.message;save();await page?.screenshot({path:path.join(directory,'failure.png')}).catch(()=>{});throw error;}finally{await browser.close();}
