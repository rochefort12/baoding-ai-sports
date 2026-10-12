import { createFixtureAudit } from './lib/UiFixtureAudit.mjs';
const fixtureAudit=createFixtureAudit();
// 交互回归：业务XHR全部截获，POST只返回本地模拟结果。
import {createRequire} from 'node:module';
import path from 'node:path';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {event,units,entry,menus,identity,team} from './critical-ui-fixtures.mjs';
const require=createRequire(path.join(process.argv[2],'_resolve.cjs'));
const {chromium}=require('playwright');
const base=process.argv[3]||'http://127.0.0.1:5173';
const out=path.resolve('.local/critical-tests'); await fs.mkdir(out,{recursive:true});
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true});
const checks=[],unexpected=[],errors=[];let completed=false;
const check=(condition,label)=>{assert.ok(condition,label);checks.push(label);console.log('PASS '+label)};
async function scenario(kind,width=1440) {
 const state={settled:kind==='extra',fail:false,status:'pending',writes:[],release:null};
 const context=await browser.newContext({viewport:{width,height:width===1440?900:844}});
 await context.addInitScript(()=>{localStorage.setItem('Admin-Token','isolated-critical');localStorage.setItem('Platform-Token','isolated-critical')});
 const invite=()=>({registrationId:'701',eventId:'901',eventName:event.name,unitName:'双打',entryType:'pair',registrationStatus:'draft',memberStatus:state.status==='accepted'?'confirmed':'pending_confirmation',canRespond:state.status==='pending',members:state.status==='accepted'?[{legalName:'虚构伙伴',status:'confirmed',selfMember:false},{legalName:'虚构本人',status:'confirmed',selfMember:true}]:[]});
 await context.route('**/*',async route=>{
  const request=route.request();
  if(!['xhr','fetch'].includes(request.resourceType()))return route.continue();
  const u=new URL(request.url()).pathname;
  let data=[],code=200,msg='isolated fixture';
  if(request.method()!=='GET'){
   const permitted=kind==='sender'?u.endsWith('/teams/601/invitations'):kind==='money'||kind==='extra'?u.endsWith('/fees/obligations/801/confirm'):kind==='registration'?u.endsWith('/registrations/invites/fixture/confirm'):u.endsWith('/teams/invitations/611/accept');
   if(!permitted){unexpected.push(u);return route.fulfill({json:{code:403,msg:'isolated writes forbidden'}})}
   state.writes.push({path:u,data:request.postDataJSON()});
   if(state.release)await state.release.promise;
   if(state.fail){code=500;msg='隔离模拟：服务暂时不可用';}
   else {state.settled=true;state.status='accepted';if(kind==='registration')data=invite();if(kind==='sender')data=team;}
  } else if(u.endsWith('/system/user/getInfo')) data={user:{userId:'201',tenantId:kind==='money'||kind==='extra'?'fixture-tenant':'900001',userName:'fixture',nickName:'虚构本人',avatar:''},roles:[kind==='money'||kind==='extra'?'organizer':'participant'],permissions:[]};
  else if(u.endsWith('/system/menu/getRouters'))data=kind==='money'||kind==='extra'?menus:[];
  else if(u.endsWith('/sports/b/ai/assistant/sessions'))data=[];
  else if(u.endsWith('/auth/tenant/list'))data={tenantEnabled:false,voList:[]};
  else if(u.endsWith('/sports/c/organization/application'))data={applicationId:null,status:null,canEnter:false,files:[],versions:[]};
  else if(u.endsWith('/sports/c/identity'))data=identity;
  else if(u.endsWith('/sports/c/teams/601'))data=team;
  else if(u.endsWith('/sports/b/desk/context'))data={organizationId:'601',organizationName:'虚构组织',organize:true,payment:true};
  else if(u.endsWith('/sports/b/events/901'))data={...event,registrationReview:'none'};
  else if(u.endsWith('/sports/b/events'))data=[{...event,registrationReview:'none'}];
  else if(u.endsWith('/registrations/events')||u.endsWith('/fees/events'))data=[{eventId:'901',name:event.name,holdingStatus:'normal',publicationStatus:'published',unitOpen:true}];
  else if(u.endsWith('/registrations/units'))data=units;
  else if(u.endsWith('/registrations/units/501/entries'))data=[{...entry,status:state.settled?'approved':'submitted',obligationStatus:state.settled?'settled':'open'}];
  else if(u.endsWith('/fees/obligations/801/records'))data={netAmount:state.settled?120:0,dueAmount:120,receipts:[],refunds:[]};
  else if(u.endsWith('/fees/units'))data=[{unitId:'501',unitName:'双打',amount:120,paymentMode:'offline'}];
  else if(u.endsWith('/registrations/invites/fixture'))data=invite();
  else if(u.endsWith('/teams/invitations/611')){if(kind==='denied'){code=403;msg='这不是你的邀请';data=null;}else data={id:'611',teamId:'601',teamName:'虚构队伍',status:state.status,personName:'虚构本人'};}
  else return fixtureAudit.reject(route);
  return route.fulfill({json:{code,msg,data}});
 });
 const page=await context.newPage();page.on('pageerror',error=>errors.push(error.message));page.setDefaultTimeout(12000);
 return {page,context,state};
}
const until=async(predicate,label)=>{for(let i=0;i<100;i++){if(predicate())return;await new Promise(r=>setTimeout(r,50))}throw Error('Timed out: '+label)};
const gate=()=>{let resolve;const promise=new Promise(r=>resolve=r);return {promise,resolve}};
async function openMoney(s,extra=false){
 const p=s.page;await p.goto(base+'/org-desk/workspace/901?task=registrations');
 if(extra)await p.getByRole('button',{name:/全部 ·/}).click();
 await p.getByRole('button',{name:'查看办理',exact:true}).click();
 await p.getByRole('button',{name:extra?'补记其他实际收款':'登记实际到账',exact:true}).click();
 await p.locator('.b-dialog').waitFor();
}
async function fillMoney(p,extra=false){
 const form=p.locator('.b-dialog');
 await form.locator('.el-form-item').filter({hasText:'实际付款人'}).locator('input').fill('虚构付款人');
 if(extra)await form.locator('.el-input-number input').fill('10');
 const at=form.locator('.el-date-editor input');await at.fill('2026-10-07 10:20:00');await at.press('Enter');
}
try {
 const s=await scenario('extra',390);
 try {
  await openMoney(s,true);const p=s.page;
  check(await p.locator('.b-dialog .el-input-number input').inputValue()==='','足额后补记金额不默认填入');
  await fillMoney(p,true);await p.locator('.b-dialog').getByRole('button',{name:'确认登记'}).click();
  await p.getByText('请填写补记原因，确认是另一笔实际收款',{exact:true}).waitFor();check(s.state.writes.length===0,'补记缺原因时零请求');
  await p.locator('.b-dialog textarea').fill('隔离样例：另一笔真实收款的核对说明');
  await p.locator('.b-dialog').getByRole('button',{name:'确认登记'}).click();await p.locator('.el-message-box').waitFor();
  await p.locator('.el-message-box').getByRole('button',{name:'返回核对'}).click();
  await p.locator('.el-message-box').waitFor({state:'hidden'});
  check(s.state.writes.length===0,'二次确认取消后零请求');
  await p.screenshot({path:path.join(out,'extra-receipt-mobile.png'),fullPage:true});
  await p.locator('.b-dialog').getByRole('button',{name:'取消',exact:true}).click();check(s.state.writes.length===0,'关闭到账表单不写入');
 } finally {await s.context.close()}
 const m=await scenario('money');
 try {
  await openMoney(m);const p=m.page;await fillMoney(p);m.state.fail=true;
  await p.locator('.b-dialog').getByRole('button',{name:'确认登记'}).click();
  await p.getByText('隔离模拟：服务暂时不可用',{exact:true}).waitFor();
  await until(()=>m.state.writes.length===1,'failed receipt');
  check(await p.locator('.b-dialog').isVisible(),'接口失败保留到账表单');
  await p.locator('.b-dialog').getByRole('button',{name:'确认登记'}).waitFor({state:'visible'});
  // 现有HTTP拦截器500ms防重复窗口结束后模拟人工重试。
  await p.waitForTimeout(550);m.state.fail=false;m.state.release=gate();
  await p.locator('.b-dialog').getByRole('button',{name:'确认登记'}).click();
  await until(()=>m.state.writes.length===2,'retry receipt');
  check(await p.locator('.b-dialog').getByRole('button',{name:'确认登记'}).isDisabled(),'到账处理中按钮禁用');
  await p.locator('.b-dialog').getByRole('button',{name:'确认登记'}).evaluate(e=>{e.click();e.click()});
  check(m.state.writes.length===2,'忙碌期间重复点击不追加到账请求');
  check(m.state.writes[0].data.requestKey===m.state.writes[1].data.requestKey,'失败重试沿用原请求键');
  check(m.state.writes[1].data.payerName==='虚构付款人'&&m.state.writes[1].data.amount===120&&m.state.writes[1].data.occurredAt==='2026-10-07 10:20:00','提交实填付款人金额北京时间');
  m.state.release.resolve();await p.getByText('实际到账已登记，报名已自动通过',{exact:true}).waitFor();
  await p.locator('.b-dialog').waitFor({state:'hidden'});check(true,'成功到账关闭表单并刷新资格');
 } finally {m.state.release?.resolve();await m.context.close()}
 for(const kind of ['team','registration']) {
  const s=await scenario(kind,390);
  try {
   const p=s.page;await p.goto(base+(kind==='team'?'/portal/teams/invitations/611':'/portal/registration/invite/fixture'));
   const label=kind==='team'?'接受邀请':'确认参加';await p.getByRole('button',{name:label,exact:true}).waitFor();
   if(kind==='registration')check(await p.locator('.invitation-roster').count()===0,'确认前页面不展示伙伴名单');
   s.state.fail=true;await p.getByRole('button',{name:label,exact:true}).click();
   await p.getByText('隔离模拟：服务暂时不可用',{exact:true}).waitFor();
   check(await p.getByRole('button',{name:label,exact:true}).isEnabled(),kind+' 邀请失败后恢复操作');
   await p.waitForTimeout(550);s.state.fail=false;
   s.state.release=gate();await p.getByRole('button',{name:label,exact:true}).click();await until(()=>s.state.writes.length===2,'invite response');
   check(await p.getByRole('button',{name:label,exact:true}).isDisabled(),kind+' 邀请处理中接受按钮禁用');
   check(await p.getByRole('button',{name:'拒绝邀请',exact:true}).isDisabled(),kind+' 邀请处理中拒绝按钮禁用');
   await p.getByRole('button',{name:label,exact:true}).evaluate(e=>{e.click();e.click()});
   check(s.state.writes.length===2,kind+' 邀请提交防重复');s.state.release.resolve();
   await p.getByRole('button',{name:label,exact:true}).waitFor({state:'hidden'});
   if(kind==='registration'){await p.locator('.invitation-roster').waitFor();check(await p.getByText('虚构伙伴',{exact:true}).count()===1,'确认后显示最小伙伴名单');}
   else {await p.getByRole('link',{name:'查看队伍',exact:true}).waitFor();check(true,'接受入队后提供查看队伍入口');}
  } finally {s.state.release?.resolve();await s.context.close()}
 }
 const sender=await scenario('sender',390);
 try {
  const p=sender.page;await p.goto(base+'/portal/teams/601');
  const sms=p.getByRole('checkbox',{name:'同时申请短信提醒'});
  const smsLabel=p.locator('.el-checkbox').filter({hasText:'同时申请短信提醒'});await smsLabel.waitFor();
  check(!await sms.isChecked(),'邀请默认仅站内信，不申请短信');
  await p.getByPlaceholder('对方已注册的手机号').fill('13900000000');
  await p.getByRole('button',{name:'发出邀请',exact:true}).click();
  await until(()=>sender.state.writes.length===1,'inbox invitation');
  check(sender.state.writes[0].data.requestSms===false,'默认邀请请求不触发短信');
  await p.getByPlaceholder('对方已注册的手机号').fill('13900000001');await smsLabel.click();
  await p.getByRole('button',{name:'发出邀请',exact:true}).click();
  await p.getByText('短信通道未接通，请复制链接联系对方',{exact:true}).waitFor();
  check(sender.state.writes.length===2&&sender.state.writes[1].data.requestSms===true,'明确勾选才申请短信');
  check(!await sms.isChecked(),'发出邀请后短信选项重置');
 } finally {await sender.context.close()}
 const d=await scenario('denied');try {await d.page.goto(base+'/portal/teams/invitations/611');await d.page.getByText('无法查看这条邀请',{exact:true}).waitFor();check(await d.page.getByRole('button',{name:'接受邀请',exact:true}).count()===0,'其他账号邀请拒绝后无操作入口')}finally{await d.context.close()}
 fixtureAudit.assertClean();check(unexpected.length===0,'所有业务写请求仅限明确测试的模拟接口');check(errors.length===0,'交互异常后无未处理脚本错误');
 completed=true;console.log('CRITICAL UI PASS '+checks.length+' checks; all API requests intercepted');
} finally {
 await fs.writeFile(path.join(out,'ui-results.json'),JSON.stringify({scope:'Mocked API interaction tests; no actual business writes',completed,checks,unexpected,errors},null,2));
 await browser.close();
}

